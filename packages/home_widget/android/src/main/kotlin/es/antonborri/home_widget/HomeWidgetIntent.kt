package es.antonborri.home_widget

import android.app.Activity
import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.glance.action.Action
import androidx.glance.appwidget.action.actionStartActivity

object HomeWidgetLaunchIntent {

    const val HOME_WIDGET_LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"

    fun <T> getActivity(context: Context, activityClass: Class<T>, uri: Uri? = null): PendingIntent where T : Activity {
        val intent = Intent(context, activityClass)
        intent.data = uri
        intent.action = HOME_WIDGET_LAUNCH_ACTION

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        if (Build.VERSION.SDK_INT < 34) {
            return PendingIntent.getActivity(context, 0, intent, flags)
        }

        val options = ActivityOptions.makeBasic()
        options.pendingIntentBackgroundActivityStartMode = ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED

        return PendingIntent.getActivity(context, 0, intent, flags, options.toBundle())
    }
}

inline fun <reified T : Activity> actionStartActivity(context: Context, uri: Uri? = null): Action {
    val intent = Intent(context, T::class.java)
    intent.data = uri
    intent.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION

    return actionStartActivity(intent)
}


object HomeWidgetBackgroundIntent {
    private const val HOME_WIDGET_BACKGROUND_ACTION = "es.antonborri.home_widget.action.BACKGROUND"

    fun getBroadcast(context: Context, uri: Uri? = null): PendingIntent {
        val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java)
        intent.data = uri
        intent.action = HOME_WIDGET_BACKGROUND_ACTION

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }
}