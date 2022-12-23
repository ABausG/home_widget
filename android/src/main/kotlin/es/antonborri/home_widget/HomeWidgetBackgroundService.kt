package es.antonborri.home_widget

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.util.Log
import androidx.core.app.JobIntentService
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import java.util.*
import java.util.concurrent.atomic.AtomicBoolean

class HomeWidgetBackgroundService : MethodChannel.MethodCallHandler, JobIntentService() {

    private val queue = ArrayDeque<List<Any>>()
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        private const val TAG = "HomeWidgetService"
        private val JOB_ID = UUID.randomUUID().mostSignificantBits.toInt()
        private var engine: FlutterEngine? = null

        private val serviceStarted = AtomicBoolean(false)

        fun enqueueWork(context: Context, work: Intent) {
            enqueueWork(context, HomeWidgetBackgroundService::class.java, JOB_ID, work)
        }
    }

    override fun onCreate() {
        super.onCreate()
        synchronized(serviceStarted) {
            context = this
            if (engine == null) {
                val callbackHandle = HomeWidgetPlugin.getDispatcherHandle(context)

                if (callbackHandle == 0L) {
                    Log.e(TAG, "No callbackHandle saved. Did you call HomeWidget.registerBackgroundCallback?")
                }

                engine = FlutterEngine(context)
                
                val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

                

                val callback = DartExecutor.DartCallback(
                        context.assets,
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        callbackInfo
                )
                engine?.dartExecutor?.executeDartCallback(callback)
            }
        }
        channel = MethodChannel(engine!!.getDartExecutor().getBinaryMessenger(),
                "home_widget/background")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "HomeWidget.backgroundInitialized") {
            synchronized(serviceStarted) {
                while (!queue.isEmpty()) {
                    channel.invokeMethod("", queue.remove())
                }
                serviceStarted.set(true)
            }
        }
    }

    override fun onHandleWork(intent: Intent) {
        val data = intent.data?.toString() ?: ""
        val args = listOf(
                HomeWidgetPlugin.getHandle(context),
                data
        )

        synchronized(serviceStarted) {
            if (!serviceStarted.get()) {
                queue.add(args)
            } else {
                Handler(context.mainLooper).post { channel.invokeMethod("", args) }
            }
        }
    }
}
