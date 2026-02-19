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
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

class HomeWidgetBackgroundWorker(private val context: Context, workerParams: WorkerParameters) :
    CoroutineWorker(context, workerParams), MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel

  override suspend fun doWork(): Result {
    engineMutex.withLock {
      if (engine == null) {
        try {
          initializeFlutterEngine()
        } catch (e: CancellationException) {
          // Rethrow to respect cooperative cancellation. Swallowing this
          // would prevent CoroutineWorker from handling worker stoppage
          // correctly (e.g. OS killing the process, constraints changing).
          resetEngine()
          throw e
        } catch (e: Exception) {
          Log.e(TAG, "Failed to initialize Flutter engine", e)
          // Reset engine state so the next work item can retry initialization
          // from a clean state instead of using a partially initialized engine.
          resetEngine()
          // Queue this work item's data so it is not silently lost. When a
          // subsequent worker succeeds in starting the engine and Dart calls
          // backgroundInitialized, the queued callback will be dispatched.
          val data = inputData.getString(DATA_KEY) ?: ""
          val args = listOf(HomeWidgetPlugin.getHandle(context), data)
          synchronized(serviceStarted) {
            queue.add(args)
          }
          // Return success to prevent poisoning the APPEND work chain.
          // Returning failure would cancel all subsequently appended work items
          // because WorkManager treats a failed item in an APPEND chain as a
          // signal to cancel every downstream item. The chain state is persisted
          // in WorkManager's database and survives process restarts, effectively
          // breaking all future background callbacks until app data is cleared.
          // Output data carries the failure signal for observability.
          return Result.success(
              Data.Builder()
                  .putBoolean("engine_init_failed", true)
                  .putString("error", e.message ?: "Unknown error")
                  .build()
          )
        }
      }
    }

    // Defensive null check: engine could theoretically become null if
    // resetEngine() is called between the mutex release above and here.
    engine?.let {
      channel = MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL_NAME)
      channel.setMethodCallHandler(this)
    } ?: run {
      Log.w(TAG, "Flutter engine is null after initialization, skipping callback")
      return Result.success()
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
          "No callbackHandle saved. Did you call HomeWidget.registerBackgroundCallback?"
      )
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
              callbackInfo,
          )
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

    private val engineMutex = Mutex()
    @Volatile private var engine: FlutterEngine? = null
    private val queue = ArrayDeque<List<Any>>()
    private val serviceStarted = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun resetEngine() {
      val engineToDestroy = engine
      engine = null
      serviceStarted.set(false)
      // Do not clear the queue: pending callbacks from earlier workers
      // should still be dispatched once a new engine initializes successfully.
      // Destroy the engine on the main thread as required by FlutterEngine.
      if (engineToDestroy != null) {
        mainHandler.post {
          try {
            engineToDestroy.destroy()
          } catch (e: Exception) {
            Log.w(TAG, "Error destroying Flutter engine", e)
          }
        }
      }
    }

    fun enqueueWork(context: Context, work: Intent) {
      val data = Data.Builder().putString(DATA_KEY, work.data?.toString() ?: "").build()

      val workRequest =
          OneTimeWorkRequestBuilder<HomeWidgetBackgroundWorker>().setInputData(data).build()

      // Use APPEND_OR_REPLACE instead of APPEND to prevent work chain
      // poisoning. With APPEND, if any work item in the chain fails, all
      // subsequently appended items are immediately cancelled by WorkManager.
      // This failure state is persisted in WorkManager's SQLite database and
      // survives process death, force stop, and device reboots — permanently
      // breaking background callbacks until the user clears app data.
      // APPEND_OR_REPLACE replaces the chain if it has failed or been
      // cancelled, allowing recovery without user intervention.
      WorkManager.getInstance(context)
          .enqueueUniqueWork(UNIQUE_WORK_NAME, ExistingWorkPolicy.APPEND_OR_REPLACE, workRequest)
    }
  }
}
