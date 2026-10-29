package es.antonborri.home_widget

import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Receives the alarms armed by [HomeWidgetScheduler] and updates the corresponding Widget.
 *
 * It also listens for `BOOT_COMPLETED` and `ACTION_MY_PACKAGE_REPLACED` because alarms are dropped
 * by the system on reboot and on app updates, and for
 * `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` (API 31+) because revoking the
 * `SCHEDULE_EXACT_ALARM` special app access makes the system cancel all of the app's exact alarms;
 * that broadcast is the system's signal that the permission was re-granted.
 *
 * The plugin does not register this receiver so that apps which never schedule an update do not
 * inherit the boot permission. Apps that use `HomeWidget.scheduleWidgetUpdates` have to add it to
 * their own `AndroidManifest.xml`:
 * ```xml
 * <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
 *
 * <application>
 *     <receiver
 *         android:name="es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver"
 *         android:exported="false">
 *         <intent-filter>
 *             <action android:name="android.intent.action.BOOT_COMPLETED" />
 *             <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
 *             <action android:name="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />
 *         </intent-filter>
 *     </receiver>
 * </application>
 * ```
 *
 * The receiver is not exported; `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` and
 * `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` are protected system broadcasts which are
 * delivered regardless.
 */
class HomeWidgetScheduledUpdateReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      HomeWidgetScheduler.ACTION_SCHEDULED_UPDATE -> {
        val providerClassName =
            intent.getStringExtra(HomeWidgetScheduler.EXTRA_PROVIDER_CLASS_NAME) ?: return
        if (updateWidget(context, providerClassName)) {
          HomeWidgetScheduler.pruneAndArmNext(context, providerClassName, catchUp = false)
        } else {
          HomeWidgetScheduler.cancel(context, providerClassName)
        }
      }
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_MY_PACKAGE_REPLACED,
      AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
        HomeWidgetScheduler.rescheduleAll(context)
      }
    }
  }

  companion object {
    /**
     * Mirrors the broadcast that `HomeWidgetPlugin`'s `updateWidget` sends.
     *
     * The broadcast is skipped while no instance of the Widget is on the HomeScreen; the stored
     * times are kept so that a Widget added later resumes the schedule.
     *
     * Returns `false` when the Widget no longer exists, in which case the caller must drop the
     * schedule instead of re-arming it.
     */
    internal fun updateWidget(context: Context, providerClassName: String): Boolean {
      val javaClass =
          try {
            Class.forName(providerClassName)
          } catch (classException: ClassNotFoundException) {
            // The Widget was removed or renamed since the update was scheduled.
            return false
          }
      val ids: IntArray =
          AppWidgetManager.getInstance(context.applicationContext)
              .getAppWidgetIds(ComponentName(context.applicationContext, javaClass))
      if (ids.isEmpty()) {
        return true
      }
      val updateIntent = Intent(context.applicationContext, javaClass)
      updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
      updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
      updateIntent.putExtra(HomeWidgetPlugin.TRIGGERED_FROM_HOME_WIDGET, true)
      context.sendBroadcast(updateIntent)
      return true
    }
  }
}
