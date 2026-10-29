package es.antonborri.home_widget_example.glance

import android.content.Context
import androidx.core.os.ConfigurationCompat
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetPlugin

class HomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<HomeWidgetGlanceAppWidget>() {
  override val glanceAppWidget = HomeWidgetGlanceAppWidget()

  override fun previewFingerprint(context: Context): String {
    val data = HomeWidgetPlugin.getData(context)
    return listOf(
            data.getString("title", ""),
            data.getString("message", ""),
            ConfigurationCompat.getLocales(context.resources.configuration).toLanguageTags(),
        )
        .joinToString("|")
  }
}
