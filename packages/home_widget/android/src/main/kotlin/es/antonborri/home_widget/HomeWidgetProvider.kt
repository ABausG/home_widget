package es.antonborri.home_widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences

abstract class HomeWidgetProvider : AppWidgetProvider() {

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
    onUpdate(context, appWidgetManager, appWidgetIds, HomeWidgetPlugin.getData(context))
  }

  abstract fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  )
}
