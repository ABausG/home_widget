package es.antonborri.home_widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.*


/** HomeWidgetPlugin */
class HomeWidgetPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "home_widget")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "saveWidgetData") {
      if (call.hasArgument("id") && call.hasArgument("data")) {
        val id = call.argument<String>("id")
        val data = call.argument<String>("data")
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
        prefs.putString(id, data)
        result.success(prefs.commit())
      } else {
        result.error("-1", "InvalidArguments saveWidgetData must be called with id and data", IllegalArgumentException())
      }
    } else if (call.method == "getWidgetData") {
      if (call.hasArgument("id")) {
        val id = call.argument<String>("id")
        val defaultValue = call.argument<String?>("defaultValue")
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        result.success(prefs.getString(id, defaultValue))
      } else {
        result.error("-2", "InvalidArguments getWidgetData must be called with id", IllegalArgumentException())
      }
    } else if (call.method == "updateWidget") {
      val className = call.argument<String>("name")
      try {
      val javaClass = Class.forName("${context.getPackageName()}.${className}")
      val intent = Intent(context, javaClass)
      intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
      val ids: IntArray = AppWidgetManager.getInstance(context.applicationContext).getAppWidgetIds(ComponentName(context, javaClass))
      intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
      context.sendBroadcast(intent)
      } catch (classException : ClassNotFoundException) {
        result.error("-3", "No Widget found with Name $className. Argument 'name' must be the same as your AppWidgetProvider you wish to update", classException)
      }
    } else if(call.method == "setAppGroupId") {
      result.success(true)
    } else
    {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  companion object {
    private const val PREFERENCES = "HomeWidgetPreferences"

    fun getData(context: Context) : SharedPreferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
  }
}
