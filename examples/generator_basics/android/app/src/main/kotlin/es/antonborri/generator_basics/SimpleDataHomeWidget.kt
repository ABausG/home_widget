// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
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
import androidx.glance.text.Text
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class SimpleDataHomeWidget : GlanceAppWidget() {
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
    val hwPreviewData = SimpleDataData.previewFromPreferences(HomeWidgetPlugin.getData(context))
    return listOf(
            "4a13e0d1",
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
        if (preview) SimpleDataData.previewFromPreferences(prefs)
        else SimpleDataData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize()
                  .clickable(onClick = actionStartActivity<MainActivity>()),
          contentAlignment = Alignment.Center,
      ) {
        Column {
          Text(text = "Simple Data")
          Row {
            Text(text = "label: ")
            Text(text = widgetData.label ?: "")
          }
          Row {
            Text(text = "value: ")
            Text(
                text =
                    hwFormatDecimal(
                        (widgetData.value ?: 0L),
                        null,
                        null,
                        true,
                        hwFormatLocale(context),
                    )
            )
          }
        }
      }
    }
  }
}

data class SimpleDataData(
    val label: String? = null,
    val value: Long? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.SimpleData"

    fun fromPreferences(prefs: android.content.SharedPreferences): SimpleDataData {
      return SimpleDataData(
          label = prefs.getString("${PREFERENCES_PREFIX}.label", null),
          value =
              if (prefs.contains("${PREFERENCES_PREFIX}.value"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.value", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.value", 0L)
                  })
              else null,
      )
    }

    fun previewFromPreferences(prefs: android.content.SharedPreferences): SimpleDataData {
      return SimpleDataData(
          label = prefs.getString("${PREFERENCES_PREFIX}.label", "Hello"),
          value =
              if (prefs.contains("${PREFERENCES_PREFIX}.value"))
                  (try {
                    prefs.getInt("${PREFERENCES_PREFIX}.value", 0).toLong()
                  } catch (_: ClassCastException) {
                    prefs.getLong("${PREFERENCES_PREFIX}.value", 0L)
                  })
              else 42L,
      )
    }
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
