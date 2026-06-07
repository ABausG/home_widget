// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
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

class ConditionalStatusHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = ConditionalStatusData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize(),
          contentAlignment = Alignment.Center,
      ) {
        if (widgetData.hasData != null) {
          if (widgetData.enabled == true) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text = "Enabled",
                  style =
                      TextStyle(
                          color = ColorProvider(day = Color(0xFF16A34A), night = Color(0xFF16A34A)),
                          fontSize = 18.sp,
                          fontWeight = FontWeight.Medium,
                      ),
              )
              Spacer(modifier = GlanceModifier.defaultWeight())
            }
          } else {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text = "Disabled",
                  style =
                      TextStyle(
                          color = ColorProvider(day = Color(0xFFDC2626), night = Color(0xFFDC2626)),
                          fontSize = 18.sp,
                          fontWeight = FontWeight.Medium,
                      ),
              )
              Spacer(modifier = GlanceModifier.defaultWeight())
            }
          }
        } else {
          Column(
              modifier = GlanceModifier.fillMaxSize(),
              horizontalAlignment = Alignment.CenterHorizontally,
          ) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            Text(
                text = "No Data",
                style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Medium),
            )
            Text(
                text = "Open the app",
                style =
                    TextStyle(
                        color = GlanceTheme.colors.onSurfaceVariant,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Normal,
                    ),
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
          }
        }
      }
    }
  }
}

data class ConditionalStatusData(
    val hasData: Boolean? = null,
    val enabled: Boolean? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.ConditionalStatus"

    fun fromPreferences(prefs: android.content.SharedPreferences): ConditionalStatusData {
      return ConditionalStatusData(
          hasData =
              if (prefs.contains("${PREFERENCES_PREFIX}.hasData"))
                  prefs.getBoolean("${PREFERENCES_PREFIX}.hasData", false)
              else null,
          enabled =
              if (prefs.contains("${PREFERENCES_PREFIX}.enabled"))
                  prefs.getBoolean("${PREFERENCES_PREFIX}.enabled", false)
              else true,
      )
    }
  }
}
