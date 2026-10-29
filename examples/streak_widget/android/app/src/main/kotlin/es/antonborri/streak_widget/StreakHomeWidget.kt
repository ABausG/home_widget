// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.streak_widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.ConfigurationCompat
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetFonts
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetPreviews
import java.text.NumberFormat
import java.util.Locale

class StreakHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode: SizeMode = SizeMode.Exact

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val measuring: (HomeWidgetFonts.TextBounds) -> GlanceAppWidget = { bounds ->
      object : GlanceAppWidget() {
        override suspend fun provideGlance(context: Context, id: GlanceId) {
          provideContent {
            WidgetContent(
                context,
                HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)),
                textBounds = bounds,
            )
          }
        }
      }
    }
    val measured = HomeWidgetFonts.measureTextBounds(context, id, measuring)
    provideContent {
      val size = LocalSize.current
      var textBounds by remember { mutableStateOf(measured) }
      LaunchedEffect(size) {
        if (!textBounds.covers(size)) {
          textBounds += HomeWidgetFonts.measureTextBounds(context, id, size, measuring)
        }
      }
      WidgetContent(context, currentState(), textBounds = textBounds)
    }
  }

  override suspend fun providePreview(context: Context, widgetCategory: Int) {
    provideContent {
      WidgetContent(
          context,
          HomeWidgetGlanceState(HomeWidgetPreviews.emptyPreferences),
          preview = true,
          textBounds = HomeWidgetFonts.TextBounds.NONE,
      )
    }
  }

  fun previewFingerprint(context: Context): String {
    val hwLocales = hwCurrentLocales(context)
    return listOf(
            "966c17d1",
            hwLocales.joinToString(","),
        )
        .joinToString("|")
  }

  @Composable
  private fun WidgetContent(
      context: Context,
      currentState: HomeWidgetGlanceState,
      preview: Boolean = false,
      textBounds: HomeWidgetFonts.TextBounds,
  ) {
    val prefs = currentState.preferences
    val widgetData =
        if (preview) StreakData.previewFromPreferences(prefs) else StreakData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {
          Box(modifier = GlanceModifier.fillMaxSize()) {
            widgetData.mascot
                ?.let { path -> hwDecodeImage(context, path, null, null) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Dash reacting to your streak",
                      contentScale = ContentScale.Crop,
                      modifier = GlanceModifier.fillMaxSize(),
                  )
                }
          }
          Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {
            Box(
                modifier =
                    GlanceModifier.padding(
                        start = 10.0.dp,
                        top = 10.0.dp,
                        end = 10.0.dp,
                        bottom = 10.0.dp,
                    )
            ) {
              if (widgetData.frozen == true) {
                Row(
                    modifier =
                        GlanceModifier.background(
                                ColorProvider(day = Color(0x73000000), night = Color(0x73000000))
                            )
                            .cornerRadius(16.0.dp)
                            .padding(start = 6.0.dp, top = 0.0.dp, end = 10.0.dp, bottom = 0.0.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                  Image(
                      modifier = GlanceModifier.size(24.dp),
                      provider =
                          ImageProvider(
                              HomeWidgetFonts.iconBitmap(
                                  context,
                                  R.font.hw_font_streak__icons_materialicons,
                                  0xE037,
                                  24f,
                              )
                          ),
                      contentDescription = "Streak frozen",
                      colorFilter =
                          ColorFilter.tint(
                              ColorProvider(day = Color(0xE01CB0F6), night = Color(0xE01CB0F6))
                          ),
                  )
                  Image(
                      modifier = GlanceModifier.padding(start = 2.0.dp),
                      provider =
                          ImageProvider(
                              if (textBounds.isProbe("cbc999b0", LocalSize.current))
                                  HomeWidgetFonts.probeBitmap()
                              else
                                  HomeWidgetFonts.textBitmap(
                                      context,
                                      HomeWidgetFonts.typeface(context, "Nunito", 900, false),
                                      hwFormatDecimal(
                                          (widgetData.streak ?: 0L),
                                          null,
                                          null,
                                          true,
                                          hwFormatLocale(context),
                                      ),
                                      fontSizeSp = 28f,
                                      maxWidthDp = textBounds.width("cbc999b0", LocalSize.current),
                                      maxHeightDp =
                                          textBounds.height("cbc999b0", LocalSize.current),
                                  )
                          ),
                      contentDescription =
                          if (textBounds.isProbe("cbc999b0", LocalSize.current))
                              "hw_text_bounds:cbc999b0"
                          else
                              hwFormatDecimal(
                                  (widgetData.streak ?: 0L),
                                  null,
                                  null,
                                  true,
                                  hwFormatLocale(context),
                              ),
                      colorFilter =
                          ColorFilter.tint(
                              ColorProvider(day = Color(0xE01CB0F6), night = Color(0xE01CB0F6))
                          ),
                  )
                }
              } else {
                if (widgetData.completed == true) {
                  Row(
                      modifier =
                          GlanceModifier.background(
                                  ColorProvider(day = Color(0x73000000), night = Color(0x73000000))
                              )
                              .cornerRadius(16.0.dp)
                              .padding(
                                  start = 6.0.dp,
                                  top = 0.0.dp,
                                  end = 10.0.dp,
                                  bottom = 0.0.dp,
                              ),
                      verticalAlignment = Alignment.CenterVertically,
                  ) {
                    Image(
                        modifier = GlanceModifier.size(24.dp),
                        provider =
                            ImageProvider(
                                HomeWidgetFonts.iconBitmap(
                                    context,
                                    R.font.hw_font_streak__icons_materialicons,
                                    0xE392,
                                    24f,
                                )
                            ),
                        contentDescription = "Lesson done",
                        colorFilter =
                            ColorFilter.tint(
                                ColorProvider(day = Color(0xE0FF9600), night = Color(0xE0FF9600))
                            ),
                    )
                    Image(
                        modifier = GlanceModifier.padding(start = 2.0.dp),
                        provider =
                            ImageProvider(
                                if (textBounds.isProbe("cbc999b0", LocalSize.current))
                                    HomeWidgetFonts.probeBitmap()
                                else
                                    HomeWidgetFonts.textBitmap(
                                        context,
                                        HomeWidgetFonts.typeface(context, "Nunito", 900, false),
                                        hwFormatDecimal(
                                            (widgetData.streak ?: 0L),
                                            null,
                                            null,
                                            true,
                                            hwFormatLocale(context),
                                        ),
                                        fontSizeSp = 28f,
                                        maxWidthDp =
                                            textBounds.width("cbc999b0", LocalSize.current),
                                        maxHeightDp =
                                            textBounds.height("cbc999b0", LocalSize.current),
                                    )
                            ),
                        contentDescription =
                            if (textBounds.isProbe("cbc999b0", LocalSize.current))
                                "hw_text_bounds:cbc999b0"
                            else
                                hwFormatDecimal(
                                    (widgetData.streak ?: 0L),
                                    null,
                                    null,
                                    true,
                                    hwFormatLocale(context),
                                ),
                        colorFilter =
                            ColorFilter.tint(
                                ColorProvider(day = Color(0xE0FF9600), night = Color(0xE0FF9600))
                            ),
                    )
                  }
                } else {
                  Row(
                      modifier =
                          GlanceModifier.background(
                                  ColorProvider(day = Color(0x73000000), night = Color(0x73000000))
                              )
                              .cornerRadius(16.0.dp)
                              .padding(
                                  start = 6.0.dp,
                                  top = 0.0.dp,
                                  end = 10.0.dp,
                                  bottom = 0.0.dp,
                              ),
                      verticalAlignment = Alignment.CenterVertically,
                  ) {
                    Image(
                        modifier = GlanceModifier.size(24.dp),
                        provider =
                            ImageProvider(
                                HomeWidgetFonts.iconBitmap(
                                    context,
                                    R.font.hw_font_streak__icons_materialicons,
                                    0xE392,
                                    24f,
                                )
                            ),
                        contentDescription = "Lesson not done yet",
                        colorFilter =
                            ColorFilter.tint(
                                ColorProvider(day = Color(0xE0AFAFAF), night = Color(0xE0AFAFAF))
                            ),
                    )
                    Image(
                        modifier = GlanceModifier.padding(start = 2.0.dp),
                        provider =
                            ImageProvider(
                                if (textBounds.isProbe("cbc999b0", LocalSize.current))
                                    HomeWidgetFonts.probeBitmap()
                                else
                                    HomeWidgetFonts.textBitmap(
                                        context,
                                        HomeWidgetFonts.typeface(context, "Nunito", 900, false),
                                        hwFormatDecimal(
                                            (widgetData.streak ?: 0L),
                                            null,
                                            null,
                                            true,
                                            hwFormatLocale(context),
                                        ),
                                        fontSizeSp = 28f,
                                        maxWidthDp =
                                            textBounds.width("cbc999b0", LocalSize.current),
                                        maxHeightDp =
                                            textBounds.height("cbc999b0", LocalSize.current),
                                    )
                            ),
                        contentDescription =
                            if (textBounds.isProbe("cbc999b0", LocalSize.current))
                                "hw_text_bounds:cbc999b0"
                            else
                                hwFormatDecimal(
                                    (widgetData.streak ?: 0L),
                                    null,
                                    null,
                                    true,
                                    hwFormatLocale(context),
                                ),
                        colorFilter =
                            ColorFilter.tint(
                                ColorProvider(day = Color(0xE0AFAFAF), night = Color(0xE0AFAFAF))
                            ),
                    )
                  }
                }
              }
            }
          }
          Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {
            if (widgetData.message != null) {
              Box(
                  modifier = GlanceModifier.fillMaxSize(),
                  contentAlignment = Alignment.BottomCenter,
              ) {
                Box(
                    modifier =
                        GlanceModifier.padding(
                            start = 8.0.dp,
                            top = 8.0.dp,
                            end = 8.0.dp,
                            bottom = 8.0.dp,
                        )
                ) {
                  Text(
                      modifier =
                          GlanceModifier.background(
                                  ColorProvider(day = Color(0x73000000), night = Color(0x73000000))
                              )
                              .cornerRadius(16.0.dp)
                              .padding(start = 8.0.dp, top = 2.0.dp, end = 8.0.dp, bottom = 2.0.dp),
                      text = widgetData.message ?: "",
                      style =
                          TextStyle(
                              color =
                                  ColorProvider(day = Color(0xF2FFFFFF), night = Color(0xF2FFFFFF)),
                              fontSize = 11.sp,
                              fontWeight = FontWeight.Bold,
                              textAlign = TextAlign.Center,
                          ),
                  )
                }
              }
            } else {}
          }
        }
      }
    }
  }
}

