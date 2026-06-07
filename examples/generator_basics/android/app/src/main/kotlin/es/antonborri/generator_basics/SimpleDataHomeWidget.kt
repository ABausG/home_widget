// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
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
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.Text
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

class SimpleDataHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = SimpleDataData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize(),
          contentAlignment = Alignment.Center,
      ) {
        Column {
          Text(text = "Simple Data")
          Row {
            Text(text = "label: ")
            Text(text = widgetData.label ?: "")
          }
          Row {
            Text(text = "value: ")
            Text(text = (widgetData.value?.toString() ?: "0"))
          }
        }
      }
    }
  }
}

data class SimpleDataData(
    val label: String? = null,
    val value: Int? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.SimpleData"

    fun fromPreferences(prefs: android.content.SharedPreferences): SimpleDataData {
      return SimpleDataData(
          label = prefs.getString("${PREFERENCES_PREFIX}.label", null),
          value =
              if (prefs.contains("${PREFERENCES_PREFIX}.value"))
                  prefs.getInt("${PREFERENCES_PREFIX}.value", 0)
              else null,
      )
    }
  }
}
