// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class FontAndIconsHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<FontAndIconsHomeWidget>() {
  override val glanceAppWidget = FontAndIconsHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
}
