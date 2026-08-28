package es.antonborri.home_widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * Schedules Widget updates at specific points in time.
 *
 * For every AppWidgetProvider a list of update times (epoch milliseconds, UTC) is persisted.
 * Exactly one `AlarmManager` alarm is armed per provider, always for the next future time. When it
 * fires [HomeWidgetScheduledUpdateReceiver] broadcasts an `ACTION_APPWIDGET_UPDATE` to the
 * provider, drops the times that have passed and arms the alarm for the next one.
 *
 * This is a public API. It can be used from Dart via `HomeWidget.scheduleWidgetUpdates` or directly
 * from native code:
 * ```kotlin
 * HomeWidgetScheduler.schedule(
 *     context,
 *     "com.example.app.MyWidgetProvider",
 *     listOf(System.currentTimeMillis() + 60_000),
 * )
 * ```
 *
 * Apps that use scheduling have to register [HomeWidgetScheduledUpdateReceiver] in their own
 * `AndroidManifest.xml`; the plugin does not declare it so that apps which never schedule an update
 * do not inherit the boot permission. See [HomeWidgetScheduledUpdateReceiver] for the required
 * manifest entry.
 *
 * Note on exactness: on Android 12 (API 31) and above exact alarms require the app to hold the
 * `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` permission. The plugin deliberately does not declare
 * either of them so apps can decide themselves. If the permission is missing the updates are still
 * scheduled, just inexact, and may be delayed by the system.
 */
object HomeWidgetScheduler {
  private const val TAG = "HomeWidgetScheduler"
  private const val SCHEDULE_PREFIX = "scheduledUpdates."

  /** Action of the Intent that is broadcast when a scheduled update is due. */
  const val ACTION_SCHEDULED_UPDATE = "es.antonborri.home_widget.action.SCHEDULED_UPDATE"

  /** Extra holding the qualified class name of the AppWidgetProvider that should be updated. */
  const val EXTRA_PROVIDER_CLASS_NAME = "providerClassName"

  /**
   * Replaces the scheduled updates of [providerClassName] with [updateTimes].
   *
   * [providerClassName] is the fully qualified class name of the AppWidgetProvider. [updateTimes]
   * are epoch milliseconds in UTC. Times in the past are ignored, passing an empty list (or a list
   * with only past times) is equivalent to calling [cancel].
   */
  fun schedule(context: Context, providerClassName: String, updateTimes: List<Long>) {
    val now = System.currentTimeMillis()
    val upcoming = updateTimes.filter { it > now }.distinct().sorted()
    if (upcoming.isEmpty()) {
      cancel(context, providerClassName)
      return
    }
    warnIfReceiverMissing(context)
    saveTimes(context, providerClassName, upcoming)
    armNext(context, providerClassName, upcoming)
  }

  /** Cancels all scheduled updates of [providerClassName] and forgets its stored times. */
  fun cancel(context: Context, providerClassName: String) {
    cancelAlarm(context, providerClassName)
    context
        .getSharedPreferences(HomeWidgetPlugin.INTERNAL_PREFERENCES, Context.MODE_PRIVATE)
        .edit()
        .remove("$SCHEDULE_PREFIX$providerClassName")
        .apply()
  }

  /**
   * Drops all times that have passed for [providerClassName] and arms the alarm for the next one.
   *
   * Called after an alarm fired to advance to the following update time.
   */
  fun pruneAndArmNext(context: Context, providerClassName: String) {
    val upcoming = loadTimes(context, providerClassName).filter { it > System.currentTimeMillis() }
    if (upcoming.isEmpty()) {
      cancel(context, providerClassName)
      return
    }
    saveTimes(context, providerClassName, upcoming)
    armNext(context, providerClassName, upcoming)
  }

  /**
   * Re-arms the alarms of every provider that has scheduled updates.
   *
   * Alarms do not survive a reboot or an app update, so this is called from
   * [HomeWidgetScheduledUpdateReceiver] on `BOOT_COMPLETED` and `ACTION_MY_PACKAGE_REPLACED`. It is
   * also called when the user re-grants `SCHEDULE_EXACT_ALARM` after revoking it, since revocation
   * makes the system delete all of the app's exact alarms and only re-granting the permission (or a
   * reboot) triggers a broadcast that lets the app know to re-arm them.
   */
  fun rescheduleAll(context: Context) {
    val prefs =
        context.getSharedPreferences(
            HomeWidgetPlugin.INTERNAL_PREFERENCES,
            Context.MODE_PRIVATE,
        )
    val providerClassNames =
        prefs.all.keys
            .filter { it.startsWith(SCHEDULE_PREFIX) }
            .map { it.removePrefix(SCHEDULE_PREFIX) }
    for (providerClassName in providerClassNames) {
      pruneAndArmNext(context, providerClassName)
    }
  }

