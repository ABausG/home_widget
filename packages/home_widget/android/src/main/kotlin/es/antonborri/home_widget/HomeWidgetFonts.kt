package es.antonborri.home_widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.View
import androidx.annotation.FontRes
import androidx.core.content.res.ResourcesCompat
import androidx.glance.text.TextAlign
import kotlin.math.ceil
import kotlin.math.roundToInt
import org.json.JSONArray

/**
 * Draws text and icons of a custom font for use in a Glance widget.
 *
 * Glance cannot draw text in a custom font, so the glyphs are drawn into a white mask bitmap here
 * and shown through an `ImageProvider`, which keeps the colour themable through a `ColorFilter`:
 * ```kotlin
 * Image(
 *     provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, R.font.my_icons, 0xe87d, 24f)),
 *     contentDescription = null,
 *     colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),
 *     modifier = GlanceModifier.size(24.dp),
 * )
 * ```
 */
object HomeWidgetFonts {
  private const val TAG = "HomeWidgetFonts"

  /**
   * The largest bitmap either renderer draws, in pixels per side — a guard against a runaway
   * request.
   */
  private const val MAX_SIZE_PX = 2048

  private const val FONT_MANIFEST = "flutter_assets/FontManifest.json"

  private const val DEFAULT_FONT_WEIGHT = 400

  private val typefaceCache = HashMap<String, Typeface?>()

  private val manifestLock = Any()

  private var manifestCache: Map<String, List<FontDeclaration>>? = null

  /** One font file of a family, as the Flutter asset manifest declares it. */
  private class FontDeclaration(val asset: String, val weight: Int, val italic: Boolean)

