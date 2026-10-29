// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ConditionalStatusHomeWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<ConditionalStatusHomeWidget>() {
  override val glanceAppWidget = ConditionalStatusHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
}
