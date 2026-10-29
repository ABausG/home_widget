// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.text.format.DateFormat as AndroidDateFormat
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
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetFonts
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class WeekForecastHomeWidget : GlanceAppWidget() {
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
    val hwLocales = hwCurrentLocales(context)
    val hwPreviewData = WeekForecastData.previewFromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "ba15c5a5",
            hwLocales.joinToString(","),
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
        if (preview) WeekForecastData.previewFromPreferences(prefs)
        else WeekForecastData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(modifier = GlanceModifier.fillMaxHeight(), horizontalAlignment = Alignment.Start) {
          Text(
              text = widgetData.city ?: "",
              style =
                  TextStyle(
                      color = GlanceTheme.colors.onSurface,
                      fontSize = 18.sp,
                      fontWeight = FontWeight.Medium,
                  ),
          )
          Spacer(modifier = GlanceModifier.defaultWeight())
          Row(
              modifier = GlanceModifier.fillMaxWidth(),
              verticalAlignment = Alignment.CenterVertically,
          ) {
            if (widgetData.days.isNullOrEmpty()) {
              Text(
                  text = "Open the app to load the forecast",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
            } else {
              val hwItems = widgetData.days.orEmpty().take(5)
              hwItems.forEachIndexed { hwIndex, hwItem ->
                if (hwIndex > 0) Spacer(modifier = GlanceModifier.defaultWeight())
                Column(
                    modifier = GlanceModifier.padding(start = if (hwIndex > 0) 4.0.dp else 0.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                  Text(
                      text =
                          hwItem.day?.let { hwFormatDateSkeleton(it, "E", hwFormatLocale(context)) }
                              ?: "",
                      style =
                          TextStyle(
                              color = GlanceTheme.colors.onSurfaceVariant,
                              fontSize = 12.sp,
                              fontWeight = FontWeight.Normal,
                          ),
                  )
                  hwItem.condition?.let { codePoint ->
                    Box(modifier = GlanceModifier.padding(top = 4.0.dp)) {
                      Image(
                          modifier = GlanceModifier.size(24.dp),
                          provider =
                              ImageProvider(
                                  HomeWidgetFonts.iconBitmap(
                                      context,
                                      R.font.hw_font_week_forecast__icons_materialicons,
                                      codePoint,
                                      24f,
                                      matchTextDirection = codePoint in hwMirroredIcons,
                                  )
                              ),
                          contentDescription = null,
                          colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
                      )
                    }
                  }
                  Row(
                      modifier = GlanceModifier.padding(top = 4.0.dp),
                      verticalAlignment = Alignment.CenterVertically,
                  ) {
                    Text(
                        text =
                            hwFormatDecimal(
                                (hwItem.temperature ?: 0L),
                                null,
                                null,
                                true,
                                hwFormatLocale(context),
                            ),
                        style =
                            TextStyle(
                                color = GlanceTheme.colors.onSurface,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Normal,
                            ),
                    )
                    Text(
                        text = widgetData.unit ?: "",
                        style =
                            TextStyle(
                                color = GlanceTheme.colors.onSurface,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Normal,
                            ),
                    )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

data class WeekForecastData(
    val city: String? = null,
    val unit: String? = null,
    val days: List<WeekForecastDaysItem>? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.WeekForecast"

    fun fromPreferences(prefs: android.content.SharedPreferences): WeekForecastData {
      return WeekForecastData(
          city = prefs.getString("${PREFERENCES_PREFIX}.city", "Nowhere"),
          unit = prefs.getString("${PREFERENCES_PREFIX}.unit", "°"),
          days = WeekForecastDaysItem.fromPath(prefs.getString("${PREFERENCES_PREFIX}.days", null)),
      )
    }

    fun previewFromPreferences(prefs: android.content.SharedPreferences): WeekForecastData {
      return WeekForecastData(
          city = prefs.getString("${PREFERENCES_PREFIX}.city", "Berlin"),
          unit = prefs.getString("${PREFERENCES_PREFIX}.unit", "°"),
          days =
              WeekForecastDaysItem.fromPath(prefs.getString("${PREFERENCES_PREFIX}.days", null))
                  ?: listOf(
                      WeekForecastDaysItem(
                          day = hwParseIsoDate("2026-09-21T12:00:00Z"),
                          condition = 59097,
                          temperature = 21L,
                      ),
                      WeekForecastDaysItem(
                          day = hwParseIsoDate("2026-09-22T12:00:00Z"),
                          condition = 57711,
                          temperature = 18L,
                      ),
                      WeekForecastDaysItem(
                          day = hwParseIsoDate("2026-09-23T12:00:00Z"),
                          condition = 59018,
                          temperature = 14L,
                      ),
                      WeekForecastDaysItem(
                          day = hwParseIsoDate("2026-09-24T12:00:00Z"),
                          condition = 985035,
                          temperature = 16L,
                      ),
                      WeekForecastDaysItem(
                          day = hwParseIsoDate("2026-09-25T12:00:00Z"),
                          condition = 59097,
                          temperature = 22L,
                      ),
                  ),
      )
    }
  }
}

data class WeekForecastDaysItem(
    val day: java.util.Date? = null,
    val condition: Int? = null,
    val temperature: Long? = null,
) {
  companion object {
    fun fromPath(path: String?): List<WeekForecastDaysItem>? {
      if (path == null) return null
      return try {
        val file = java.io.File(path)
        if (!file.exists()) return null
        fromJsonArray(org.json.JSONArray(file.readText()))
      } catch (_: Exception) {
        null
      }
    }

    fun fromJsonArray(array: org.json.JSONArray?): List<WeekForecastDaysItem>? {
      if (array == null) return null
      return List(array.length()) { index -> fromJson(array.optJSONObject(index)) }
    }

    fun fromJson(obj: org.json.JSONObject?): WeekForecastDaysItem {
      val json = obj ?: org.json.JSONObject()
      return WeekForecastDaysItem(
          day =
              hwParseIsoDate(
                  if (json.has("day") && !json.isNull("day")) json.optString("day") else ""
              ),
          condition =
              if (json.has("condition") && !json.isNull("condition")) json.optInt("condition")
              else 57711,
          temperature =
              if (json.has("temperature") && !json.isNull("temperature"))
                  json.optLong("temperature")
              else 0L,
      )
    }
  }
}

private val hwMirroredIcons: Set<Int> = setOf()

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

private fun hwParseIsoDate(value: String): Date? {
  fun normalize(raw: String): String {
    var body = raw.trim()
    var zone = "+0000"
    if (body.endsWith("Z", ignoreCase = true)) {
      body = body.substring(0, body.length - 1)
    } else {
      val sign = maxOf(body.lastIndexOf('+'), body.lastIndexOf('-'))
      if (sign > 18) {
        zone = body.substring(sign).replace(":", "")
        body = body.substring(0, sign)
      }
    }
    if (zone.length == 3) zone += "00"
    var fraction = ""
    val dot = body.indexOf('.')
    if (dot >= 0) {
      fraction = body.substring(dot + 1).filter { it.isDigit() }
      body = body.substring(0, dot)
    }
    return body + "." + (fraction + "000").substring(0, 3) + zone
  }

  val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US)
  formatter.timeZone = TimeZone.getTimeZone("UTC")
  formatter.isLenient = false
  return try {
    formatter.parse(normalize(value))
  } catch (_: Exception) {
    null
  }
}

private fun hwResolveTimeZone(id: String?): TimeZone {
  if (id.isNullOrEmpty()) return TimeZone.getDefault()
  val normalized = id.replace(Regex("^(UTC|UT)(?=[+-])"), "GMT")
  val zone = TimeZone.getTimeZone(normalized)
  val unknown = zone.id == "GMT" && !normalized.equals("GMT", ignoreCase = true)
  return if (unknown) TimeZone.getDefault() else zone
}

private fun hwFormatDateSkeleton(
    date: Date,
    skeleton: String,
    locale: Locale,
    timeZoneId: String? = null,
): String {
  val pattern = AndroidDateFormat.getBestDateTimePattern(locale, skeleton)
  val formatter = SimpleDateFormat(pattern, locale)
  formatter.timeZone = hwResolveTimeZone(timeZoneId)
  return formatter.format(date)
}