  /**
   * Logs a warning when the app forgot to register [HomeWidgetScheduledUpdateReceiver].
   *
   * The alarm is armed with an explicit PendingIntent, so an unregistered receiver simply never
   * receives it and the Widget is silently never updated. Scheduling still proceeds; this warning
   * is the developer's signal that the manifest entry is missing.
   */
  private fun warnIfReceiverMissing(context: Context) {
    val component =
        ComponentName(context.applicationContext, HomeWidgetScheduledUpdateReceiver::class.java)
    try {
      context.packageManager.getReceiverInfo(component, 0)
    } catch (e: PackageManager.NameNotFoundException) {
      Log.w(
          TAG,
          "HomeWidgetScheduledUpdateReceiver is not registered in the app's AndroidManifest.xml. " +
              "Scheduled Widget updates will not be delivered. Add:\n" +
              "<uses-permission android:name=\"android.permission.RECEIVE_BOOT_COMPLETED\" />\n" +
              "<receiver android:name=\"es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver\" " +
              "android:exported=\"false\">\n" +
              "  <intent-filter>\n" +
              "    <action android:name=\"android.intent.action.BOOT_COMPLETED\" />\n" +
              "    <action android:name=\"android.intent.action.MY_PACKAGE_REPLACED\" />\n" +
              "    <action android:name=\"android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED\" />\n" +
              "  </intent-filter>\n" +
              "</receiver>",
      )
    }
  }

  private fun armNext(context: Context, providerClassName: String, upcoming: List<Long>) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
    val triggerAtMillis = upcoming.first()
    val pendingIntent = createPendingIntent(context, providerClassName) ?: return

    when {
      // Android 12+ only grants exact alarms to apps holding
      // SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM.
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
        if (alarmManager.canScheduleExactAlarms()) {
          alarmManager.setExactAndAllowWhileIdle(
              AlarmManager.RTC_WAKEUP,
              triggerAtMillis,
              pendingIntent,
          )
        } else {
          alarmManager.setAndAllowWhileIdle(
              AlarmManager.RTC_WAKEUP,
              triggerAtMillis,
              pendingIntent,
          )
        }
      }
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
          alarmManager.setExactAndAllowWhileIdle(
              AlarmManager.RTC_WAKEUP,
              triggerAtMillis,
              pendingIntent,
          )
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT ->
          alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
      else -> alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
    }
  }

  /**
   * Cancels the alarm of [providerClassName] if one is currently armed.
   *
   * `FLAG_NO_CREATE` makes the lookup return `null` instead of creating a new PendingIntent when
   * nothing is armed, so cancelling an unscheduled provider is a no-op.
   */
  private fun cancelAlarm(context: Context, providerClassName: String) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
    val pendingIntent =
        createPendingIntent(context, providerClassName, PendingIntent.FLAG_NO_CREATE) ?: return
    alarmManager.cancel(pendingIntent)
    pendingIntent.cancel()
  }

  /**
   * PendingIntents are matched without their extras, so the provider is encoded in the data Uri and
   * the request code to keep one distinct alarm per provider.
   *
   * Returns `null` only when [baseFlags] contains `FLAG_NO_CREATE` and no matching PendingIntent
   * exists.
   */
  private fun createPendingIntent(
      context: Context,
      providerClassName: String,
      baseFlags: Int = PendingIntent.FLAG_UPDATE_CURRENT,
  ): PendingIntent? {
    val intent =
        Intent(context.applicationContext, HomeWidgetScheduledUpdateReceiver::class.java).apply {
          action = ACTION_SCHEDULED_UPDATE
          data = Uri.parse("homewidget://scheduled/$providerClassName")
          putExtra(EXTRA_PROVIDER_CLASS_NAME, providerClassName)
        }
    var flags = baseFlags
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      flags = flags or PendingIntent.FLAG_IMMUTABLE
    }
    return PendingIntent.getBroadcast(
        context.applicationContext,
        providerClassName.hashCode(),
        intent,
        flags,
    )
  }

  private fun saveTimes(context: Context, providerClassName: String, times: List<Long>) {
    val array = JSONArray()
    for (time in times) {
      array.put(time)
    }
    context
        .getSharedPreferences(HomeWidgetPlugin.INTERNAL_PREFERENCES, Context.MODE_PRIVATE)
        .edit()
        .putString("$SCHEDULE_PREFIX$providerClassName", array.toString())
        .apply()
  }

  private fun loadTimes(context: Context, providerClassName: String): List<Long> {
    val stored =
        context
            .getSharedPreferences(HomeWidgetPlugin.INTERNAL_PREFERENCES, Context.MODE_PRIVATE)
            .getString("$SCHEDULE_PREFIX$providerClassName", null) ?: return emptyList()
    return try {
      val array = JSONArray(stored)
      val times = mutableListOf<Long>()
      for (index in 0 until array.length()) {
        times.add(array.getLong(index))
      }
      times.sorted()
    } catch (e: org.json.JSONException) {
      emptyList()
    }
  }
}
