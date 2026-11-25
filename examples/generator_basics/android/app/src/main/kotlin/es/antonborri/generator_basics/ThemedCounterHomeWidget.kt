// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
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
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetAppearance
import es.antonborri.home_widget.HomeWidgetFonts
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class ThemedCounterHomeWidget : GlanceAppWidget() {
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
    val hwPreviewData = ThemedCounterData.fromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "e1d942a0",
            hwLocales.joinToString(","),
            hwIsNight(context).toString(),
            hwPreviewData.toString(),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = ThemedCounterData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(
                      ColorProvider(day = Color(0xFFEFF6FF), night = Color(0xFF0B1220))
                  )
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Spacer(modifier = GlanceModifier.defaultWeight())
          Row(
              modifier = GlanceModifier.fillMaxWidth(),
              verticalAlignment = Alignment.CenterVertically,
          ) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            HomeWidgetAppearance.pick(context, { 0xE37A }, { 0xE1B0 })?.let { codePoints ->
              HwAppearanceImage(
                  modifier = GlanceModifier.size(14.dp),
                  size = GlanceModifier.size(14.dp),
                  context = context,
                  images =
                      codePoints.map { codePoint ->
                        HomeWidgetFonts.iconBitmap(
                            context,
                            R.font.hw_font_themed_counter__icons_materialicons,
                            codePoint,
                            14f,
                        )
                      },
                  contentDescription = null,
                  contentScale = ContentScale.Fit,
                  tint = GlanceTheme.colors.onSurfaceVariant,
              )
            }
            if (hwIsNight(context)) {
              Text(
                  modifier = GlanceModifier.padding(start = 4.0.dp),
                  text = "Dark mode",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
            } else {
              Text(
                  modifier = GlanceModifier.padding(start = 4.0.dp),
                  text = "Light mode",
                  style =
                      TextStyle(
                          color = GlanceTheme.colors.onSurfaceVariant,
                          fontSize = 12.sp,
                          fontWeight = FontWeight.Normal,
                      ),
              )
            }
            Spacer(modifier = GlanceModifier.defaultWeight())
          }
          Text(
              modifier = GlanceModifier.padding(top = 4.0.dp),
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
                      color =
                          (hwAppearanceColor(
                              context,
                              hwColor(widgetData.accentLight),
                              hwColor(widgetData.accentDark),
                          ) ?: GlanceTheme.colors.onSurface),
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

data class ThemedCounterData(
    val count: Long? = null,
    val accentLight: Long? = null,
    val accentDark: Long? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.ThemedCounter"

    fun fromPreferences(prefs: android.content.SharedPreferences): ThemedCounterData {
      return ThemedCounterData(
          count =
              if (prefs.contains("${PREFERENCES_PREFIX}.count"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.count", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.count", 0L)
                  })
              else 0L,
          accentLight = (hwReadColor(prefs, "${PREFERENCES_PREFIX}.accentLight") ?: 4280110808L),
          accentDark = (hwReadColor(prefs, "${PREFERENCES_PREFIX}.accentDark") ?: 4287874557L),
      )
    }
  }
}

private fun hwAppearanceColor(
    context: Context,
    light: androidx.glance.unit.ColorProvider?,
    dark: androidx.glance.unit.ColorProvider?,
): androidx.glance.unit.ColorProvider? {
  val day = light ?: dark ?: return null
  return ColorProvider(
      day = day.getColor(HomeWidgetAppearance.configurationContext(context, night = false)),
      night =
          (dark ?: day).getColor(HomeWidgetAppearance.configurationContext(context, night = true)),
  )
}

@Composable
private fun HwAppearanceImage(
    modifier: GlanceModifier,
    size: GlanceModifier,
    context: Context,
    images: HomeWidgetAppearance.DayNight<Bitmap>,
    contentDescription: String?,
    contentScale: ContentScale,
    tint: androidx.glance.unit.ColorProvider? = null,
) {
  if (images.day === images.night || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
    Image(
        provider = ImageProvider(images.day),
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
        colorFilter = tint?.let { ColorFilter.tint(it) },
    )
    return
  }
  Box(modifier = modifier) {
    AndroidRemoteViews(
        remoteViews =
            HomeWidgetAppearance.image(
                context,
                images.day,
                images.night,
                contentDescription,
                contentScale,
                tint?.let {
                  HomeWidgetAppearance.DayNight(
                      day =
                          it.getColor(
                                  HomeWidgetAppearance.configurationContext(context, night = false)
                              )
                              .toArgb(),
                      night =
                          it.getColor(
                                  HomeWidgetAppearance.configurationContext(context, night = true)
                              )
                              .toArgb(),
                  )
                },
            ),
        modifier = size,
    )
  }
}

private fun hwColor(argb: Long?) = argb?.let {
  ColorProvider(day = Color(it.toInt()), night = Color(it.toInt()))
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

private fun hwIsNight(context: Context): Boolean =
    (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
        Configuration.UI_MODE_NIGHT_YES

private fun hwReadColor(prefs: SharedPreferences, key: String): Long? = runCatching {
  prefs.getLong(key, 0L).takeIf { it == prefs.getLong(key, 1L) }
}
    .recoverCatching { prefs.getInt(key, 0).takeIf { it == prefs.getInt(key, 1) }?.toLong() }
    .getOrNull()
