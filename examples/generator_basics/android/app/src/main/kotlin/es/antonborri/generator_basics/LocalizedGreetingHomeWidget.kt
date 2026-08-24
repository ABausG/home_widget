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
    val tag =
        if (locale.country.isNullOrEmpty()) {
          locale.language
        } else {
          "${locale.language}-${locale.country}"
        }
    if (tag.isNotEmpty()) tags.add(tag.replace('_', '-'))
  }
  if (tags.isEmpty()) {
    val fallback = java.util.Locale.getDefault()
    tags.add(
        if (fallback.country.isNullOrEmpty()) {
          fallback.language
        } else {
          "${fallback.language}-${fallback.country}"
        }
    )
  }
  return tags
}

// Returns null when nothing in [values] matches, so a caller holding a second
// tier of translations can fall through to it.
private fun hwResolveLocalized(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String? {
  for (locale in locales) {
    val tag = locale.replace('_', '-')
    values[tag]?.let {
      return it
    }
    val language = tag.substringBefore('-')
    values[language]?.let {
      return it
    }
    // Same language, different region or script (pt-PT -> pt-BR). Keeps
    // keyed strings on the translation the OS already picks for resources.
    // Smallest key wins so the choice is stable across runs.
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
    prefs: android.content.SharedPreferences,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
  val stored = hwDecodeLocalized(prefs.getString(key, null))
  if (stored != null) {
    hwResolveLocalized(locales, stored, baseLocale)?.let {
      return it
    }
  }
  return hwLocalize(locales, values, baseLocale)
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
