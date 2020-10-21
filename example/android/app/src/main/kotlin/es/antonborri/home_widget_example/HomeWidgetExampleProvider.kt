package es.antonborri.home_widget_example

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetExampleProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.example_layout).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("title", null) ?: "No Title Set")
                setTextViewText(R.id.widget_message, widgetData.getString("message", null) ?: "No Message Set")
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}