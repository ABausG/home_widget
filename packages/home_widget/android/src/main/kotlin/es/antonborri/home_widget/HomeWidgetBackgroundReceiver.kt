package es.antonborri.home_widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.FlutterInjector

class HomeWidgetBackgroundReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val flutterLoader = FlutterInjector.instance().flutterLoader()
    flutterLoader.startInitialization(context)
    flutterLoader.ensureInitializationComplete(context, null)
    if (intent.getBooleanExtra(EXTRA_DIRECT, false)) {
      HomeWidgetBackgroundRunner.execute(context, intent, goAsync())
    } else {
      HomeWidgetBackgroundWorker.enqueueWork(context, intent)
    }
  }

  companion object {
    const val EXTRA_DIRECT = "es.antonborri.home_widget.extra.DIRECT"
  }
}
