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
    val expedited = intent.getBooleanExtra(HomeWidgetBackgroundIntent.EXTRA_IS_EXPEDITED, false)
    HomeWidgetBackgroundWorker.enqueueWork(context, intent, expedited)
  }
}
