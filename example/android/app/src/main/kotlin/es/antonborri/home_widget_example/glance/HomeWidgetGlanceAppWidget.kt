package es.antonborri.home_widget_example.glance

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget_example.MainActivity

class HomeWidgetGlanceAppWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        Log.e("WIDGET_LOG", "Provide Clance")
        provideContent {
            GlanceContent(context)
        }
    }

    @Composable
    private fun GlanceContent(context: Context) {
        val data = HomeWidgetPlugin.getData(context)
        val imagePath = data.getString("dashIcon", null)

        val title = data.getString("title", "")!!
        val message = data.getString("message", "")!!

        Box(
                modifier = GlanceModifier
                        .background(Color.White)
                        .padding(16.dp)
                        .clickable(onClick = actionRunCallback<OpenAppAction>())
        ) {
            Column(
                    modifier = GlanceModifier.fillMaxSize(),
                    verticalAlignment = Alignment.Vertical.Top,
                    horizontalAlignment = Alignment.Horizontal.Start,
            ) {
                Text("Glance")
                Text(
                        title,
                        style = TextStyle(fontSize = 36.sp, fontWeight = FontWeight.Bold),
                        modifier = GlanceModifier.clickable(onClick = actionRunCallback<InteractiveAction>())
                )
                Text(
                        message,
                        style = TextStyle(fontSize = 18.sp)
                )
                imagePath?.let {
                    val bitmap = BitmapFactory.decodeFile(it)
                    Image(androidx.glance.ImageProvider(bitmap), null)
                }
            }
        }
    }
}

class OpenAppAction : ActionCallback {
    companion object {
        const val MESSAGE_KEY = "OpenAppActionMessageKey"
    }

    override suspend fun onAction(
            context: Context, glanceId: GlanceId, parameters: ActionParameters
    ) {
        val message = parameters[ActionParameters.Key<String>(MESSAGE_KEY)]

        val pendingIntentWithData = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("homeWidgetExample://message?message=$message")
        )

        pendingIntentWithData.send()
    }
}

class InteractiveAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("homeWidgetExample://titleClicked")
        )
        backgroundIntent.send()
    }
}