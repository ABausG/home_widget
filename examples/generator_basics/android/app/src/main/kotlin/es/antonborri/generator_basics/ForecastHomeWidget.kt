// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
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
import java.text.NumberFormat
import java.util.Locale

class ForecastHomeWidget : GlanceAppWidget() {
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
    val hwPreviewData = ForecastData.previewFromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "8a5e956c",
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
    val prefs = currentState.preferences
    val widgetData =
        if (preview) ForecastData.previewFromPreferences(prefs)
        else ForecastData.fromPreferences(prefs)
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
              text = widgetData.city ?: "",
              style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
          )
          Text(
              text = widgetData.condition ?: "",
              style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
          )
          Text(
              text =
                  hwFormatDecimal(
                      (widgetData.temperature ?: 0L),
                      null,
                      null,
                      true,
                      hwFormatLocale(context),
                  )
          )
        }
      }
    }
  }
}

data class ForecastData(
    val city: String? = null,
    val condition: String? = null,
    val temperature: Long? = null,
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
                  timedValues.optLong("temperature")
              else 0L,
      )
    }

    fun previewFromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): ForecastData {
      val timedValues = resolveTimedValues(prefs, now)
      return ForecastData(
          city = prefs.getString("${PREFERENCES_PREFIX}.city", "Berlin"),
          condition =
              if (timedValues.has("condition") && !timedValues.isNull("condition"))
                  timedValues.optString("condition")
              else "Sunny",
          temperature =
              if (timedValues.has("temperature") && !timedValues.isNull("temperature"))
                  timedValues.optLong("temperature")
              else 21L,
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

private fun hwFormatLocale(context: Context): Locale =
    ConfigurationCompat.getLocales(context.resources.configuration)[0] ?: Locale.getDefault()

private fun hwFormatDecimal(
    value: Number,
    minFraction: Int?,
    maxFraction: Int?,
    grouping: Boolean,
    locale: Locale,
): String {
  val formatter = NumberFormat.getNumberInstance(locale)
  formatter.isGroupingUsed = grouping
  minFraction?.let { formatter.minimumFractionDigits = it }
  maxFraction?.let { formatter.maximumFractionDigits = it }
  return formatter.format(value)
}
