// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This is a placeholder Glance (Jetpack Compose) widget.
package es.antonborri.generator_basics

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.io.File
import org.json.JSONObject

class ImageShowcaseHomeWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
    val prefs = currentState.preferences
    val widgetData = ImageShowcaseData.fromPreferences(prefs)
    GlanceTheme {
      Box(
          modifier =
              GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                  .padding(16.dp)
                  .fillMaxSize(),
          contentAlignment = Alignment.Center,
      ) {
        Column(
            modifier =
                GlanceModifier.fillMaxSize()
                    .padding(start = 8.0.dp, top = 8.0.dp, end = 8.0.dp, bottom = 8.0.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Spacer(modifier = GlanceModifier.defaultWeight())
          flutterAssetBitmap(context, "assets/logo.png", 24.0, 24.0)?.let { bitmap ->
            Image(
                provider = ImageProvider(bitmap),
                contentDescription = "App logo",
                contentScale = ContentScale.Fit,
                modifier = GlanceModifier.width(24.0.dp).height(24.0.dp),
            )
          }
          if (widgetData.picture?.let { java.io.File(it).exists() } == true) {
            widgetData.picture
                ?.let { path -> hwDecodeImageFile(context, path, 64.0, 64.0) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Picture saved by the app",
                      contentScale = ContentScale.Crop,
                      modifier = GlanceModifier.width(64.0.dp).height(64.0.dp),
                  )
                }
          } else {
            Text(
                text = "Open the app to pick an image",
                style =
                    TextStyle(
                        color = GlanceTheme.colors.onSurfaceVariant,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Normal,
                    ),
            )
          }
          Row(verticalAlignment = Alignment.CenterVertically) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            widgetData.slide
                ?.let { path -> hwDecodeImageFile(context, path, 28.0, 28.0) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Picture for the current time slot",
                      contentScale = ContentScale.Fit,
                      modifier = GlanceModifier.width(28.0.dp).height(28.0.dp),
                  )
                }
            widgetData.contact
                ?.avatar
                ?.let { path -> hwDecodeImageFile(context, path, 28.0, 28.0) }
                ?.let { bitmap ->
                  Image(
                      provider = ImageProvider(bitmap),
                      contentDescription = "Contact avatar",
                      contentScale = ContentScale.Crop,
                      modifier = GlanceModifier.width(28.0.dp).height(28.0.dp),
                  )
                }
            Text(
                text = (widgetData.contact?.name ?: "") ?: "",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
          }
          Spacer(modifier = GlanceModifier.defaultWeight())
        }
      }
    }
  }
}

data class ImageShowcaseData(
    val picture: String? = null,
    val contact: ImageShowcaseContactJsonData? = null,
    val slide: String? = null,
) {
  companion object {
    private const val PREFERENCES_PREFIX = "home_widget.ImageShowcase"

    fun fromPreferences(
        prefs: android.content.SharedPreferences,
        now: Long = System.currentTimeMillis(),
    ): ImageShowcaseData {
      val timedValues = resolveTimedValues(prefs, now)
      return ImageShowcaseData(
          picture = prefs.getString("${PREFERENCES_PREFIX}.picture", null),
          contact =
              ImageShowcaseContactJsonData.fromPath(
                  prefs.getString("${PREFERENCES_PREFIX}.contact", null)
              ),
          slide =
              if (timedValues.has("slide") && !timedValues.isNull("slide"))
                  timedValues.optString("slide")
              else null,
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

data class ImageShowcaseContactJsonData(
    val avatar: String? = null,
    val name: String = "",
) {
  companion object {
    fun fromPath(path: String?): ImageShowcaseContactJsonData? {
      if (path == null) return null
      return try {
        val file = java.io.File(path)
        if (!file.exists()) return null
        fromJson(org.json.JSONObject(file.readText()))
      } catch (_: Exception) {
        null
      }
    }

    fun fromJson(obj: org.json.JSONObject?): ImageShowcaseContactJsonData? {
      if (obj == null) return null
      val json = obj
      return ImageShowcaseContactJsonData(
          avatar =
              if (json.has("avatar") && !json.isNull("avatar")) json.optString("avatar") else null,
          name = if (json.has("name") && !json.isNull("name")) json.optString("name") else "",
      )
    }
  }
}

private fun hwImageSampleSize(
    context: android.content.Context,
    bounds: BitmapFactory.Options,
    widthDp: Double?,
    heightDp: Double?,
): Int {
  val metrics = context.resources.displayMetrics
  val fallback = minOf(metrics.widthPixels, metrics.heightPixels)
  val targetWidth = widthDp?.let { (it * metrics.density).toInt() } ?: fallback
  val targetHeight = heightDp?.let { (it * metrics.density).toInt() } ?: fallback
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

private fun hwDecodeImageFile(
    context: android.content.Context,
    path: String,
    widthDp: Double?,
    heightDp: Double?,
): android.graphics.Bitmap? =
    try {
      val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
      BitmapFactory.decodeFile(path, bounds)
      if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        null
      } else {
        BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
              inSampleSize = hwImageSampleSize(context, bounds, widthDp, heightDp)
            },
        )
      }
    } catch (_: Exception) {
      null
    }

private fun flutterAssetBitmap(
    context: android.content.Context,
    asset: String,
    widthDp: Double?,
    heightDp: Double?,
): android.graphics.Bitmap? =
    try {
      val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
      context.assets.open("flutter_assets/$asset").use {
        BitmapFactory.decodeStream(it, null, bounds)
      }
      if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        null
      } else {
        val options =
            BitmapFactory.Options().apply {
              inSampleSize = hwImageSampleSize(context, bounds, widthDp, heightDp)
            }
        context.assets.open("flutter_assets/$asset").use {
          BitmapFactory.decodeStream(it, null, options)
        }
      }
    } catch (_: Exception) {
      null
    }
