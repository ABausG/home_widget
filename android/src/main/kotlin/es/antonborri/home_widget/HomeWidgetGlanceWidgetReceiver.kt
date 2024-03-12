import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import kotlinx.coroutines.runBlocking

abstract class HomeWidgetGlanceWidgetReceiver<T : GlanceAppWidget> : GlanceAppWidgetReceiver() {

    abstract override val glanceAppWidget: T

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        runBlocking {
            appWidgetIds.forEach {
                val glanceId = GlanceAppWidgetManager(context).getGlanceIdBy(it)
                glanceAppWidget.apply {
                    if (this.stateDefinition is HomeWidgetGlanceStateDefinition) {
                        // Must Update State
                        updateAppWidgetState<HomeWidgetGlanceState>(context = context, this.stateDefinition as HomeWidgetGlanceStateDefinition, glanceId) { currentState -> currentState }
                    }
                    // Update widget.
                    update(context, glanceId)
                }
            }
        }
    }
}