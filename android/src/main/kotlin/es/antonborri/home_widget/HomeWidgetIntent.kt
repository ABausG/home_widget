package es.antonborri.home_widget

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

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

        return PendingIntent.getActivity(context, 0, intent, flags)
    }
}


object HomeWidgetBackgroundIntent {
    private const val HOME_WIDGET_BACKGROUND_ACTION = "es.antonborri.home_widget.action.BACKGROUND"

    @JvmOverloads
    fun getBroadcast(context: Context, uri: Uri? = null, toast: String? = null): PendingIntent {
        val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java)
        intent.data = uri
        intent.action = HOME_WIDGET_BACKGROUND_ACTION
        if (toast != null) {
            intent.putExtra("toast", toast)
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }
}