// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.ConfigurationCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class SizeAdaptiveDashboardHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode =
      SizeMode.Responsive(
          setOf(
              DpSize(110.dp, 110.dp),
              DpSize(250.dp, 110.dp),
              DpSize(250.dp, 250.dp),
              DpSize(530.dp, 250.dp),
              DpSize(250.dp, 530.dp),
          )
      )

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
    val hwPreviewData = SizeAdaptiveDashboardData.fromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "d4bd29ad",
            hwLocales.joinToString(","),
            hwPreviewData.toString(),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = SizeAdaptiveDashboardData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        when (LocalSize.current) {
          DpSize(250.dp, 110.dp) -> {
            Row(verticalAlignment = Alignment.CenterVertically) {
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text =
                      hwFormatDecimal(
                          (widgetData.score ?: 0L),
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
              Text(
                  modifier =
                      GlanceModifier.padding(
                          start = 8.0.dp,
                          top = 0.0.dp,
                          end = 0.0.dp,
                          bottom = 0.0.dp,
                      ),
                  text = widgetData.scoreLabel ?: "",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 16.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
              Spacer(modifier = GlanceModifier.defaultWeight())
            }
          }
          DpSize(250.dp, 250.dp),
          DpSize(530.dp, 250.dp) -> {
            Column(horizontalAlignment = Alignment.Start) {
              Text(
                  text =
                      hwFormatDecimal(
                          (widgetData.score ?: 0L),
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
              Text(
                  text = widgetData.scoreLabel ?: "",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 16.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
              Text(
                  modifier =
                      GlanceModifier.padding(
                          start = 0.0.dp,
                          top = 8.0.dp,
                          end = 0.0.dp,
                          bottom = 0.0.dp,
                      ),
                  text =
                      hwFormatDecimal(
                          (widgetData.streak ?: 0L),
                          null,
                          null,
                          true,
                          hwFormatLocale(context),
                      ),
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurface,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
            }
          }
          DpSize(250.dp, 530.dp) -> {
            Column(horizontalAlignment = Alignment.Start) {
              Text(
                  text = "Dashboard",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurface,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text =
                      hwFormatDecimal(
                          (widgetData.score ?: 0L),
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
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text = widgetData.scoreLabel ?: "",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 16.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text =
                      hwFormatDecimal(
                          (widgetData.streak ?: 0L),
                          null,
                          null,
                          true,
                          hwFormatLocale(context),
                      ),
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurface,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text = widgetData.motivation ?: "",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
            }
          }
          else -> {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
              Spacer(modifier = GlanceModifier.defaultWeight())
              Text(
                  text =
                      hwFormatDecimal(
                          (widgetData.score ?: 0L),
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
              Spacer(modifier = GlanceModifier.defaultWeight())
            }
          }
        }
      }
    }
  }
}

data class SizeAdaptiveDashboardData(
    val score: Long? = null,
    val scoreLabel: String? = null,
    val streak: Long? = null,
    val motivation: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.SizeAdaptiveDashboard"

    fun fromPreferences(prefs: android.content.SharedPreferences): SizeAdaptiveDashboardData {
      return SizeAdaptiveDashboardData(
          score =
              if (prefs.contains("${PREFERENCES_PREFIX}.score"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.score", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.score", 0L)
                  })
              else 0L,
          scoreLabel = prefs.getString("${PREFERENCES_PREFIX}.scoreLabel", "Points"),
          streak =
              if (prefs.contains("${PREFERENCES_PREFIX}.streak"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.streak", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.streak", 0L)
                  })
              else 0L,
          motivation = prefs.getString("${PREFERENCES_PREFIX}.motivation", "Keep it up!"),
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
