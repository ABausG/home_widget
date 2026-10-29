package es.antonborri.home_widget

import android.app.Activity
import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.glance.GlanceId
import androidx.glance.action.Action
import androidx.glance.action.ActionParameters
import androidx.glance.action.mutableActionParametersOf
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionStartActivity

object HomeWidgetLaunchIntent {

  const val HOME_WIDGET_LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"

  fun <T> getActivity(context: Context, activityClass: Class<T>, uri: Uri? = null): PendingIntent
      where T : Activity {
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
    if (Build.VERSION.SDK_INT >= 35) {
      options.setPendingIntentCreatorBackgroundActivityStartMode(
          ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
      )
    } else if (Build.VERSION.SDK_INT >= 34) {
      options.pendingIntentBackgroundActivityStartMode =
          ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
    }

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

  /** Intent extra naming the registered callback that should receive the interaction. */
  const val EXTRA_CALLBACK_KEY = "es.antonborri.home_widget.extra.CALLBACK_KEY"

  fun getBroadcast(context: Context, uri: Uri? = null): PendingIntent =
      getBroadcast(context, uri, null)

  /**
   * A broadcast that runs the callback registered with [key] in Dart. Falls back to the callback
   * registered without a key when [key] is `null` or nothing was registered for it.
   */
  fun getBroadcast(context: Context, uri: Uri?, key: String?): PendingIntent {
    var flags = PendingIntent.FLAG_UPDATE_CURRENT
    if (Build.VERSION.SDK_INT >= 23) {
      flags = flags or PendingIntent.FLAG_IMMUTABLE
    }

    // Extras are not part of a PendingIntent's identity, so each key needs its own request code.
    return PendingIntent.getBroadcast(
        context,
        key?.hashCode() ?: 0,
        getIntent(context, uri, key),
        flags,
    )
  }

  internal fun getIntent(context: Context, uri: Uri?, key: String?): Intent {
    val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java)
    intent.data = uri
    intent.action = HOME_WIDGET_BACKGROUND_ACTION
    if (key != null) {
      intent.putExtra(EXTRA_CALLBACK_KEY, key)
    }
    return intent
  }
}

/**
 * A Glance action that runs a Dart callback registered with
 * `HomeWidget.registerInteractivityCallback`, without opening the app.
 *
 * Pass the Uri the callback receives and, optionally, the key it was registered with:
 * ```
 * GlanceModifier.clickable(
 *     actionRunCallback<HomeWidgetInteractivityAction>(
 *         HomeWidgetInteractivityAction.parameters(uri, key)))
 * ```
 */
class HomeWidgetInteractivityAction : ActionCallback {
  override suspend fun onAction(
      context: Context,
      glanceId: GlanceId,
      parameters: ActionParameters,
  ) {
    val uri = parameters[UriKey]?.let(Uri::parse)
    context.sendBroadcast(
        HomeWidgetBackgroundIntent.getIntent(context, uri, parameters[CallbackKey])
    )
  }

  companion object {
    /** The Uri passed to the Dart callback, as a string. */
    val UriKey = ActionParameters.Key<String>("es.antonborri.home_widget.interactivity.uri")

    /** The key the Dart callback was registered with. */
    val CallbackKey = ActionParameters.Key<String>("es.antonborri.home_widget.interactivity.key")

    fun parameters(uri: Uri?, key: String? = null): ActionParameters {
      val parameters = mutableActionParametersOf()
      if (uri != null) parameters[UriKey] = uri.toString()
      if (key != null) parameters[CallbackKey] = key
      return parameters
    }
  }
}
