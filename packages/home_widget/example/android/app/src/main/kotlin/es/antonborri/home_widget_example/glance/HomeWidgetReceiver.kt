package es.antonborri.home_widget_example.glance

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class HomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<HomeWidgetGlanceAppWidget>() {
  override val glanceAppWidget = HomeWidgetGlanceAppWidget()
}
