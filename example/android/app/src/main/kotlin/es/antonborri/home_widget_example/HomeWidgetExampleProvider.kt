package es.antonborri.home_widget_example

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class HomeWidgetExampleProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val data = HomeWidgetPlugin.getData(context)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.example_layout).apply {
                setTextViewText(R.id.widget_title, data.getString("title", null) ?: "No Title Set")
                setTextViewText(R.id.widget_message, data.getString("message", null) ?: "No Message Set")
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}