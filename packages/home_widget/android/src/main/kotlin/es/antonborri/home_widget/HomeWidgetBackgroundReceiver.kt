package es.antonborri.home_widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.FlutterInjector

class HomeWidgetBackgroundReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val flutterLoader = FlutterInjector.instance().flutterLoader()
    flutterLoader.startInitialization(context)
    flutterLoader.ensureInitializationComplete(context, null)
    
    val data = Data.Builder()
      .putString(
        HomeWidgetBackgroundWorker.DATA_KEY,
        intent.data?.toString() ?: ""
      )
      .build()
    
    val workRequest = OneTimeWorkRequestBuilder<HomeWidgetBackgroundWorker>()
      .setInputData(data)
      .build()
    
    WorkManager.getInstance(context)
      .enqueueUniqueWork(
        HomeWidgetBackgroundWorker.UNIQUE_WORK_NAME,
        ExistingWorkPolicy.APPEND,
        workRequest
      )
  }
}
