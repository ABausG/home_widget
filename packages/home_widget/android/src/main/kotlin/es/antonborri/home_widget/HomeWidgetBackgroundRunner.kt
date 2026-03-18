package es.antonborri.home_widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
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
import kotlinx.coroutines.withContext

object HomeWidgetBackgroundRunner : MethodChannel.MethodCallHandler {
  private const val CHANNEL_NAME = "home_widget/background"

  @Volatile private var engine: FlutterEngine? = null
  private val queue = ArrayDeque<List<Any>>()
  private val serviceStarted = AtomicBoolean(false)
  private val mainHandler = Handler(Looper.getMainLooper())
  private var channel: MethodChannel? = null

  fun execute(context: Context, intent: Intent, pendingResult: BroadcastReceiver.PendingResult) {
    CoroutineScope(Dispatchers.Default).launch {
      try {
        if (engine == null) {
          initializeFlutterEngine(context)
        }

        engine?.let {
          channel = MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL_NAME)
          channel?.setMethodCallHandler(this@HomeWidgetBackgroundRunner)
        }

        val data = intent.data?.toString() ?: ""
        val args = listOf(HomeWidgetPlugin.getHandle(context), data)
        synchronized(serviceStarted) {
          if (!serviceStarted.get()) {
            queue.add(args)
          } else {
            mainHandler.post { channel?.invokeMethod("", args) }
          }
        }
      } finally {
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
        val args = queue.remove()
        mainHandler.post { channel?.invokeMethod("", args) }
      }
      serviceStarted.set(true)
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
}