data class StreakData(
    val frozen: Boolean? = null,
    val streak: Long? = null,
    val completed: Boolean? = null,
    val mascot: String? = null,
    val message: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.Streak"

    fun fromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): StreakData {
      val timedValues = resolveTimedValues(prefs, now)
      return StreakData(
          frozen =
              if (prefs.contains("${PREFERENCES_PREFIX}.frozen"))
                  prefs.getBoolean("${PREFERENCES_PREFIX}.frozen", false)
              else false,
          streak =
              if (prefs.contains("${PREFERENCES_PREFIX}.streak"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.streak", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.streak", 0L)
                  })
              else 0L,
          completed =
              if (prefs.contains("${PREFERENCES_PREFIX}.completed"))
                  prefs.getBoolean("${PREFERENCES_PREFIX}.completed", false)
              else false,
          mascot =
              if (timedValues.has("mascot") && !timedValues.isNull("mascot"))
                  timedValues.optString("mascot")
              else null,
          message =
              if (timedValues.has("message") && !timedValues.isNull("message"))
                  timedValues.optString("message")
              else null,
      )
    }

    fun previewFromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): StreakData {
      val timedValues = resolveTimedValues(prefs, now)
      return StreakData(
          frozen =
              if (prefs.contains("${PREFERENCES_PREFIX}.frozen"))
                  prefs.getBoolean("${PREFERENCES_PREFIX}.frozen", false)
              else false,
          streak =
              if (prefs.contains("${PREFERENCES_PREFIX}.streak"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.streak", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.streak", 0L)
                  })
              else 12L,
          completed =
              if (prefs.contains("${PREFERENCES_PREFIX}.completed"))
                  prefs.getBoolean("${PREFERENCES_PREFIX}.completed", false)
              else true,
          mascot =
              if (timedValues.has("mascot") && !timedValues.isNull("mascot"))
                  timedValues.optString("mascot")
              else "assets/dash/success_grass.png",
          message =
              if (timedValues.has("message") && !timedValues.isNull("message"))
                  timedValues.optString("message")
              else "Streak secured",
      )
    }

    private fun resolveTimedValues(
        prefs: android.content.SharedPreferences,
        now: Long,
    ): org.json.JSONObject {
      val path =
          prefs.getString("${PREFERENCES_PREFIX}.timedData", null) ?: return org.json.JSONObject()
      return try {
        val file = java.io.File(path)
        if (!file.exists()) return org.json.JSONObject()
        val json = org.json.JSONObject(file.readText())
        var activeKey: String? = null
        var activeTimestamp = 0L
        val keys = json.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          val timestamp = key.toLongOrNull() ?: continue
          if (timestamp <= now && (activeKey == null || timestamp > activeTimestamp)) {
            activeKey = key
            activeTimestamp = timestamp
          }
        }
        val resolvedKey = activeKey ?: return org.json.JSONObject()
        json.optJSONObject(resolvedKey) ?: org.json.JSONObject()
      } catch (_: Exception) {
        org.json.JSONObject()
      }
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

