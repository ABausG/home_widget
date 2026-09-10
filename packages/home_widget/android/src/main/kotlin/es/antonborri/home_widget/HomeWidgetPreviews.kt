package es.antonborri.home_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Registers the previews the launcher shows for a Widget in its gallery.
 *
 * Android 15 (API 35) lets an app replace the static preview image of a Widget with one the system
 * renders from the Widget's own `providePreview`, so the gallery can show it filled with real data.
 * Below API 35 everything here is a no-op.
 *
 * This is a public API. It can be used from Dart via `HomeWidget.updateWidgetPreview` or directly
 * from native code:
 * ```kotlin
 * HomeWidgetPreviews.update(context, MyWidgetReceiver::class.java)
 * ```
 *
 * The system rate-limits preview updates to roughly two per hour and Widget. [registerAll]
 * therefore only pushes a preview when the receiver's
 * [HomeWidgetGlanceWidgetReceiver.previewFingerprint] differs from the one that was stored the last
 * time a preview was accepted, or when the system holds no preview for the Widget any more.
 */
object HomeWidgetPreviews {
  private const val TAG = "HomeWidgetPreviews"
  private const val PREFERENCES = "HomeWidgetPreviews"

  /**
   * A [SharedPreferences] that holds nothing and cannot be written to.
   *
   * A Widget whose preview does not use live data renders from this, so every field falls through
   * to the sample value it ships rather than to whatever the app happens to have saved.
   */
  val emptyPreferences: SharedPreferences =
      object : SharedPreferences {
        override fun getAll(): Map<String, *> = emptyMap<String, Any>()

        override fun getString(key: String?, defValue: String?): String? = defValue

        override fun getStringSet(key: String?, defValues: Set<String>?): Set<String>? = defValues

        override fun getInt(key: String?, defValue: Int): Int = defValue

        override fun getLong(key: String?, defValue: Long): Long = defValue

        override fun getFloat(key: String?, defValue: Float): Float = defValue

        override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue

        override fun contains(key: String?): Boolean = false

        override fun edit(): SharedPreferences.Editor =
            throw UnsupportedOperationException("The preview preferences are read-only")

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?
        ) = Unit

        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?
        ) = Unit
      }

  /**
   * Asks the system to re-render the gallery preview of [receiverClass].
   *
   * Returns `false` below Android 15, when [receiverClass] is not a `GlanceAppWidgetReceiver`, and
   * when the system rate limit was hit; `true` when the preview was accepted.
   */
  suspend fun update(context: Context, receiverClass: Class<*>): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
      return false
    }
    if (!GlanceAppWidgetReceiver::class.java.isAssignableFrom(receiverClass)) {
      return false
    }
    @Suppress("UNCHECKED_CAST")
    val receiverKClass = receiverClass.kotlin as KClass<out GlanceAppWidgetReceiver>
    val result = GlanceAppWidgetManager(context).setWidgetPreviews(receiverKClass)
    if (result != GlanceAppWidgetManager.SET_WIDGET_PREVIEWS_RESULT_SUCCESS) {
      return false
    }
    val receiver = receiverClass.getDeclaredConstructor().newInstance()
    if (receiver is HomeWidgetGlanceWidgetReceiver<*>) {
      storeFingerprint(context, receiverClass.name, receiver.previewFingerprint(context))
    }
    return true
  }

  /**
   * Refreshes the previews of all installed [HomeWidgetGlanceWidgetReceiver]s whose content
   * changed.
   *
   * Called once per Flutter engine attach. Receivers whose
   * [HomeWidgetGlanceWidgetReceiver.previewFingerprint] is `null` or unchanged are skipped, so an
   * app that renders the same preview on every start does not spend its rate limit. An app update
   * or a reboot can make the system drop a preview it accepted, so a Widget the system reports no
   * preview for is registered again regardless.
   */
  fun registerAll(context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
      return
    }
    val applicationContext = context.applicationContext
    CoroutineScope(Dispatchers.Default).launch {
      val providers =
          try {
            AppWidgetManager.getInstance(applicationContext)
                .getInstalledProvidersForPackage(applicationContext.packageName, null)
          } catch (e: Exception) {
            Log.w(TAG, "Failed to list the installed Widget providers", e)
            return@launch
          }
      for (provider in providers) {
        val className = provider.provider.className
        try {
          val receiverClass = Class.forName(className)
          if (!HomeWidgetGlanceWidgetReceiver::class.java.isAssignableFrom(receiverClass)) {
            continue
          }
          val receiver =
              receiverClass.getDeclaredConstructor().newInstance()
                  as HomeWidgetGlanceWidgetReceiver<*>
          val fingerprint = receiver.previewFingerprint(applicationContext) ?: continue
          if (
              provider.generatedPreviewCategories != 0 &&
                  fingerprint == loadFingerprint(applicationContext, className)
          ) {
            continue
          }
          update(applicationContext, receiverClass)
        } catch (e: Exception) {
          Log.w(TAG, "Failed to update the preview of $className", e)
        }
      }
    }
  }

  private fun storeFingerprint(context: Context, receiverClassName: String, fingerprint: String?) {
    val editor =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().apply {
          if (fingerprint == null) {
            remove(receiverClassName)
          } else {
            putString(receiverClassName, fingerprint)
          }
        }
    editor.apply()
  }

  private fun loadFingerprint(context: Context, receiverClassName: String): String? =
      context
          .getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
          .getString(receiverClassName, null)
}
