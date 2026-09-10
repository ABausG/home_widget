// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.ConfigurationCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin

class GreetingHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  override suspend fun providePreview(context: Context, widgetCategory: Int) {
    provideContent {
      WidgetContent(
          context,
          HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)),
          preview = true,
      )
    }
  }

  fun previewFingerprint(context: Context): String {
    val hwPreviewData = GreetingData.previewFromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "c9486ef3",
            ConfigurationCompat.getLocales(context.resources.configuration).toLanguageTags(),
            hwPreviewData.toString(),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(
      context: Context,
      currentState: HomeWidgetGlanceState,
      preview: Boolean = false,
  ) {
    val prefs = currentState.preferences
    val widgetData =
        if (preview) GreetingData.previewFromPreferences(prefs)
        else GreetingData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(horizontalAlignment = Alignment.Start) {
          Text(text = "Hello", style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal))
          Text(
              text = widgetData.name ?: "",
              style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
          )
        }
      }
    }
  }
}

data class GreetingData(
    val name: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.Greeting"

    fun fromPreferences(prefs: android.content.SharedPreferences): GreetingData {
      return GreetingData(
          name = prefs.getString("${PREFERENCES_PREFIX}.name", "world"),
      )
    }

    fun previewFromPreferences(prefs: android.content.SharedPreferences): GreetingData {
      return GreetingData(
          name = prefs.getString("${PREFERENCES_PREFIX}.name", "Anton"),
      )
    }
  }
}
