package es.antonborri.home_widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

object HomeWidgetBackgroundRunner : MethodChannel.MethodCallHandler {
  private const val TAG = "HomeWidgetRunner"
  private const val CHANNEL_NAME = "home_widget/background"

  @Volatile private var engine: FlutterEngine? = null
  @Volatile private var channel: MethodChannel? = null
  private val queue = ArrayDeque<PendingWork>()
  private val serviceStarted = AtomicBoolean(false)
  private val mainHandler = Handler(Looper.getMainLooper())
  private val initMutex = Mutex()

  private data class PendingWork(
      val args: List<Any>,
      val pendingResult: BroadcastReceiver.PendingResult,
  )

  fun execute(context: Context, intent: Intent, pendingResult: BroadcastReceiver.PendingResult) {
    CoroutineScope(Dispatchers.Default).launch {
      try {
        ensureEngineInitialized(context)

        val data = intent.data?.toString() ?: ""
        val args = listOf(HomeWidgetPlugin.getHandle(context), data)
        synchronized(serviceStarted) {
          if (!serviceStarted.get()) {
            queue.add(PendingWork(args, pendingResult))
          } else {
            dispatchToChannel(args, pendingResult)
          }
        }
      } catch (e: Throwable) {
        Log.e(TAG, "Error executing background callback", e)
        pendingResult.finish()
      }
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
        val work = queue.remove()
        dispatchToChannel(work.args, work.pendingResult)
      }
      serviceStarted.set(true)
    }
  }

  private fun dispatchToChannel(
      args: List<Any>,
      pendingResult: BroadcastReceiver.PendingResult,
  ) {
    mainHandler.post {
      val ch = channel
      if (ch == null) {
        pendingResult.finish()
        return@post
      }
      // Empty method name is the expected protocol for the "home_widget/background"
      // channel — the Dart side treats every invokeMethod call as a background
      // callback trigger regardless of method name.
      ch.invokeMethod("", args, object : MethodChannel.Result {
        override fun success(result: Any?) { pendingResult.finish() }
        override fun error(code: String, message: String?, details: Any?) { pendingResult.finish() }
        override fun notImplemented() { pendingResult.finish() }
      })
    }
  }

  private suspend fun ensureEngineInitialized(context: Context) {
    if (engine != null) return
    initMutex.withLock {
      if (engine != null) return
      initializeFlutterEngine(context)
    }
  }

  private suspend fun initializeFlutterEngine(context: Context) {
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
      try {
        engine = FlutterEngine(context)
        val callback =
            DartExecutor.DartCallback(
                context.assets,
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                callbackInfo,
            )
        engine?.dartExecutor?.executeDartCallback(callback)
        engine?.let {
          channel = MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL_NAME)
          channel?.setMethodCallHandler(this@HomeWidgetBackgroundRunner)
        }
      } catch (e: Throwable) {
        Log.e(
            TAG,
            "Failed to initialize FlutterEngine (callbackHandle=$callbackHandle, callbackInfo=$callbackInfo)",
            e,
        )
        engine = null
        channel = null
        throw e
      }
    }
  }
}
