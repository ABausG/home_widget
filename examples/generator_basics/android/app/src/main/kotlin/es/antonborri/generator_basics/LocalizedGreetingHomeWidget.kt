// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.ConfigurationCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Locale
import org.json.JSONObject

class LocalizedGreetingHomeWidget : GlanceAppWidget() {
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
    val hwPreviewData =
        LocalizedGreetingData.previewFromPreferences(HomeWidgetPlugin.getData(context), hwLocales)
    return listOf(
            "cfd7deee",
            hwLocales.joinToString(","),
            hwPreviewData.toString(),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(
      context: Context,
      currentState: HomeWidgetGlanceState,
      preview: Boolean = false,
  ) {
    val hwLocales = hwCurrentLocales(context)
    val prefs = currentState.preferences
    val widgetData =
        if (preview) LocalizedGreetingData.previewFromPreferences(prefs, hwLocales)
        else LocalizedGreetingData.fromPreferences(prefs, hwLocales)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(horizontalAlignment = Alignment.Start) {
          Text(
              text = context.getString(R.string.home_widget_localized_greeting_t_1e28f816),
              style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
          )
          Text(
              text = widgetData.greeting ?: "",
              style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
          )
        }
      }
    }
  }
}

data class LocalizedGreetingData(
    val greeting: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.LocalizedGreeting"

    fun fromPreferences(
        prefs: android.content.SharedPreferences,
        locales: List<String>,
    ): LocalizedGreetingData {
      return LocalizedGreetingData(
          greeting =
              hwReadLocalized(
                  prefs,
                  "${PREFERENCES_PREFIX}.greeting",
                  locales,
                  mapOf("en" to "Hello", "de" to "Hallo", "pt-BR" to "Olá"),
                  "en",
              ),
      )
    }

    fun previewFromPreferences(
        prefs: android.content.SharedPreferences,
        locales: List<String>,
    ): LocalizedGreetingData {
      return LocalizedGreetingData(
          greeting =
              hwReadLocalized(
                  prefs,
                  "${PREFERENCES_PREFIX}.greeting",
                  locales,
                  mapOf("en" to "Hello, Anton", "de" to "Hallo, Anton", "pt-BR" to "Olá, Anton"),
                  "en",
              ),
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

private fun hwLocalizedEntries(json: JSONObject): Map<String, String> {
  val parsed = mutableMapOf<String, String>()
  val keys = json.keys()
  while (keys.hasNext()) {
    val name = keys.next()
    val value = json.opt(name)
    if (value is String) parsed[name] = value
  }
  return parsed
}

private fun hwDecodeLocalized(raw: String?): Map<String, String>? {
  if (raw == null) return null
  return try {
    hwLocalizedEntries(JSONObject(raw))
  } catch (_: Exception) {
    null
  }
}

private fun hwResolveLocalized(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String? {
  for (locale in locales) {
    // Progressive truncation: zh-Hant-TW -> zh-Hant -> zh.
    var candidate = locale.replace('_', '-')
    while (true) {
      values[candidate]?.let {
        return it
      }
      val cut = candidate.lastIndexOf('-')
      if (cut <= 0) break
      candidate = candidate.substring(0, cut)
    }
    val language = candidate
    // Same language, different region or script (pt-PT -> pt-BR).
    var sibling: String? = null
    for (key in values.keys) {
      if (key.substringBefore('-') != language) continue
      val current = sibling
      if (current == null || key < current) sibling = key
    }
    if (sibling != null) {
      values[sibling]?.let {
        return it
      }
    }
  }
  return values[baseLocale]
}

private fun hwLocalize(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String = hwResolveLocalized(locales, values, baseLocale) ?: ""

private fun hwReadLocalized(
    prefs: SharedPreferences,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
  val merged = values.toMutableMap()
  hwDecodeLocalized(prefs.getString(key, null))?.let { merged.putAll(it) }
  return hwLocalize(locales, merged, baseLocale)
}
