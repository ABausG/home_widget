// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.icu.text.CompactDecimalFormat
import android.os.Build
import android.text.format.DateFormat as AndroidDateFormat
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
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Currency
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class NumberDateFormattingHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = NumberDateFormattingData.fromPreferences(prefs)
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
          Row {
            Text(
                text = "Order #",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Text(
                text =
                    hwFormatDecimal(
                        (widgetData.orderNumber ?: 0L).toDouble(),
                        null,
                        null,
                        false,
                        hwFormatLocale(context),
                    ),
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Text(text = " · ", style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal))
            Text(
                text =
                    widgetData.placedAt?.let {
                      hwFormatDateSkeleton(it, "yMMMd", hwFormatLocale(context))
                    } ?: "",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
          }
          Text(
              text =
                  hwFormatCurrency(
                      (widgetData.total ?: 0.0),
                      widgetData.currency ?: "",
                      null,
                      hwFormatLocale(context),
                  ),
              style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
          )
          Row {
            Text(
                text =
                    hwFormatPercent(
                        (widgetData.discount ?: 0.0),
                        null,
                        null,
                        hwFormatLocale(context),
                    )
            )
            Text(text = " off · ")
            Text(
                text =
                    hwFormatDecimal(
                        (widgetData.items ?: 0L).toDouble(),
                        null,
                        null,
                        true,
                        hwFormatLocale(context),
                    )
            )
            Text(text = " items")
          }
          Row {
            Text(
                text = "Delivery ",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Text(
                text =
                    widgetData.deliveryAt?.let {
                      hwFormatDateSkeleton(
                          it,
                          "jm",
                          hwFormatLocale(context),
                          widgetData.deliveryZone,
                      )
                    } ?: "",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
          }
          Row {
            Text(
                text =
                    hwFormatCompact((widgetData.points ?: 0L).toDouble(), hwFormatLocale(context)),
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Text(text = " of ", style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal))
            Text(
                text = hwFormatDecimal(25000.0, null, null, true, hwFormatLocale(context)),
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Text(
                text = " points",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
          }
        }
      }
    }
  }
}

data class NumberDateFormattingData(
    val orderNumber: Long? = null,
    val placedAt: java.util.Date? = null,
    val total: Double? = null,
    val currency: String? = null,
    val discount: Double? = null,
    val items: Long? = null,
    val deliveryAt: java.util.Date? = null,
    val deliveryZone: String? = null,
    val points: Long? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.NumberDateFormatting"

    fun fromPreferences(prefs: android.content.SharedPreferences): NumberDateFormattingData {
      return NumberDateFormattingData(
          orderNumber =
              when (val raw = prefs.all["${PREFERENCES_PREFIX}.orderNumber"]) {
                is Int -> raw.toLong()
                is Long -> raw
                else -> 0L
              },
          placedAt = hwParseIsoDate(prefs.getString("${PREFERENCES_PREFIX}.placedAt", null) ?: ""),
          total =
              if (prefs.contains("${PREFERENCES_PREFIX}.total"))
                  java.lang.Double.longBitsToDouble(
                      prefs.getLong("${PREFERENCES_PREFIX}.total", 0L)
                  )
              else 0.0,
          currency = prefs.getString("${PREFERENCES_PREFIX}.currency", "EUR"),
          discount =
              if (prefs.contains("${PREFERENCES_PREFIX}.discount"))
                  java.lang.Double.longBitsToDouble(
                      prefs.getLong("${PREFERENCES_PREFIX}.discount", 0L)
                  )
              else 0.0,
          items =
              when (val raw = prefs.all["${PREFERENCES_PREFIX}.items"]) {
                is Int -> raw.toLong()
                is Long -> raw
                else -> 0L
              },
          deliveryAt =
              hwParseIsoDate(prefs.getString("${PREFERENCES_PREFIX}.deliveryAt", null) ?: ""),
          deliveryZone = prefs.getString("${PREFERENCES_PREFIX}.deliveryZone", ""),
          points =
              when (val raw = prefs.all["${PREFERENCES_PREFIX}.points"]) {
                is Int -> raw.toLong()
                is Long -> raw
                else -> 0L
              },
      )
    }
  }
}

private fun hwFormatLocale(context: Context): Locale =
    ConfigurationCompat.getLocales(context.resources.configuration)[0] ?: Locale.getDefault()

private fun hwFormatCompact(value: Double, locale: Locale): String {
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
    val compact =
        CompactDecimalFormat.getInstance(
            locale,
            CompactDecimalFormat.CompactStyle.SHORT,
        )
    return compact.format(value)
  }
  return NumberFormat.getNumberInstance(locale).format(value)
}

private fun hwFormatCurrency(
    value: Double,
    code: String,
    decimals: Int?,
    locale: Locale,
): String {
  val resolved =
      try {
        Currency.getInstance(code.uppercase(Locale.ROOT))
      } catch (_: IllegalArgumentException) {
        null
      }
  val formatter =
      if (resolved == null) {
        NumberFormat.getNumberInstance(locale)
      } else {
        NumberFormat.getCurrencyInstance(locale).apply {
          currency = resolved
          val defaults = resolved.defaultFractionDigits
          if (decimals == null && defaults >= 0) {
            minimumFractionDigits = defaults
            maximumFractionDigits = defaults
          }
        }
      }
  decimals?.let {
    formatter.minimumFractionDigits = it
    formatter.maximumFractionDigits = it
  }
  return formatter.format(value)
}

private fun hwFormatDecimal(
    value: Double,
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

private fun hwFormatPercent(
    value: Double,
    minFraction: Int?,
    maxFraction: Int?,
    locale: Locale,
): String {
  val formatter = NumberFormat.getPercentInstance(locale)
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

private fun hwResolveTimeZone(id: String?): TimeZone =
    if (!id.isNullOrEmpty() && TimeZone.getAvailableIDs().contains(id)) {
      TimeZone.getTimeZone(id)
    } else {
      TimeZone.getDefault()
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
