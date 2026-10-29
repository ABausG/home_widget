// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class GreetingHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<GreetingHomeWidget>() {
  override val glanceAppWidget = GreetingHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
}
