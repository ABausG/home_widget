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
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetFonts
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetInteractivityAction
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class InteractiveCounterHomeWidget : GlanceAppWidget() {
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
    val hwPreviewData = InteractiveCounterData.fromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "6dbacd1e",
            hwLocales.joinToString(","),
            hwPreviewData.toString(),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = InteractiveCounterData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(
            modifier = GlanceModifier.fillMaxHeight(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Spacer(modifier = GlanceModifier.defaultWeight())
          Text(
              text =
                  hwFormatDecimal(
                      (widgetData.count ?: 0L),
                      null,
                      null,
                      true,
                      hwFormatLocale(context),
                  ),
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
            Image(
                modifier =
                    GlanceModifier.clickable(
                            onClick =
                                actionRunCallback<HomeWidgetInteractivityAction>(
                                    HomeWidgetInteractivityAction.parameters(
                                        Uri.parse("homewidget://interaction/decrement?homeWidget"),
                                        "InteractiveCounterHomeWidget",
                                    )
                                )
                        )
                        .size(32.dp),
                provider =
                    ImageProvider(
                        HomeWidgetFonts.iconBitmap(
                            context,
                            R.font.hw_font_interactive_counter__icons_materialicons,
                            0xE518,
                            32f,
                        )
                    ),
                contentDescription = "Decrement",
                colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
            )
            Box(modifier = GlanceModifier.padding(start = 24.0.dp)) {
              Image(
                  modifier =
                      GlanceModifier.clickable(
                              onClick =
                                  actionRunCallback<HomeWidgetInteractivityAction>(
                                      HomeWidgetInteractivityAction.parameters(
                                          hwPayloadUrl(
                                              "homewidget://interaction/increment",
                                              listOf("step" to "1"),
                                              "homeWidget",
                                              "",
                                          ),
                                          "InteractiveCounterHomeWidget",
                                      )
                                  )
                          )
                          .size(32.dp),
                  provider =
                      ImageProvider(
                          HomeWidgetFonts.iconBitmap(
                              context,
                              R.font.hw_font_interactive_counter__icons_materialicons,
                              0xE050,
                              32f,
                          )
                      ),
                  contentDescription = "Increment",
                  colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
              )
            }
          }
          Spacer(modifier = GlanceModifier.defaultWeight())
        }
      }
    }
  }
}

data class InteractiveCounterData(
    val count: Long? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.InteractiveCounter"

    fun fromPreferences(prefs: android.content.SharedPreferences): InteractiveCounterData {
      return InteractiveCounterData(
          count =
              if (prefs.contains("${PREFERENCES_PREFIX}.count"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.count", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.count", 0L)
                  })
              else 0L,
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

private fun hwFormatLocale(context: Context): Locale =
    ConfigurationCompat.getLocales(context.resources.configuration)[0] ?: Locale.getDefault()

private fun hwFormatDecimal(
    value: Number,
    minFraction: Int?,
    maxFraction: Int?,
    grouping: Boolean,
    locale: Locale,
): String {
  val formatter = NumberFormat.getNumberInstance(locale)
  formatter.isGroupingUsed = grouping
  minFraction?.let { formatter.minimumFractionDigits = it }
  maxFraction?.let { formatter.maximumFractionDigits = it }
  return formatter.format(value)
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
