// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
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
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
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
import java.util.Locale

class FontAndIconsHomeWidget : GlanceAppWidget() {
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
          HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)),
          preview = true,
          textBounds = HomeWidgetFonts.TextBounds.NONE,
      )
    }
  }

  fun previewFingerprint(context: Context): String {
    val hwLocales = hwCurrentLocales(context)
    val hwPreviewData = FontAndIconsData.previewFromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "2a6778db",
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
      textBounds: HomeWidgetFonts.TextBounds,
  ) {
    val prefs = currentState.preferences
    val widgetData =
        if (preview) FontAndIconsData.previewFromPreferences(prefs)
        else FontAndIconsData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
          Spacer(modifier = GlanceModifier.defaultWeight())
          Image(
              modifier = GlanceModifier,
              provider =
                  ImageProvider(
                      if (textBounds.isProbe("b0f04704", LocalSize.current))
                          HomeWidgetFonts.probeBitmap()
                      else
                          HomeWidgetFonts.textBitmap(
                              context,
                              HomeWidgetFonts.typeface(context, "Chewy", 400, false),
                              "Chewy",
                              fontSizeSp = 24f,
                              maxWidthDp = textBounds.width("b0f04704", LocalSize.current),
                              maxHeightDp = textBounds.height("b0f04704", LocalSize.current),
                          )
                  ),
              contentDescription =
                  if (textBounds.isProbe("b0f04704", LocalSize.current)) "hw_text_bounds:b0f04704"
                  else "Chewy",
              colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
          )
          Image(
              modifier = GlanceModifier,
              provider =
                  ImageProvider(
                      if (textBounds.isProbe("41d76946", LocalSize.current))
                          HomeWidgetFonts.probeBitmap()
                      else
                          HomeWidgetFonts.textBitmap(
                              context,
                              HomeWidgetFonts.typeface(context, "Chewy", 400, false),
                              "The same family again, wrapping to the room the label leaves it.",
                              fontSizeSp = 14f,
                              textAlign = TextAlign.Center,
                              maxWidthDp = textBounds.width("41d76946", LocalSize.current),
                              maxHeightDp = textBounds.height("41d76946", LocalSize.current),
                              fillWidth = true,
                          )
                  ),
              contentDescription =
                  if (textBounds.isProbe("41d76946", LocalSize.current)) "hw_text_bounds:41d76946"
                  else "The same family again, wrapping to the room the label leaves it.",
              colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
          )
          Row(verticalAlignment = Alignment.CenterVertically) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            Image(
                modifier = GlanceModifier.size(24.dp),
                provider =
                    ImageProvider(
                        HomeWidgetFonts.iconBitmap(
                            context,
                            R.font.hw_font_font_and_icons__icons_materialicons,
                            0xE25B,
                            24f,
                        )
                    ),
                contentDescription = null,
                colorFilter =
                    ColorFilter.tint(
                        ColorProvider(day = Color(0xFFE53935), night = Color(0xFFE53935))
                    ),
            )
            Image(
                modifier = GlanceModifier.size(24.dp),
                provider =
                    ImageProvider(
                        HomeWidgetFonts.iconBitmap(
                            context,
                            R.font.hw_font_font_and_icons__icons_cupertinoicons__cupertino_icons,
                            0xF4B6,
                            24f,
                        )
                    ),
                contentDescription = null,
                colorFilter =
                    ColorFilter.tint(
                        ColorProvider(day = Color(0xFFFB8C00), night = Color(0xFFFB8C00))
                    ),
            )
            Image(
                modifier = GlanceModifier.size(24.dp),
                provider =
                    ImageProvider(
                        HomeWidgetFonts.iconBitmap(
                            context,
                            R.font
                                .hw_font_font_and_icons__icons_fontawesomesolid__font_awesome_flutter,
                            0xF004,
                            24f,
                        )
                    ),
                contentDescription = null,
                colorFilter =
                    ColorFilter.tint(
                        ColorProvider(day = Color(0xFF8E24AA), night = Color(0xFF8E24AA))
                    ),
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
          }
          Text(
              text = "three icons, three fonts",
              style =
                  TextStyle(
                      color = GlanceTheme.colors.onSurface,
                      fontSize = 12.sp,
                      fontWeight = FontWeight.Normal,
                  ),
          )
          widgetData.mood?.let { codePoint ->
            Image(
                modifier = GlanceModifier.size(40.dp),
                provider =
                    ImageProvider(
                        HomeWidgetFonts.iconBitmap(
                            context,
                            R.font.hw_font_font_and_icons__icons_materialicons,
                            codePoint,
                            40f,
                            matchTextDirection = codePoint in hwMirroredIcons,
                        )
                    ),
                contentDescription = "Mood",
                colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
            )
          }
          Spacer(modifier = GlanceModifier.defaultWeight())
        }
      }
    }
  }
}

data class FontAndIconsData(
    val mood: Int? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.FontAndIcons"

    fun fromPreferences(prefs: android.content.SharedPreferences): FontAndIconsData {
      return FontAndIconsData(
          mood =
              if (prefs.contains("${PREFERENCES_PREFIX}.mood"))
                  prefs.getInt("${PREFERENCES_PREFIX}.mood", 0)
              else 59097,
      )
    }

    fun previewFromPreferences(prefs: android.content.SharedPreferences): FontAndIconsData {
      return FontAndIconsData(
          mood =
              if (prefs.contains("${PREFERENCES_PREFIX}.mood"))
                  prefs.getInt("${PREFERENCES_PREFIX}.mood", 0)
              else 58873,
      )
    }
  }
}

private val hwMirroredIcons: Set<Int> = setOf(0xE09B)

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
