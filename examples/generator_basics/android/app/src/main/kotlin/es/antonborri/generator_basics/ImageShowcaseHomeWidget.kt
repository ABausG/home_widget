// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.ConfigurationCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.util.Locale

class ImageShowcaseHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  override suspend fun providePreview(context: Context, widgetCategory: Int) {
    provideContent {
      WidgetContent(
          context,
          HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)),
          preview = true,
      )
    }
  }

  fun previewFingerprint(context: Context): String {
    val hwLocales = hwCurrentLocales(context)
    val hwPreviewData = ImageShowcaseData.previewFromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "e9e6ed83",
            hwLocales.joinToString(","),
            hwPreviewData.toString(),
            listOf(hwPreviewData.picture, hwPreviewData.slide, hwPreviewData.contact?.avatar)
                .joinToString(",") { hwPath ->
                  hwPath?.let { java.io.File(it).lastModified().toString() } ?: ""
                },
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(
      context: Context,
      currentState: HomeWidgetGlanceState,
      preview: Boolean = false,
  ) {
    val prefs = currentState.preferences
    val widgetData =
        if (preview) ImageShowcaseData.previewFromPreferences(prefs)
        else ImageShowcaseData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(
            modifier =
                GlanceModifier.fillMaxSize()
                    .padding(start = 8.0.dp, top = 8.0.dp, end = 8.0.dp, bottom = 8.0.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Spacer(modifier = GlanceModifier.defaultWeight())
          hwDecodeImage(context, "assets/logo.png", 24.0, 24.0)?.let { bitmap ->
            Image(
                provider = ImageProvider(bitmap),
                contentDescription = "App logo",
                contentScale = ContentScale.Fit,
                modifier = GlanceModifier.width(24.0.dp).height(24.0.dp),
            )
          }
          if (hwImageExists(context, widgetData.picture)) {
            widgetData.picture
                ?.let { path -> hwDecodeImage(context, path, 64.0, 64.0) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Picture saved by the app",
                      contentScale = ContentScale.Crop,
                      modifier = GlanceModifier.width(64.0.dp).height(64.0.dp),
                  )
                }
          } else {
            Text(
                text = "Open the app to pick an image",
                style =
                    TextStyle(
                        color = GlanceTheme.colors.onSurfaceVariant,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Normal,
                    ),
            )
          }
          Row(verticalAlignment = Alignment.CenterVertically) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            widgetData.slide
                ?.let { path -> hwDecodeImage(context, path, 28.0, 28.0) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Picture for the current time slot",
                      contentScale = ContentScale.Fit,
                      modifier = GlanceModifier.width(28.0.dp).height(28.0.dp),
                  )
                }
            widgetData.contact
                ?.avatar
                ?.let { path -> hwDecodeImage(context, path, 28.0, 28.0) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Contact avatar",
                      contentScale = ContentScale.Crop,
                      modifier = GlanceModifier.width(28.0.dp).height(28.0.dp),
                  )
                }
            Text(
                text = (widgetData.contact?.name ?: ""),
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
          }
          Spacer(modifier = GlanceModifier.defaultWeight())
        }
      }
    }
  }
}

data class ImageShowcaseData(
    val picture: String? = null,
    val contact: ImageShowcaseContactJsonData? = null,
    val slide: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.ImageShowcase"

    fun fromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): ImageShowcaseData {
      val timedValues = resolveTimedValues(prefs, now)
      return ImageShowcaseData(
          picture = prefs.getString("${PREFERENCES_PREFIX}.picture", null),
          contact =
              ImageShowcaseContactJsonData.fromPath(
                  prefs.getString("${PREFERENCES_PREFIX}.contact", null)
              ),
          slide =
              if (timedValues.has("slide") && !timedValues.isNull("slide"))
                  timedValues.optString("slide")
              else null,
      )
    }

    fun previewFromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): ImageShowcaseData {
      val timedValues = resolveTimedValues(prefs, now)
      return ImageShowcaseData(
          picture = prefs.getString("${PREFERENCES_PREFIX}.picture", "assets/dash.png"),
          contact =
              ImageShowcaseContactJsonData.previewFromPath(
                  prefs.getString("${PREFERENCES_PREFIX}.contact", null)
              ),
          slide =
              if (timedValues.has("slide") && !timedValues.isNull("slide"))
                  timedValues.optString("slide")
              else null,
      )
    }

    private fun resolveTimedValues(
        prefs: android.content.SharedPreferences,
        now: Long,
    ): org.json.JSONObject {
      val path =
          prefs.getString("${PREFERENCES_PREFIX}.timedData", null) ?: return org.json.JSONObject()
      return try {
        val file = java.io.File(path)
        if (!file.exists()) return org.json.JSONObject()
        val json = org.json.JSONObject(file.readText())
        var activeKey: String? = null
        var activeTimestamp = 0L
        val keys = json.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          val timestamp = key.toLongOrNull() ?: continue
          if (timestamp <= now && (activeKey == null || timestamp > activeTimestamp)) {
            activeKey = key
            activeTimestamp = timestamp
          }
        }
        val resolvedKey = activeKey ?: return org.json.JSONObject()
        json.optJSONObject(resolvedKey) ?: org.json.JSONObject()
      } catch (_: Exception) {
        org.json.JSONObject()
      }
    }
  }
}

