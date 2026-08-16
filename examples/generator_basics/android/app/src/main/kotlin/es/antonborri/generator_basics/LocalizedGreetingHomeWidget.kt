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
    val hwLocale = hwCurrentLocale(context)
    val prefs = currentState.preferences
    val widgetData = LocalizedGreetingData.fromPreferences(prefs, hwLocale)
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
              text =
                  hwLocalize(
                      hwLocale,
                      mapOf("en" to "Greeting", "de" to "Begrüßung", "pt-BR" to "Saudação"),
                      "en",
                  ),
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
        locale: String,
    ): LocalizedGreetingData {
      return LocalizedGreetingData(
          greeting =
              hwReadLocalized(
                  prefs,
                  "${PREFERENCES_PREFIX}.greeting",
                  locale,
                  mapOf("en" to "Hello", "de" to "Hallo", "pt-BR" to "Olá"),
                  "en",
              ),
      )
    }
  }
}

private fun hwCurrentLocale(context: android.content.Context): String {
  val locale =
      androidx.core.os.ConfigurationCompat.getLocales(context.resources.configuration)[0]
          ?: java.util.Locale.getDefault()
  return if (locale.country.isNullOrEmpty()) {
    locale.language
  } else {
    "${locale.language}-${locale.country}"
  }
}

private fun hwLocalize(locale: String, values: Map<String, String>, baseLocale: String): String {
  val tag = locale.replace('_', '-')
  return values[tag] ?: values[tag.substringBefore('-')] ?: values[baseLocale] ?: ""
}

private fun hwReadLocalized(
    prefs: android.content.SharedPreferences,
    key: String,
    locale: String,
    values: Map<String, String>,
    baseLocale: String,
): String {
  val tag = locale.replace('_', '-')
  return prefs.getString("$key.$tag", null)
      ?: prefs.getString("$key.${tag.substringBefore('-')}", null)
      ?: prefs.getString("$key.$baseLocale", null)
      ?: hwLocalize(tag, values, baseLocale)
}
