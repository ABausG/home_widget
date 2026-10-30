// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.ConfigurationCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.actionStartActivity
import java.util.Date
import java.util.Locale

class WidgetLinkHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  override suspend fun providePreview(context: Context, widgetCategory: Int) {
    provideContent {
      WidgetContent(context, HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)))
    }
  }

  fun previewFingerprint(context: Context): String {
    val hwLocales = hwCurrentLocales(context)
    val hwPreviewData = WidgetLinkData.fromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "42ca801d",
            hwLocales.joinToString(","),
            hwPreviewData.toString(),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = WidgetLinkData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(
                      onClick =
                          actionStartActivity<MainActivity>(
                              context,
                              Uri.parse("generatorBasics://link?homeWidget"),
                          )
                  ),
          contentAlignment = Alignment.Center,
      ) {
        Column(horizontalAlignment = Alignment.Start) {
          Text(
              text = "Tap me",
              style =
                  TextStyle(
                      color = GlanceTheme.colors.onSurface,
                      fontSize = 12.sp,
                      fontWeight = FontWeight.Normal,
                  ),
          )
          Text(
              modifier = GlanceModifier.padding(top = 8.0.dp),
              text = "Opens the app",
              style =
                  TextStyle(
                      color = GlanceTheme.colors.onSurface,
                      fontSize = 22.sp,
                      fontWeight = FontWeight.Bold,
                  ),
          )
          Row(
              modifier = GlanceModifier.padding(top = 8.0.dp),
              verticalAlignment = Alignment.CenterVertically,
          ) {
            Text(
                modifier =
                    GlanceModifier.clickable(
                        onClick =
                            actionStartActivity<MainActivity>(
                                context,
                                hwPayloadUrl(
                                    "generatorBasics://topic",
                                    listOf(
                                        "topic" to hwPayloadValue(widgetData.topic),
                                        "position" to "1",
                                    ),
                                    "homeWidget",
                                    "",
                                ),
                            )
                    ),
                text = widgetData.topic ?: "",
                style = TextStyle(color = GlanceTheme.colors.onSurface),
            )
            Box(modifier = GlanceModifier.padding(start = 16.0.dp)) {
              Text(
                  modifier =
                      GlanceModifier.clickable(
                          onClick =
                              actionStartActivity<MainActivity>(
                                  context,
                                  Uri.parse("generatorBasics://settings?homeWidget"),
                              )
                      ),
                  text = "Settings",
                  style = TextStyle(color = GlanceTheme.colors.onSurface),
              )
            }
          }
        }
      }
    }
  }
}

data class WidgetLinkData(
    val topic: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.WidgetLink"

    fun fromPreferences(prefs: android.content.SharedPreferences): WidgetLinkData {
      return WidgetLinkData(
          topic = prefs.getString("${PREFERENCES_PREFIX}.topic", "Widgets"),
      )
    }
  }
}

private fun hwCurrentLocales(context: Context): List<String> {
  val configured = ConfigurationCompat.getLocales(context.resources.configuration)
  val tags = mutableListOf<String>()
  for (index in 0 until configured.size()) {
    val locale = configured[index] ?: continue
    val tag = locale.toLanguageTag()
    if (tag.isNotEmpty() && tag != "und") tags.add(tag)
  }
  if (tags.isEmpty()) {
    val fallback = Locale.getDefault().toLanguageTag()
    if (fallback.isNotEmpty() && fallback != "und") tags.add(fallback)
  }
  return tags
}

private fun hwPayloadUrl(
    head: String,
    payload: List<Pair<String, String?>>,
    marker: String,
    fragment: String,
): Uri {
  val url = StringBuilder(head)
  var separator = if (head.contains('?')) '&' else '?'
  for ((name, value) in payload) {
    if (value == null) continue
    url.append(separator).append(name).append('=').append(Uri.encode(value))
    separator = '&'
  }
  if (marker.isNotEmpty()) url.append(separator).append(marker)
  return Uri.parse(url.append(fragment).toString())
}

private fun hwPayloadValue(value: Any?): String? =
    when (value) {
      null -> null
      is Date -> value.time.toString()
      else -> value.toString()
    }
