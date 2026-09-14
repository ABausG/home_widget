package es.antonborri.home_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.RemoteViews
import androidx.annotation.FontRes
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.core.content.res.ResourcesCompat
import androidx.glance.ExperimentalGlanceApi
import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.compose
import androidx.glance.text.TextAlign
import kotlin.math.ceil
import kotlin.math.roundToInt
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
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

  /** The prefix a measuring probe's `contentDescription` carries; the rest is the key. */
  const val TEXT_BOUNDS_TAG = "hw_text_bounds:"

  private const val FONT_MANIFEST = "flutter_assets/FontManifest.json"

  /** How many measuring rounds a single widget size may take before the walk gives up. */
  private const val MAX_MEASURE_ROUNDS = 32

  /**
   * Glance runs one unmanaged composition per widget at a time, and the sizes of a resized widget
   * ask to be measured together.
   */
  private val measureLock = Mutex()

  private const val DEFAULT_FONT_WEIGHT = 400

  private val typefaceCache = HashMap<String, Typeface?>()

  private val manifestLock = Any()

  private var manifestCache: Map<String, List<FontDeclaration>>? = null

  private val probeLock = Any()

  private var probeCache: Bitmap? = null

  /** Which axis a measurement runs along. */
  private enum class Axis {
    Horizontal,
    Vertical,
  }

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

  /**
   * The 1 × 1 transparent bitmap a measuring composition shows in place of a custom font text.
   *
   * The probe stands in for the text while [measureTextBounds] lays the widget out: it draws
   * nothing, takes the modifiers the text would have taken, and is found again by the
   * [TEXT_BOUNDS_TAG] its `contentDescription` carries. One instance is created on first use and
   * shared by every probe of every measurement.
   */
  fun probeBitmap(): Bitmap {
    synchronized(probeLock) {
      probeCache?.let {
        return it
      }
      val bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
      probeCache = bitmap
      return bitmap
    }
  }

  /**
   * The room custom font texts were measured to have, per widget size, keyed the way the generated
   * code names each text.
   *
   * The room of a text is what its ancestors leave it: the widget, less every padding down to it,
   * less every sibling that was measured beside it. A lookup takes the size the widget is currently
   * drawn at, `LocalSize.current`, and picks its entry, or that of the nearest measured size when
   * none matches exactly. A key that was never measured, or that measured as nothing on the
   * requested axis, falls back to the whole widget's width or height, so a text always has
   * somewhere to go.
   *
   * [measureTextBounds] also hands an instance to each of its measuring rounds, holding the keys
   * measured so far; those render for real while the next one is still a probe. A returned instance
   * is never measuring, so it reports every text as drawn.
   */
  class TextBounds
  internal constructor(
      private val bounds: Map<DpSize, Map<String, DpSize>>,
      private val measuring: Boolean = false,
  ) {
    /**
     * The width [key] has to itself when the widget is laid out at [size], in density independent
     * pixels. Pass `LocalSize.current`.
     */
    fun width(key: String, size: DpSize): Float =
        measured(size, key)?.width?.value?.takeIf { it > 0f } ?: size.width.value

    /**
     * The height [key] has to itself when the widget is laid out at [size], in density independent
     * pixels. Pass `LocalSize.current`.
     */
    fun height(key: String, size: DpSize): Float =
        measured(size, key)?.height?.value?.takeIf { it > 0f } ?: size.height.value

    /**
     * Whether [key] still has to be drawn as a probe: only while measuring, and only until its room
     * is known.
     */
    fun isProbe(key: String, size: DpSize): Boolean = measuring && measured(size, key) == null

    /** Whether [size] itself was measured, rather than served by the nearest size that was. */
    fun covers(size: DpSize): Boolean = bounds.containsKey(size)

    /** These bounds with [other]'s sizes added, [other] winning a size both measured. */
    operator fun plus(other: TextBounds): TextBounds = TextBounds(bounds + other.bounds)

    /** What [key] measured at [size], or at the size closest to it that was measured. */
    private fun measured(size: DpSize, key: String): DpSize? {
      bounds[size]?.let {
        return it[key]
      }
      return bounds
          .minByOrNull { (measuredSize, _) -> squaredDistance(measuredSize, size) }
          ?.value
          ?.get(key)
    }

    private fun squaredDistance(one: DpSize, other: DpSize): Float {
      val width = one.width.value - other.width.value
      val height = one.height.value - other.height.value
      return width * width + height * height
    }

    companion object {
      /** Nothing was measured; every lookup falls back to the whole widget. */
      val NONE = TextBounds(emptyMap())
    }
  }

  /**
   * Measures the room every custom font text of the widget [id] has, one text at a time, per size
   * the launcher lays the widget out at.
   *
   * [widget] builds the widget's own layout — every sibling, spacer, padding and nesting of the
   * final one — around the [TextBounds] it is handed: a text whose room is not known yet draws as
   * an `Image` of [probeBitmap] carrying a `contentDescription` of [TEXT_BOUNDS_TAG] plus its key,
   * and every text already measured draws its real bitmap. It is a plain lambda returning a widget
   * rather than a composable so the plugin needs no Compose compiler of its own.
   *
   * A size is measured in rounds: each round composes to `RemoteViews`, inflates and lays them out
   * here rather than on the launcher, and takes the first probe in document order — depth first,
   * children in index order — as that text's room. The next round therefore measures against the
   * earlier texts at their real size, and document order decides who claims a shared line first.
   * That is one composition per custom font text plus one, per size, capped at
   * [MAX_MEASURE_ROUNDS].
   *
   * A probe draws nothing, so its own laid out size says nothing about the text; what is reported
   * is the room its ancestors leave it — the widget, less the padding and margins down to the
   * probe, less every other sibling that was measured beside it along that axis. A weighted sibling
   * such as an alignment spacer counts as taking nothing, since it only claims what is left over.
   *
   * Never throws: when a widget cannot be measured — a preview that no launcher holds, a
   * composition that fails — [TextBounds.NONE] is returned and the widget renders against the whole
   * widget's bounds instead.
   */
  suspend fun measureTextBounds(
      context: Context,
      id: GlanceId,
      widget: (TextBounds) -> GlanceAppWidget,
  ): TextBounds {
    try {
      val appWidgetManager = AppWidgetManager.getInstance(context) ?: return TextBounds.NONE
      val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
      if (appWidgetManager.getAppWidgetInfo(appWidgetId) == null) return TextBounds.NONE
      val sizes = widgetSizes(appWidgetManager.getAppWidgetOptions(appWidgetId))
      if (sizes.isEmpty()) return TextBounds.NONE

      val bounds = HashMap<DpSize, Map<String, DpSize>>(sizes.size)
      for (size in sizes) {
        bounds[size] = measureSize(context, id, size, widget)
      }
      return TextBounds(bounds)
    } catch (e: CancellationException) {
      throw e
    } catch (e: Exception) {
      Log.w(TAG, "Could not measure the text bounds of $id", e)
      return TextBounds.NONE
    }
  }

  /**
   * Measures the room every custom font text of the widget [id] has at [size] alone, the way
   * [measureTextBounds] does for every size the launcher reports.
   *
   * For a size the launcher hands a running widget later — a resize — which the bounds measured up
   * front do not [TextBounds.covers]; add the result to them with [TextBounds.plus].
   */
  suspend fun measureTextBounds(
      context: Context,
      id: GlanceId,
      size: DpSize,
      widget: (TextBounds) -> GlanceAppWidget,
  ): TextBounds {
    try {
      return TextBounds(mapOf(size to measureSize(context, id, size, widget)))
    } catch (e: CancellationException) {
      throw e
    } catch (e: Exception) {
      Log.w(TAG, "Could not measure the text bounds of $id at $size", e)
      return TextBounds.NONE
    }
  }

  private suspend fun measureSize(
      context: Context,
      id: GlanceId,
      size: DpSize,
      widget: (TextBounds) -> GlanceAppWidget,
  ): Map<String, DpSize> {
    val known = LinkedHashMap<String, DpSize>()
    measureLock.withLock {
      for (round in 0 until MAX_MEASURE_ROUNDS) {
        val partial = TextBounds(mapOf(size to known.toMap()), measuring = true)
        val remoteViews = composeAt(widget(partial), context, id, size)
        val (key, room) = measureNextProbe(context, remoteViews, size, known.keys) ?: break
        known[key] = room
      }
    }
    return known
  }

  @OptIn(ExperimentalGlanceApi::class)
  private suspend fun composeAt(
      widget: GlanceAppWidget,
      context: Context,
      id: GlanceId,
      size: DpSize,
  ): RemoteViews = widget.compose(context, id, size = size)

  /**
   * The sizes the launcher lays a widget of [options] out at, the way Glance's `SizeMode.Exact`
   * hands them to a composition as `LocalSize`.
   */
  @Suppress("DEPRECATION")
  private fun widgetSizes(options: Bundle?): List<DpSize> {
    if (options == null) return emptyList()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val exact = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
      if (!exact.isNullOrEmpty()) return exact.map { DpSize(it.width.dp, it.height.dp) }
    }
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
    val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
    val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
    val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
    if (minWidth <= 0 || maxWidth <= 0 || minHeight <= 0 || maxHeight <= 0) return emptyList()
    val portrait = DpSize(minWidth.dp, maxHeight.dp)
    val landscape = DpSize(maxWidth.dp, minHeight.dp)
    return if (portrait == landscape) listOf(portrait) else listOf(portrait, landscape)
  }

  /**
   * Inflates [remoteViews], lays it out at [size] and reads back the room of the first probe whose
   * key is not in [known], or `null` when the composition holds no such probe.
   */
  private suspend fun measureNextProbe(
      context: Context,
      remoteViews: RemoteViews,
      size: DpSize,
      known: Set<String>,
  ): Pair<String, DpSize>? =
      withContext(Dispatchers.Main) {
        val density = context.resources.displayMetrics.density
        val widthPx = (size.width.value * density).roundToInt().coerceAtLeast(1)
        val heightPx = (size.height.value * density).roundToInt().coerceAtLeast(1)
        val host = FrameLayout(context)
        val root = remoteViews.apply(context, host)
        root.measure(
            View.MeasureSpec.makeMeasureSpec(widthPx, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(heightPx, View.MeasureSpec.EXACTLY),
        )
        root.layout(0, 0, widthPx, heightPx)
        firstProbe(root, root, host, density, known)
      }

  /**
   * The first probe in document order below [view] — [view] itself first, then its children in
   * index order — whose key is not in [known], paired with the room it has.
   *
   * [root] is the view that was measured and laid out at the widget's size; [host] the group it was
   * inflated against, which bounds the walk upwards.
   */
  private fun firstProbe(
      view: View,
      root: View,
      host: ViewGroup,
      density: Float,
      known: Set<String>,
  ): Pair<String, DpSize>? {
    val tag = view.contentDescription?.toString()
    if (tag != null && tag.startsWith(TEXT_BOUNDS_TAG)) {
      val key = tag.substring(TEXT_BOUNDS_TAG.length)
      if (key !in known) {
        val widthPx =
            (available(view, root, host, Axis.Horizontal) - padding(view, Axis.Horizontal))
                .coerceAtLeast(0)
        val heightPx =
            (available(view, root, host, Axis.Vertical) - padding(view, Axis.Vertical))
                .coerceAtLeast(0)
        return key to DpSize((widthPx / density).dp, (heightPx / density).dp)
      }
    }
    if (view is ViewGroup) {
      for (child in 0 until view.childCount) {
        firstProbe(view.getChildAt(child), root, host, density, known)?.let {
          return it
        }
      }
    }
    return null
  }

  /**
   * How much room [view] has on [axis], in pixels: what its parent has left after its own padding,
   * after the siblings laid out beside [view] along that axis, and after [view]'s margins.
   *
   * Only a [LinearLayout] whose orientation runs along [axis] hands its children a share of one
   * line; on its cross axis, and in any other group, every child sees the full inner room. A
   * sibling that carries a layout weight is skipped: it takes what is left over rather than a size
   * of its own. The walk stops at [root], the view laid out at the widget's size, and at [host],
   * the group the tree was inflated against.
   */
  private fun available(view: View, root: View, host: ViewGroup, axis: Axis): Int {
    if (view === root) return measuredSize(view, axis)
    val parent = view.parent as? ViewGroup
    if (parent == null || parent === host) return measuredSize(view, axis)
    val inner = available(parent, root, host, axis) - padding(parent, axis)
    var used = 0
    if (parent is LinearLayout && parent.orientation == orientation(axis)) {
      for (index in 0 until parent.childCount) {
        val sibling = parent.getChildAt(index)
        if (sibling === view || sibling.visibility == View.GONE) continue
        if (weightOf(sibling) != 0f) continue
        used += measuredSize(sibling, axis) + margins(sibling, axis)
      }
    }
    return (inner - used - margins(view, axis)).coerceAtLeast(0)
  }

  private fun measuredSize(view: View, axis: Axis): Int =
      if (axis == Axis.Horizontal) view.measuredWidth else view.measuredHeight

  private fun padding(view: View, axis: Axis): Int =
      if (axis == Axis.Horizontal) view.paddingLeft + view.paddingRight
      else view.paddingTop + view.paddingBottom

  private fun margins(view: View, axis: Axis): Int {
    val params = view.layoutParams as? ViewGroup.MarginLayoutParams ?: return 0
    return if (axis == Axis.Horizontal) params.leftMargin + params.rightMargin
    else params.topMargin + params.bottomMargin
  }

  private fun weightOf(view: View): Float =
      (view.layoutParams as? LinearLayout.LayoutParams)?.weight ?: 0f

  private fun orientation(axis: Axis): Int =
      if (axis == Axis.Horizontal) LinearLayout.HORIZONTAL else LinearLayout.VERTICAL

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
