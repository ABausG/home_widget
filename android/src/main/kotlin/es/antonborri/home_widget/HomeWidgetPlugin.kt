package es.antonborri.home_widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.*
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry


/** HomeWidgetPlugin */
class HomeWidgetPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
        EventChannel.StreamHandler, PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private var activity: Activity? = null
    private var receiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "home_widget")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "home_widget/updates")
        eventChannel.setStreamHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "saveWidgetData" -> {
                if (call.hasArgument("id") && call.hasArgument("data")) {
                    val id = call.argument<String>("id")
                    val data = call.argument<Any>("data")
                    val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
                    when (data) {
                        is Boolean -> prefs.putBoolean(id, data)
                        is Float -> prefs.putFloat(id, data)
                        is String -> prefs.putString(id, data)
                        is Double -> prefs.putLong(id, data.toLong())
                        is Long -> prefs.putLong(id, data)
                        is Int -> prefs.putInt(id, data)
                        else -> result.error("-10", "Invalid Type ${data!!::class.java.simpleName}. Supported types are Boolean, Float, String, Double, Long", IllegalArgumentException())
                    }
                    result.success(prefs.commit())
                } else {
                    result.error("-1", "InvalidArguments saveWidgetData must be called with id and data", IllegalArgumentException())
                }
            }
            "getWidgetData" -> {
                if (call.hasArgument("id")) {
                    val id = call.argument<String>("id")
                    val defaultValue = call.argument<Any>("defaultValue")

                    val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

                    val value = prefs.all[id] ?: defaultValue
                    result.success(value)
                } else {
                    result.error("-2", "InvalidArguments getWidgetData must be called with id", IllegalArgumentException())
                }
            }
            "updateWidget" -> {
                val className = call.argument<String>("android") ?: call.argument<String>("name")
                try {
                    val javaClass = Class.forName("${context.packageName}.${className}")
                    val intent = Intent(context, javaClass)
                    intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids: IntArray = AppWidgetManager.getInstance(context.applicationContext).getAppWidgetIds(ComponentName(context, javaClass))
                    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    context.sendBroadcast(intent)
                } catch (classException: ClassNotFoundException) {
                    result.error("-3", "No Widget found with Name $className. Argument 'name' must be the same as your AppWidgetProvider you wish to update", classException)
                }
            }
            "setAppGroupId" -> {
                result.success(true)
            }
            "initiallyLaunchedFromHomeWidget" -> {
                return if (activity?.intent?.action?.equals(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) == true) {
                    result.success(activity?.intent?.data?.toString() ?: true)
                } else {
                    result.success(null)
                }
            }
            "registerBackgroundCallback" -> {
                val dispatcher = (call.arguments as Iterable<*>).toList()[0] as Long
                val callback = (call.arguments as Iterable<*>).toList()[1] as Long
                saveCallbackHandle(context, dispatcher, callback)
                return result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val PREFERENCES = "HomeWidgetPreferences"

        private const val INTERNAL_PREFERENCES = "InternalHomeWidgetPreferences"
        private const val CALLBACK_DISPATCHER_HANDLE = "callbackDispatcherHandle"
        private const val CALLBACK_HANDLE = "callbackHandle"

        private fun saveCallbackHandle(context: Context, dispatcher: Long, handle: Long) {
            context.getSharedPreferences(INTERNAL_PREFERENCES, Context.MODE_PRIVATE)
                    .edit()
                    .putLong(CALLBACK_DISPATCHER_HANDLE, dispatcher)
                    .putLong(CALLBACK_HANDLE, handle)
                    .apply()
        }

        fun getDispatcherHandle(context: Context): Long =
                context.getSharedPreferences(INTERNAL_PREFERENCES, Context.MODE_PRIVATE).getLong(CALLBACK_DISPATCHER_HANDLE, 0)

        fun getHandle(context: Context): Long =
                context.getSharedPreferences(INTERNAL_PREFERENCES, Context.MODE_PRIVATE).getLong(CALLBACK_HANDLE, 0)

        fun getData(context: Context): SharedPreferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        context.unregisterReceiver(receiver)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        context.unregisterReceiver(receiver)
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        receiver = createReceiver(events)
    }

    override fun onCancel(arguments: Any?) {
        receiver = null
    }

    private fun createReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action.equals(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)) {
                    events?.success(intent?.data?.toString() ?: true)
                }
            }

        }
    }

    override fun onNewIntent(intent: Intent?): Boolean {
        receiver?.onReceive(context, intent)
        return receiver != null
    }
}
