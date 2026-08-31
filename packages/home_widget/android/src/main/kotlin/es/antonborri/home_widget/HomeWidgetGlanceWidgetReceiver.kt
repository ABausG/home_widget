package es.antonborri.home_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import kotlinx.coroutines.runBlocking

abstract class HomeWidgetGlanceWidgetReceiver<T : GlanceAppWidget> : GlanceAppWidgetReceiver() {

  abstract override val glanceAppWidget: T

  /**
   * Re-arms the scheduled updates of this Widget when its first instance is added.
   *
   * Safety net for an alarm that was lost while no instance existed. The system already draws the
   * current state of the Widget that is being added, so no catch-up update is needed.
   */
  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    HomeWidgetScheduler.pruneAndArmNext(context, javaClass.name, catchUp = false)
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
  ) {
    super.onUpdate(context, appWidgetManager, appWidgetIds)
    runBlocking {
      appWidgetIds.forEach {
        val glanceId = GlanceAppWidgetManager(context).getGlanceIdBy(it)
        glanceAppWidget.apply {
          if (this.stateDefinition is HomeWidgetGlanceStateDefinition) {
            // Must Update State
            updateAppWidgetState<HomeWidgetGlanceState>(
                context = context,
                this.stateDefinition as HomeWidgetGlanceStateDefinition,
                glanceId,
            ) { currentState ->
              currentState
            }
          }
          // Update widget.
          update(context, glanceId)
        }
      }
    }
  }
}