data class ImageShowcaseContactJsonData(
    val avatar: String? = null,
    val name: String = "",
) {
  companion object {
    fun fromPath(path: String?): ImageShowcaseContactJsonData? {
      if (path == null) return null
      return try {
        val file = java.io.File(path)
        if (!file.exists()) return null
        fromJson(org.json.JSONObject(file.readText()))
      } catch (_: Exception) {
        null
      }
    }

    fun fromJson(obj: org.json.JSONObject?): ImageShowcaseContactJsonData? {
      if (obj == null) return null
      val json = obj
      return ImageShowcaseContactJsonData(
          avatar =
              if (json.has("avatar") && !json.isNull("avatar")) json.optString("avatar") else null,
          name = if (json.has("name") && !json.isNull("name")) json.optString("name") else "",
      )
    }

    fun previewFromPath(path: String?): ImageShowcaseContactJsonData? {
      if (path == null) return previewFromJson(org.json.JSONObject())
      return try {
        val file = java.io.File(path)
        if (!file.exists()) return previewFromJson(org.json.JSONObject())
        previewFromJson(org.json.JSONObject(file.readText()))
      } catch (_: Exception) {
        previewFromJson(org.json.JSONObject())
      }
    }

    fun previewFromJson(obj: org.json.JSONObject?): ImageShowcaseContactJsonData? {
      val json = obj ?: org.json.JSONObject()
      return ImageShowcaseContactJsonData(
          avatar =
              if (json.has("avatar") && !json.isNull("avatar")) json.optString("avatar") else null,
          name = if (json.has("name") && !json.isNull("name")) json.optString("name") else "",
      )
    }
  }
}

private fun hwCurrentLocales(context: Context): List<String> {
  val configured = ConfigurationCompat.getLocales(context.resources.configuration)
  val tags = mutableListOf<String>()
  for (index in 0 until configured.size()) {
    val locale = configured[index] ?: continue
    val tag = locale.toLanguageTag()
    if (tag.isNotEmpty() && tag != "und") tags.add(tag)
  }
  if (tags.isEmpty()) {
    val fallback = Locale.getDefault().toLanguageTag()
    if (fallback.isNotEmpty() && fallback != "und") tags.add(fallback)
  }
  return tags
}

private fun hwDecodeImage(
    context: Context,
    path: String,
    widthDp: Double?,
    heightDp: Double?,
): Bitmap? {
  fun decode(options: BitmapFactory.Options): Bitmap? =
      if (path.startsWith("/")) {
        BitmapFactory.decodeFile(path, options)
      } else {
        context.assets.open("flutter_assets/$path").use {
          BitmapFactory.decodeStream(it, null, options)
        }
      }

  fun sampleSize(bounds: BitmapFactory.Options): Int {
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return 1
    val metrics = context.resources.displayMetrics
    val fallback = minOf(metrics.widthPixels, metrics.heightPixels)
    val widthPx = widthDp?.let { (it * metrics.density).toInt() }
    val heightPx = heightDp?.let { (it * metrics.density).toInt() }
    val targetWidth =
        widthPx
            ?: heightPx?.let {
              (it.toLong() * bounds.outWidth / bounds.outHeight).toInt().coerceAtLeast(1)
            }
            ?: fallback
    val targetHeight =
        heightPx
            ?: widthPx?.let {
              (it.toLong() * bounds.outHeight / bounds.outWidth).toInt().coerceAtLeast(1)
            }
            ?: fallback
    if (targetWidth <= 0 || targetHeight <= 0) return 1
    var sampleSize = 1
    while (
        bounds.outWidth / (sampleSize * 2) >= targetWidth &&
            bounds.outHeight / (sampleSize * 2) >= targetHeight
    ) {
      sampleSize *= 2
    }
    return sampleSize
  }

  return try {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    decode(bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
      null
    } else {
      decode(
          BitmapFactory.Options().apply { inSampleSize = sampleSize(bounds) },
      )
    }
  } catch (_: Exception) {
    null
  }
}

private fun hwImageExists(context: Context, path: String?): Boolean {
  if (path.isNullOrEmpty()) return false
  if (path.startsWith("/")) return File(path).exists()
  return try {
    context.assets.open("flutter_assets/$path").close()
    true
  } catch (_: Exception) {
    false
  }
}