  /**
   * Renders the glyph [codePoint] of the font resource [fontRes] as a white bitmap of [sizeDp] ×
   * [sizeDp] density independent pixels.
   *
   * The glyph is drawn in white so it can be recoloured with a Glance `ColorFilter.tint`, and is
   * centred both horizontally and vertically in the square. A glyph whose ink reaches past one em —
   * plenty of icon fonts ship those — is scaled down to fit the square rather than cropped.
   *
   * [matchTextDirection] mirrors the glyph horizontally when the configuration lays out right to
   * left, the way Flutter's `Icon` honours `IconData.matchTextDirection`. Pass it for a directional
   * glyph such as `Icons.arrow_back`; it does nothing in a left to right layout.
   *
   * Never throws: when the font cannot be loaded or the glyph cannot be drawn, a fully transparent
   * bitmap of the requested size is returned.
   */
  fun iconBitmap(
      context: Context,
      @FontRes fontRes: Int,
      codePoint: Int,
      sizeDp: Float,
      matchTextDirection: Boolean = false,
  ): Bitmap {
    val displayMetrics = context.resources.displayMetrics
    val sizePx = (sizeDp * displayMetrics.density).roundToInt().coerceIn(1, MAX_SIZE_PX)
    val bitmap = Bitmap.createBitmap(displayMetrics, sizePx, sizePx, Bitmap.Config.ARGB_8888)
    try {
      val typeface = ResourcesCompat.getFont(context, fontRes)
      if (typeface == null) {
        Log.w(TAG, "Could not load the font resource $fontRes")
        return bitmap
      }
      val paint =
          Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            this.typeface = typeface
            textSize = sizePx.toFloat()
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
          }
      val glyph = String(Character.toChars(codePoint))
      val ink = Rect()
      paint.getTextBounds(glyph, 0, glyph.length, ink)
      val inkSize = maxOf(ink.width(), ink.height())
      if (inkSize > sizePx) {
        paint.textSize = paint.textSize * sizePx / inkSize
      }
      val metrics = paint.fontMetrics
      val baseline = sizePx / 2f - (metrics.ascent + metrics.descent) / 2f
      val canvas = Canvas(bitmap)
      val rightToLeft = context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL
      if (matchTextDirection && rightToLeft) {
        canvas.scale(-1f, 1f, sizePx / 2f, sizePx / 2f)
      }
      canvas.drawText(glyph, sizePx / 2f, baseline, paint)
    } catch (e: Exception) {
      Log.w(TAG, "Failed to render the code point $codePoint of the font resource $fontRes", e)
    }
    return bitmap
  }

  /**
   * The [Typeface] Flutter renders [family] at [weight] and [italic] in.
   *
   * [family] is the family key Flutter registers the font under: the family name as the
   * `pubspec.yaml` declares it, or `packages/<package>/<family>` for a family shipped by a package.
   * Which file that is comes out of the `FontManifest.json` next to the fonts in `flutter_assets`,
   * picked the way Flutter picks it: a file of the requested slant beats one of the wrong slant, an
   * exact [weight] beats every other, and otherwise the nearest weight wins — looking down from a
   * light target and up from a heavy one.
   *
   * The manifest is read once and kept, as are the typefaces themselves. Returns `null` when no
   * declared family matches [family], which [textBitmap] renders in the system font.
   */
  fun typeface(
      context: Context,
      family: String,
      weight: Int = DEFAULT_FONT_WEIGHT,
      italic: Boolean = false,
  ): Typeface? {
    val declarations = fontManifest(context)[family] ?: return null
    val declaration = pickDeclaration(declarations, weight, italic) ?: return null
    return assetTypeface(context, declaration.asset)
  }

  /**
   * Loads the font of the Flutter asset [asset] as a [Typeface].
   *
   * [asset] is an asset key as it appears in the `pubspec.yaml`, for example
   * `assets/fonts/Chewy-Regular.ttf`, or `packages/my_package/fonts/Chewy-Regular.ttf` for a font
   * shipped by a package. The font is read in place from the `flutter_assets` directory, so it does
   * not have to be copied into the Android project.
   *
   * Typefaces are cached by [asset], including the failure to load one. Returns `null` when [asset]
   * is `null` or when the asset does not exist or cannot be parsed as a font.
   */
  fun assetTypeface(context: Context, asset: String?): Typeface? {
    if (asset == null) {
      return null
    }
    synchronized(typefaceCache) {
      if (typefaceCache.containsKey(asset)) {
        return typefaceCache[asset]
      }
    }
    val typeface =
        try {
          Typeface.createFromAsset(context.assets, "flutter_assets/$asset")
        } catch (e: Exception) {
          Log.w(TAG, "Could not load the font asset $asset", e)
          null
        }
    synchronized(typefaceCache) { typefaceCache[asset] = typeface }
    return typeface
  }

  /**
   * Renders [text] in [typeface] as a white bitmap on a transparent background.
   *
   * The text is drawn in white so it can be recoloured with a Glance `ColorFilter.tint`. It wraps
   * at [maxWidthDp] density independent pixels and stops at [maxHeightDp], the last line that fits
   * ellipsized, as is the line at [maxLines].
   *
   * The bitmap is only as wide as the widest line, so [textAlign] aligns the lines relative to each
   * other. Pass [fillWidth] to make it [maxWidthDp] wide instead, which is what gives a centred or
   * end aligned line somewhere to sit.
   *
   * [typeface] falls back to [Typeface.DEFAULT] when it is `null`.
   *
   * Never throws: when the text cannot be drawn, a 1 × 1 transparent bitmap is returned.
   */
  fun textBitmap(
      context: Context,
      typeface: Typeface?,
      text: CharSequence,
      fontSizeSp: Float = 14f,
      underline: Boolean = false,
      lineThrough: Boolean = false,
      textAlign: TextAlign? = null,
      maxLines: Int = Int.MAX_VALUE,
      maxWidthDp: Float,
      maxHeightDp: Float = Float.MAX_VALUE,
      fillWidth: Boolean = false,
  ): Bitmap {
    try {
      val displayMetrics = context.resources.displayMetrics
      val resolvedTypeface = typeface ?: Typeface.DEFAULT
      val paint =
          TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            this.typeface = resolvedTypeface
            textSize =
                TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_SP,
                    fontSizeSp,
                    displayMetrics,
                )
            color = Color.WHITE
            isUnderlineText = underline
            isStrikeThruText = lineThrough
          }

      val wrapWidth = (maxWidthDp * displayMetrics.density).toInt().coerceIn(1, MAX_SIZE_PX)
      val maxHeightPx = (maxHeightDp * displayMetrics.density).toInt().coerceIn(1, MAX_SIZE_PX)

      var layout = textLayout(text, paint, wrapWidth, textAlign, maxLines)
      var lines = maxLines
      val fitting = linesWithin(layout, maxHeightPx)
      if (fitting < layout.lineCount) {
        lines = fitting
        layout = textLayout(text, paint, wrapWidth, textAlign, lines)
      }

      var width = wrapWidth
      if (!fillWidth) {
        var widest = 0f
        var leftToRight = true
        for (line in 0 until layout.lineCount) {
          widest = maxOf(widest, layout.getLineWidth(line))
          leftToRight =
              leftToRight && layout.getParagraphDirection(line) == Layout.DIR_LEFT_TO_RIGHT
        }
        val tight = ceil(widest).toInt().coerceIn(1, width)
        if (tight < width) {
          // A left-to-right ALIGN_NORMAL line starts at x = 0 regardless of the width it was
          // measured against; every other alignment shifts when the width narrows.
          if (!leftToRight || alignmentOf(textAlign) != Layout.Alignment.ALIGN_NORMAL) {
            layout = textLayout(text, paint, tight, textAlign, lines)
          }
          width = tight
        }
      }

      val height = layout.height.coerceIn(1, maxHeightPx)
      val bitmap = Bitmap.createBitmap(displayMetrics, width, height, Bitmap.Config.ARGB_8888)
      layout.draw(Canvas(bitmap))
      return bitmap
    } catch (e: Exception) {
      Log.w(TAG, "Failed to render the text \"$text\"", e)
      return Bitmap.createBitmap(
          context.resources.displayMetrics,
          1,
          1,
          Bitmap.Config.ARGB_8888,
      )
    }
  }

  /** The declared families, read from the asset manifest on first use and kept afterwards. */
  private fun fontManifest(context: Context): Map<String, List<FontDeclaration>> {
    synchronized(manifestLock) {
      manifestCache?.let {
        return it
      }
      val families = readFontManifest(context)
      manifestCache = families
      return families
    }
  }

  /** Never throws: an unreadable or malformed manifest declares no family at all. */
  private fun readFontManifest(context: Context): Map<String, List<FontDeclaration>> {
    val families = HashMap<String, List<FontDeclaration>>()
    try {
      val json = context.assets.open(FONT_MANIFEST).use { it.readBytes().toString(Charsets.UTF_8) }
      val entries = JSONArray(json)
      for (entry in 0 until entries.length()) {
        val declaration = entries.optJSONObject(entry) ?: continue
        val family = declaration.optString("family")
        val files = declaration.optJSONArray("fonts")
        if (family.isEmpty() || files == null) continue

        val declarations = ArrayList<FontDeclaration>(files.length())
        for (file in 0 until files.length()) {
          val font = files.optJSONObject(file) ?: continue
          val asset = font.optString("asset")
          if (asset.isEmpty()) continue
          declarations.add(
              FontDeclaration(
                  asset = asset,
                  weight = font.optInt("weight", DEFAULT_FONT_WEIGHT),
                  italic = font.optString("style") == "italic",
              )
          )
        }
        if (declarations.isNotEmpty()) families[family] = declarations
      }
    } catch (e: Exception) {
      Log.w(TAG, "Could not read $FONT_MANIFEST", e)
    }
    return families
  }

  /** The one file of [declarations] that renders [weight] and [italic] best. */
  private fun pickDeclaration(
      declarations: List<FontDeclaration>,
      weight: Int,
      italic: Boolean,
  ): FontDeclaration? {
    val matchingStyle = declarations.filter { it.italic == italic }
    val pool = matchingStyle.ifEmpty { declarations }
    pool
        .firstOrNull { it.weight == weight }
        ?.let {
          return it
        }

    val lighter = pool.filter { it.weight < weight }.sortedByDescending { it.weight }
    val heavier = pool.filter { it.weight > weight }.sortedBy { it.weight }
    val ordered = if (weight <= DEFAULT_FONT_WEIGHT) lighter + heavier else heavier + lighter
    return ordered.firstOrNull()
  }

  /** How many of [layout]'s lines fit into [maxHeightPx], never fewer than one. */
  private fun linesWithin(layout: StaticLayout, maxHeightPx: Int): Int {
    if (layout.height <= maxHeightPx) return layout.lineCount
    var lines = 0
    while (lines < layout.lineCount && layout.getLineBottom(lines) <= maxHeightPx) {
      lines++
    }
    return lines.coerceAtLeast(1)
  }

  private fun textLayout(
      text: CharSequence,
      paint: TextPaint,
      width: Int,
      textAlign: TextAlign?,
      maxLines: Int,
  ): StaticLayout {
    val builder =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(alignmentOf(textAlign))
            .setIncludePad(false)
            .setMaxLines(maxLines)
    if (maxLines != Int.MAX_VALUE) {
      builder.setEllipsize(TextUtils.TruncateAt.END)
    }
    return builder.build()
  }

  private fun alignmentOf(textAlign: TextAlign?): Layout.Alignment =
      when (textAlign) {
        TextAlign.Center -> Layout.Alignment.ALIGN_CENTER
        TextAlign.End,
        TextAlign.Right -> Layout.Alignment.ALIGN_OPPOSITE
        else -> Layout.Alignment.ALIGN_NORMAL
      }
}
