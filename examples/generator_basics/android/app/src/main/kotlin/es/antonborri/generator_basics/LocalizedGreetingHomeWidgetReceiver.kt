// GENERATED CODE - DO NOT MODIFY BY HAND
package es.antonborri.generator_basics

import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.updateAll
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class LocalizedGreetingHomeWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<LocalizedGreetingHomeWidget>() {
  override val glanceAppWidget = LocalizedGreetingHomeWidget()

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == Intent.ACTION_LOCALE_CHANGED) {
      val pendingResult = goAsync()
      CoroutineScope(Dispatchers.Default).launch {
        try {
          LocalizedGreetingHomeWidget().updateAll(context)
        } finally {
          pendingResult.finish()
        }
      }
    }
  }
}
