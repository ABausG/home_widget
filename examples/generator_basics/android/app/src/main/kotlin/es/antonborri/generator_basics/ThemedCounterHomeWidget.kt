// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
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
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.text.NumberFormat
import java.util.Locale

class ThemedCounterHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = ThemedCounterData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(
                      ColorProvider(day = Color(0xFFEFF6FF), night = Color(0xFF0B1220))
                  )
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Spacer(modifier = GlanceModifier.defaultWeight())
          Text(
              text = "Counter",
              style =
                  TextStyle(
                      color = GlanceTheme.colors.onSurfaceVariant,
                      fontSize = 12.sp,
                      fontWeight = FontWeight.Normal,
                  ),
          )
          Text(
              text =
                  hwFormatDecimal(
                      (widgetData.count ?: 0L),
                      null,
                      null,
                      true,
                      hwFormatLocale(context),
                  ),
              style =
                  TextStyle(
                      color = GlanceTheme.colors.onSurface,
                      fontSize = 22.sp,
                      fontWeight = FontWeight.Bold,
                  ),
          )
          Spacer(modifier = GlanceModifier.defaultWeight())
        }
      }
    }
  }
}

data class ThemedCounterData(
    val count: Long? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.ThemedCounter"

    fun fromPreferences(prefs: android.content.SharedPreferences): ThemedCounterData {
      return ThemedCounterData(
          count =
              if (prefs.contains("${PREFERENCES_PREFIX}.count"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.count", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.count", 0L)
                  })
              else 0L,
      )
    }
  }
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
