// Glance widget: mirrors iOS ConfigurableWidgetEntryView and Flutter keys in
// android_configuration_page.dart (`name.{appWidgetId}`, `punctuation.{appWidgetId}`).
package es.antonborri.configurable_widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.Text
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

class ConfigurableWidgetHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
    provideContent { WidgetContent(appWidgetId, currentState()) }
  }

  @Composable
  private fun WidgetContent(appWidgetId: Int, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val nameKey = "name.$appWidgetId"
    val punctuationKey = "punctuation.$appWidgetId"
    val name = prefs.getString(nameKey, "World")
    val punctuation = prefs.getString(punctuationKey, null)

    Column(
        modifier = GlanceModifier.fillMaxSize().background(Color(0xFFF2F2F7)).padding(16.dp),
        horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
        verticalAlignment = Alignment.Vertical.CenterVertically,
    ) {
      Text(text = "Hello")
      if (!name.isNullOrEmpty()) {
        Text(text = name)
      }
      if (!punctuation.isNullOrEmpty()) {
        Text(text = punctuation)
      }
    }
  }
}
