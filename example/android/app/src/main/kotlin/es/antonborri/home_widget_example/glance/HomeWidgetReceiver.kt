package es.antonborri.home_widget_example.glance

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import kotlinx.coroutines.runBlocking

class HomeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HomeWidgetGlanceAppWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        runBlocking {
            appWidgetIds.forEach {
                val glanceId = GlanceAppWidgetManager(context).getGlanceIdBy(it)
                HomeWidgetGlanceAppWidget().apply {
                    // Must Update State
                    updateAppWidgetState(context, glanceId) { prefs ->
                        prefs[longPreferencesKey("last_updated")] = System.currentTimeMillis()
                    }
                    // Update widget.
                    update(context, glanceId)
                }
            }
        }
    }
}