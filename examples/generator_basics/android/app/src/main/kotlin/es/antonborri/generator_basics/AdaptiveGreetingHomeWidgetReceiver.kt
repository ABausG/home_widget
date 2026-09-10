// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class AdaptiveGreetingHomeWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<AdaptiveGreetingHomeWidget>() {
  override val glanceAppWidget = AdaptiveGreetingHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
}
