// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ForecastHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ForecastHomeWidget>() {
  override val glanceAppWidget = ForecastHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
}
