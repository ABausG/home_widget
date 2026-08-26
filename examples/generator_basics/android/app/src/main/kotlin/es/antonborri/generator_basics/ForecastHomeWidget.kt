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
import java.io.File
import org.json.JSONObject

class ForecastHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = ForecastData.fromPreferences(prefs)
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
              text = widgetData.city ?: "",
              style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
          )
          Text(
              text = widgetData.condition ?: "",
              style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
          )
          Text(text = (widgetData.temperature?.toString() ?: "0"))
        }
      }
    }
  }
}

data class ForecastData(
    val city: String? = null,
    val condition: String? = null,
    val temperature: Int? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.Forecast"

    fun fromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): ForecastData {
      val timedValues = resolveTimedValues(prefs, now)
      return ForecastData(
          city = prefs.getString("${PREFERENCES_PREFIX}.city", "Nowhere"),
          condition =
              if (timedValues.has("condition") && !timedValues.isNull("condition"))
                  timedValues.optString("condition")
              else "No forecast",
          temperature =
              if (timedValues.has("temperature") && !timedValues.isNull("temperature"))
                  timedValues.optInt("temperature")
              else 0,
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
