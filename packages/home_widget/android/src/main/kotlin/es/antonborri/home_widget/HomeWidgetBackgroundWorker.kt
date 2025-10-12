package es.antonborri.home_widget

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class HomeWidgetBackgroundWorker(private val context: Context, workerParams: WorkerParameters) :
    CoroutineWorker(context, workerParams), MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel

  override suspend fun doWork(): Result {
    if (engine == null) {
      try {
        initializeFlutterEngine()
      } catch (e: Exception) {
        Log.e(TAG, "Failed to initialize Flutter engine", e)
        return Result.failure()
      }
    }

    engine?.let {
      channel = MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL_NAME)
      channel.setMethodCallHandler(this)
    }

    val data = inputData.getString(DATA_KEY) ?: ""
    val args = listOf(HomeWidgetPlugin.getHandle(context), data)

    synchronized(serviceStarted) {
      if (!serviceStarted.get()) {
        queue.add(args)
      } else {
        mainHandler.post { channel.invokeMethod("", args) }
      }
    }

    return Result.success()
  }

  private suspend fun initializeFlutterEngine() {
    val callbackHandle = HomeWidgetPlugin.getDispatcherHandle(context)
    if (callbackHandle == 0L) {
      throw IllegalStateException(
          "No callbackHandle saved. Did you call HomeWidget.registerBackgroundCallback?")
    }

    val callbackInfo =
        FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
            ?: throw IllegalStateException("Failed to lookup callback information")

    withContext(Dispatchers.Main) {
      engine = FlutterEngine(context)
      val callback =
          DartExecutor.DartCallback(
              context.assets,
              FlutterInjector.instance().flutterLoader().findAppBundlePath(),
              callbackInfo)
      engine?.dartExecutor?.executeDartCallback(callback)
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "HomeWidget.backgroundInitialized" -> {
        handleBackgroundInitialized()
        result.success(null)
      }

      else -> result.notImplemented()
    }
  }

  private fun handleBackgroundInitialized() {
    synchronized(serviceStarted) {
      while (queue.isNotEmpty()) {
        val args = queue.remove()
        mainHandler.post { channel.invokeMethod("", args) }
      }
      serviceStarted.set(true)
    }
  }

  companion object {
    private const val TAG = "HomeWidgetWorker"
    private const val DATA_KEY = "uri_data"
    private const val UNIQUE_WORK_NAME = "home_widget_background"
    private const val CHANNEL_NAME = "home_widget/background"

    @Volatile private var engine: FlutterEngine? = null
    private val queue = ArrayDeque<List<Any>>()
    private val serviceStarted = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun enqueueWork(context: Context, work: Intent) {
      val data = Data.Builder().putString(DATA_KEY, work.data?.toString() ?: "").build()

      val workRequest =
          OneTimeWorkRequestBuilder<HomeWidgetBackgroundWorker>().setInputData(data).build()

      WorkManager.getInstance(context)
          .enqueueUniqueWork(UNIQUE_WORK_NAME, ExistingWorkPolicy.APPEND, workRequest)
    }
  }
}
