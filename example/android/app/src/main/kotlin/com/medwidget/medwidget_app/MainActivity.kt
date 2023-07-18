package com.medwidget.medwidget_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

import android.app.NotificationChannel

import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import android.util.Log


class MainActivity: FlutterActivity() {
    private val channelName = "your_channel_name"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        Log.d("configureFlutterEngine","start")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "listenForDeviceUnlock") {
                // Device unlock event received, show a notification
                showNotification("Device Unlocked", "Welcome back!")
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun showNotification(title: String, message: String) {
        print("{title} {message}")
        Log.d("configureFlutterEngine","Device Unlocked")
        /*
        val context = this
        val channelId = "channel_id"
        val channelName = "channel_name"
        val channelDescription = "channel_description"
        val importance = NotificationManager.IMPORTANCE_DEFAULT

        val channel = NotificationChannel(channelId, channelName, importance)
        channel.description = channelDescription

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(true)

        with(NotificationManagerCompat.from(context)) {
            notify(0, builder.build())
        }
         */
    }
}
