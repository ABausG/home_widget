// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.streak_widget

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class StreakHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<StreakHomeWidget>() {
  override val glanceAppWidget = StreakHomeWidget()

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
}
