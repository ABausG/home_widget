// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class WeekForecastHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<WeekForecastHomeWidget>() {
  override val glanceAppWidget = WeekForecastHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == Intent.ACTION_TIME_CHANGED) {
      val manager = AppWidgetManager.getInstance(context)
      onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, javaClass)))
      return
    }
    super.onReceive(context, intent)
  }
}
