// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
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

class LocalizedGreetingHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val hwLocales = hwCurrentLocales(context)
    val prefs = currentState.preferences
    val widgetData = LocalizedGreetingData.fromPreferences(prefs, hwLocales)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize(),
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
  }
}

private fun hwCurrentLocales(context: android.content.Context): List<String> {
  val configured = androidx.core.os.ConfigurationCompat.getLocales(context.resources.configuration)
  val tags = mutableListOf<String>()
  for (index in 0 until configured.size()) {
    val locale = configured[index] ?: continue
    val tag = locale.toLanguageTag()
    if (tag.isNotEmpty() && tag != "und") tags.add(tag)
  }
  if (tags.isEmpty()) {
    val fallback = java.util.Locale.getDefault().toLanguageTag()
    if (fallback.isNotEmpty() && fallback != "und") tags.add(fallback)
  }
  return tags
}

// Returns null when nothing matches, including under the base locale.
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

private fun hwReadLocalized(
    prefs: android.content.SharedPreferences,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
  val merged = values.toMutableMap()
  hwDecodeLocalized(prefs.getString(key, null))?.let { merged.putAll(it) }
  return hwLocalize(locales, merged, baseLocale)
}

private fun hwDecodeLocalized(raw: String?): Map<String, String>? {
  if (raw == null) return null
  return try {
    val json = org.json.JSONObject(raw)
    val parsed = mutableMapOf<String, String>()
    val keys = json.keys()
    while (keys.hasNext()) {
      val name = keys.next()
      val value = json.opt(name)
      if (value is String) parsed[name] = value
    }
    parsed
  } catch (_: Exception) {
    null
  }
}

private fun hwLocalize(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String = hwResolveLocalized(locales, values, baseLocale) ?: ""