private fun hwDecodeImage(
    context: Context,
    path: String,
    widthDp: Double?,
    heightDp: Double?,
): Bitmap? {
  fun decode(options: BitmapFactory.Options): Bitmap? =
      if (path.startsWith("/")) {
        BitmapFactory.decodeFile(path, options)
      } else {
        context.assets.open("flutter_assets/$path").use {
          BitmapFactory.decodeStream(it, null, options)
        }
      }

  fun sampleSize(bounds: BitmapFactory.Options): Int {
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return 1
    val metrics = context.resources.displayMetrics
    val fallback = minOf(metrics.widthPixels, metrics.heightPixels)
    val widthPx = widthDp?.let { (it * metrics.density).toInt() }
    val heightPx = heightDp?.let { (it * metrics.density).toInt() }
    val targetWidth =
        widthPx
            ?: heightPx?.let {
              (it.toLong() * bounds.outWidth / bounds.outHeight).toInt().coerceAtLeast(1)
            }
            ?: fallback
    val targetHeight =
        heightPx
            ?: widthPx?.let {
              (it.toLong() * bounds.outHeight / bounds.outWidth).toInt().coerceAtLeast(1)
            }
            ?: fallback
    if (targetWidth <= 0 || targetHeight <= 0) return 1
    var sampleSize = 1
    while (
        bounds.outWidth / (sampleSize * 2) >= targetWidth &&
            bounds.outHeight / (sampleSize * 2) >= targetHeight
    ) {
      sampleSize *= 2
    }
    return sampleSize
  }

  return try {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    decode(bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
      null
    } else {
      decode(
          BitmapFactory.Options().apply { inSampleSize = sampleSize(bounds) },
      )
    }
  } catch (_: Exception) {
    null
  }
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
