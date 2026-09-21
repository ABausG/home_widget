import '../fonts.dart';
import '../native_helpers.dart';
import '../utils/fnv_hash.dart';
import '../utils/string_literals.dart';
import 'hw_color.dart';
import 'hw_generatable.dart';

enum HWTextAlign { start, end, center, justify }

enum HWFontWeight {
  w100(100),
  w200(200),
  w300(300),
  w400(400),
  w500(500),
  w600(600),
  w700(700),
  w800(800),
  w900(900),
  normal(400),
  bold(700);

  const HWFontWeight(this.value);

  /// The weight on the 100..900 scale a font file is declared with.
  ///
  /// `normal` and `bold` are the names Flutter gives 400 and 700.
  final int value;
}

enum HWTextStyleRole { title, headline, body, callout, caption, captionSmall }

/// How Android renders the text of an [HWTextStyle].
///
/// Android-only: iOS renders the style's [HWTextStyle.fontFamily] whatever this
/// says. A style naming a family renders on Android as a bitmap of that file by
/// default, which is the only way its glyphs reach a widget; this is how a
/// style asks for a Glance `Text` instead, either in the platform's own font
/// ([system]) or in one of the system families Glance can name.
///
/// Glance text is real text: it follows the theme, reports a baseline a row can
/// line up by, and needs no measuring pass. What it gives up is the family
/// itself and the weight, which Glance renders as bold or regular only.
class HWAndroidFont {
  /// The Android system font family Glance names, or null.
  final String? family;

  /// Whether text renders in the bitmap of the style's [HWTextStyle.fontFamily].
  final bool isCustom;

  const HWAndroidFont._({this.family, required this.isCustom});

  /// Text in the bitmap of the style's [HWTextStyle.fontFamily].
  ///
  /// The default; a style naming no family renders as a plain Glance `Text`.
  static const custom = HWAndroidFont._(isCustom: true);

  /// A plain Glance `Text` in the platform's default font, whatever
  /// [HWTextStyle.fontFamily] says.
  static const system = HWAndroidFont._(isCustom: false);

  /// A Glance `Text` in the device's serif family.
  static const serif = HWAndroidFont.family('serif');

  /// A Glance `Text` in the device's sans-serif family.
  static const sansSerif = HWAndroidFont.family('sans-serif');

  /// A Glance `Text` in the device's monospace family.
  static const monospace = HWAndroidFont.family('monospace');

  /// A Glance `Text` in the device's cursive family.
  static const cursive = HWAndroidFont.family('cursive');

  /// A Glance `Text` in any Android system family, e.g. `sans-serif-condensed`.
  ///
  /// The name is handed to Android as it is written; one the device does not
  /// know falls back to its default sans-serif.
  const HWAndroidFont.family(String family)
      : this._(family: family, isCustom: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWAndroidFont &&
          family == other.family &&
          isCustom == other.isCustom;

  @override
  int get hashCode => Object.hash(family, isCustom);

  @override
  String toString() {
    if (isCustom) return 'HWAndroidFont.custom';
    final family = this.family;
    return family == null
        ? 'HWAndroidFont.system'
        : 'HWAndroidFont.family($family)';
  }
}

/// A class representing text styling options for `HWText`.
class HWTextStyle implements HWGeneratable {
  final double? fontSize;
  final HWFontWeight? fontWeight;
  final HWColor? color;
  final bool? italic;
  final bool? underline;
  final bool? lineThrough;

  /// The font family text in this style renders with, as declared under
  /// `flutter: fonts:`, or null for the platform's own font.
  ///
  /// Mirrors Flutter's `TextStyle.fontFamily`: [fontWeight] and [italic] then
  /// pick which file of the family is used rather than being applied on top of
  /// it, so a family with no matching file renders in its nearest one.
  final String? fontFamily;

  /// The package declaring [fontFamily], or null when the app declares it.
  ///
  /// Mirrors Flutter's `TextStyle.package`.
  final String? package;

  /// How Android renders this text, or null for [HWAndroidFont.custom].
  ///
  /// Android-only, and it does not change what iOS renders or which font file
  /// the app bundles: [fontFamily] still decides both.
  final HWAndroidFont? androidFont;

  final HWTextStyle? baseStyle;

  const HWTextStyle({
    this.fontSize,
    this.fontWeight,
    this.color,
    this.italic,
    this.underline,
    this.lineThrough,
    this.fontFamily,
    this.package,
    this.androidFont,
    this.baseStyle,
  });

  /// Resolves the effective style properties by marching up the `baseStyle` chain.
  HWTextStyle _resolve() {
    return _resolveRecursive(this);
  }

  static HWTextStyle _resolveRecursive(HWTextStyle current) {
    if (current.baseStyle == null) {
      if (current is HWRoleTextStyle) {
        return HWTextStyle(
          fontSize: current.fontSize,
          fontWeight: current.fontWeight,
          color: current.color,
          italic: current.italic,
          underline: current.underline,
          lineThrough: current.lineThrough,
          fontFamily: current.fontFamily,
          package: current.package,
          androidFont: current.androidFont,
        );
      }
      return current;
    }

    final baseResolved = _resolveRecursive(current.baseStyle!);

    // A family, the package declaring it and how Android renders it resolve
    // together: overriding the family alone must not keep the base style's
    // package, which would name a family that package does not declare, nor
    // its Android choice, which was made about a family this style replaced.
    final overridesFamily = current.fontFamily != null;

    return HWTextStyle(
      fontSize: current.fontSize ?? baseResolved.fontSize,
      fontWeight: current.fontWeight ?? baseResolved.fontWeight,
      color: current.color ?? baseResolved.color,
      italic: current.italic ?? baseResolved.italic,
      underline: current.underline ?? baseResolved.underline,
      lineThrough: current.lineThrough ?? baseResolved.lineThrough,
      fontFamily: current.fontFamily ?? baseResolved.fontFamily,
      package: overridesFamily
          ? current.package
          : (current.package ?? baseResolved.package),
      androidFont: overridesFamily
          ? current.androidFont
          : (current.androidFont ?? baseResolved.androidFont),
    );
  }

  HWTextStyleRole? _getEffectiveRole() {
    HWTextStyle? current = this;
    while (current != null) {
      if (current is HWRoleTextStyle) {
        return current.role;
      }
      current = current.baseStyle;
    }
    return null;
  }

  /// The font file text in this style renders with, or null when it renders in
  /// the platform's own font.
  ///
  /// Resolved through the whole `baseStyle` chain: the family and package of
  /// the style that names them, at the weight and slant the chain resolves to.
  HWFontVariant? get fontVariant {
    final resolved = _resolve();
    final family = resolved.fontFamily;
    if (family == null) return null;
    return HWFontVariant(
      family: family,
      package: resolved.package,
      weight: (resolved.fontWeight ??
              _androidRoleFontWeight(_getEffectiveRole()) ??
              HWFontWeight.normal)
          .value,
      italic: resolved.italic == true,
    );
  }

  /// The size text in this style renders at, the effective role's own size
  /// included, or null when nothing sets one.
  double? get effectiveFontSize =>
      _resolve().fontSize ?? _androidRoleFontSize(_getEffectiveRole());

  /// [effectiveFontSize], or [hwDefaultFontSize] when nothing sets one.
  ///
  /// Rendering a custom family needs a number on both platforms — iOS bakes it
  /// into the `CTFont`, Android into the glyph mask — so a style that names one
  /// but no size lands here rather than on the platform's own default.
  double get effectiveFontSizeOrDefault =>
      effectiveFontSize ?? hwDefaultFontSize;

  /// The color text in this style renders in, or null for the platform default.
  HWColor? get effectiveColor => _resolve().color;

  /// How Android renders text in this style, as [HWAndroidFont] resolves it.
  ///
  /// Glance cannot name a custom font family, so a style naming one renders by
  /// default as a bitmap the core plugin draws. Everything else — a style with
  /// no family, and one whose [androidFont] asks for the platform font or a
  /// system family — renders as a Glance `Text`. Both are built out of the
  /// style resolved here, so a text property is added in one place.
  HWKotlinTextRenderer kotlinRenderer({HWTextAlign? textAlign}) {
    final androidFont = _effectiveAndroidFont;
    final variant = fontVariant;
    if (!androidFont.isCustom || variant == null) {
      return _glanceRenderer(textAlign, fontFamily: androidFont.family);
    }

    final resolved = _resolve();
    return HWBitmapTextRenderer(
      variant: variant,
      fontSize: effectiveFontSizeOrDefault,
      color: resolved.color,
      italic: resolved.italic == true,
      underline: resolved.underline == true,
      lineThrough: resolved.lineThrough == true,
      textAlign: textAlign,
    );
  }

  /// How Android renders this text once the `baseStyle` chain is resolved.
  HWAndroidFont get _effectiveAndroidFont =>
      _resolve().androidFont ?? HWAndroidFont.custom;

  HWGlanceTextRenderer _glanceRenderer(
    HWTextAlign? textAlign, {
    String? fontFamily,
  }) {
    final resolved = _resolve();
    final role = _getEffectiveRole();
    return HWGlanceTextRenderer(
      color: resolved.color,
      fontSize: resolved.fontSize ?? _androidRoleFontSize(role),
      fontWeight: resolved.fontWeight ?? _androidRoleFontWeight(role),
      italic: resolved.italic == true,
      underline: resolved.underline == true,
      lineThrough: resolved.lineThrough == true,
      textAlign: textAlign,
      fontFamily: fontFamily,
    );
  }

  /// The imports the `TextStyle(...)` of [toKotlin] needs.
  ///
  /// A custom family is not part of that style, so these are the Glance
  /// renderer's imports whatever family the style names. Text in a custom
  /// family is emitted through [kotlinRenderer] instead, and takes its imports
  /// off the renderer that emitted it.
  @override
  Set<String> get kotlinImports =>
      _glanceRenderer(null, fontFamily: _effectiveAndroidFont.family)
          .kotlinImports;

  @override
  Set<String> get swiftViewModifiers {
    final resolved = _resolve();
    return {
      if (resolved.color != null) ...resolved.color!.swiftViewModifiers,
    };
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final resolved = _resolve();
    final effectiveRole = _getEffectiveRole();
    final parts = <String>[];

    final variant = fontVariant;
    if (variant != null) {
      // The weight and slant picked the file, so applying them again on top of
      // it would double up on what the font already is.
      final size = effectiveFontSizeOrDefault;
      final family = escapeSwiftStringLiteral(variant.flutterFamilyKey);
      parts.add(
        '.font(${HWNativeHelper.hwFont.name}("$family", '
        '${variant.weight}, ${variant.italic}, ${hwSizeLiteral(size)}))',
      );
    } else if (resolved.fontSize != null && resolved.fontWeight != null) {
      parts.add(
        '.font(.system(size: ${resolved.fontSize}, weight: ${_swiftFontWeight(resolved.fontWeight!)}))',
      );
    } else if (resolved.fontSize != null) {
      parts.add('.font(.system(size: ${resolved.fontSize}))');
    } else if (effectiveRole != null) {
      parts.add('.font(.${_swiftRole(effectiveRole)})');
      if (resolved.fontWeight != null) {
        parts.add('.fontWeight(${_swiftFontWeight(resolved.fontWeight!)})');
      }
    } else if (resolved.fontWeight != null) {
      parts.add('.fontWeight(${_swiftFontWeight(resolved.fontWeight!)})');
    }

    if (resolved.color != null) {
      parts.add(
        '.foregroundColor(${resolved.color!.toSwift(indent, dataExpr: dataExpr)})',
      );
    }

    if (variant == null && resolved.italic == true) {
      parts.add('.italic()');
    }
    if (resolved.underline == true) {
      parts.add('.underline(true)');
    }
    if (resolved.lineThrough == true) {
      parts.add('.strikethrough(true)');
    }

    return parts.join('');
  }

  /// The Glance `TextStyle(...)` for this style.
  ///
  /// A style naming no color gets [hwDefaultContentColor], which Glance itself
  /// would render as opaque black.
  ///
  /// A custom [fontFamily] is not part of it: Glance cannot name one, so text
  /// in such a style renders through [HWBitmapTextRenderer] instead, off the
  /// same resolved values. The system family an [androidFont] asks for is
  /// something Glance can name, and is part of it.
  @override
  String toKotlin(int indent, {required String dataExpr}) =>
      _glanceRenderer(null, fontFamily: _effectiveAndroidFont.family)
          .styleExpression(indent, dataExpr: dataExpr);
}

/// How Android renders text in a style.
///
/// Glance renders text itself unless the style names a font family, in which
/// case the core plugin draws it into a bitmap instead.
sealed class HWKotlinTextRenderer {
  const HWKotlinTextRenderer();

  /// The Kotlin imports the code this emits needs.
  Set<String> get kotlinImports;

  /// The Kotlin rendering [text], the expression the bound value is read with.
  String toKotlin(
    int indent, {
    required String dataExpr,
    required String text,
  });

  /// What a baseline-aligned [HWRow] lines this text up by.
  HWKotlinBaselineText get kotlinBaselineText;
}

/// The text a baseline-aligned [HWRow] lines one of its children up by.
///
/// A row only places its children itself where the layout cannot: a Glance
/// `Text` is a `TextView` and reports a baseline the `LinearLayout` corrects
/// by, while a bitmap text is an `Image` and reports none.
class HWKotlinBaselineText {
  /// The Kotlin reading how far below the top of its line the baseline sits,
  /// in pixels, out of the expression the widget's data is read from.
  ///
  /// Needs `HomeWidgetFonts` imported and `context` in scope.
  final String Function(String dataExpr) ascent;

  /// Whether the text is drawn into a bitmap, and so carries no baseline of
  /// its own for the layout to correct.
  final bool isBitmap;

  /// Why a row cannot pad this child, or null when it can.
  ///
  /// Reported rather than thrown, so that the context-free import pass, which
  /// asks the same question of every widget, does not fail over a tree only
  /// the emit rejects.
  final String? conflict;

  const HWKotlinBaselineText({
    required this.ascent,
    required this.isBitmap,
    this.conflict,
  });
}

/// Text Glance renders itself, in the platform's own font or in a system
/// family it names.
class HWGlanceTextRenderer extends HWKotlinTextRenderer {
  /// The color the text renders in, or null for [hwDefaultContentColor].
  final HWColor? color;

  final double? fontSize;
  final HWFontWeight? fontWeight;
  final bool italic;
  final bool underline;
  final bool lineThrough;
  final HWTextAlign? textAlign;

  /// The Android system font family the text renders in, or null for the
  /// platform's own font.
  ///
  /// Glance hands it to Android as a `TypefaceSpan`, so an unknown name falls
  /// back to the device's default sans-serif rather than failing.
  final String? fontFamily;

  const HWGlanceTextRenderer({
    this.color,
    this.fontSize,
    this.fontWeight,
    this.italic = false,
    this.underline = false,
    this.lineThrough = false,
    this.textAlign,
    this.fontFamily,
  });

  @override
  Set<String> get kotlinImports => {
        'import androidx.glance.text.Text',
        'import androidx.glance.text.TextStyle',
        ...(color?.kotlinImports ?? hwDefaultContentColorKotlinImports),
        if (fontSize != null) 'import androidx.compose.ui.unit.sp',
        if (fontWeight != null) 'import androidx.glance.text.FontWeight',
        if (italic) 'import androidx.glance.text.FontStyle',
        if (underline || lineThrough)
          'import androidx.glance.text.TextDecoration',
        if (textAlign != null) 'import androidx.glance.text.TextAlign',
        if (fontFamily != null) ...[
          'import androidx.glance.text.FontFamily',
          'import android.graphics.Typeface',
        ],
      };

  /// The `TextStyle(...)` the Glance `Text` is styled with.
  String styleExpression(int indent, {required String dataExpr}) {
    final tint = color ?? hwDefaultContentColor;
    final args = <String>[
      'color = ${tint.toKotlin(indent, dataExpr: dataExpr)}',
      if (fontSize case final size?) 'fontSize = ${hwSizeLiteral(size)}.sp',
      if (fontWeight case final weight?)
        'fontWeight = ${_kotlinFontWeight(weight)}',
      if (italic) 'fontStyle = FontStyle.Italic',
      if (underline && lineThrough)
        'textDecoration = TextDecoration.combine(listOf(TextDecoration.Underline, TextDecoration.LineThrough))'
      else if (underline)
        'textDecoration = TextDecoration.Underline'
      else if (lineThrough)
        'textDecoration = TextDecoration.LineThrough',
      if (textAlign case final align?) 'textAlign = ${_kotlinTextAlign(align)}',
      if (fontFamily case final family?)
        'fontFamily = FontFamily("${escapeKotlinStringLiteral(family)}")',
    ];
    return 'TextStyle(${args.join(', ')})';
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    required String text,
  }) {
    final pad = '    ' * indent;
    final style = styleExpression(indent, dataExpr: dataExpr);
    return '${pad}Text(text = $text, style = $style)';
  }

  /// The typeface the ascent is measured in: the one Glance itself renders
  /// with, built out of the same family and weight bucket the style names.
  ///
  /// Null for the platform's own font, which the measuring helper resolves.
  String get _typefaceExpression {
    final family = fontFamily;
    if (family == null) return 'null';
    final bold =
        _kotlinGlanceFontWeight(fontWeight) != _HWGlanceFontWeight.normal;
    final style = switch ((bold, italic)) {
      (true, true) => 'Typeface.BOLD_ITALIC',
      (true, false) => 'Typeface.BOLD',
      (false, true) => 'Typeface.ITALIC',
      (false, false) => 'Typeface.NORMAL',
    };
    return 'Typeface.create("${escapeKotlinStringLiteral(family)}", $style)';
  }

  /// A style naming no size renders at the app theme's own, which only the
  /// device can answer for, so the size is left open rather than guessed at.
  @override
  HWKotlinBaselineText get kotlinBaselineText => HWKotlinBaselineText(
        ascent: (dataExpr) {
          final size =
              fontSize == null ? 'null' : '${hwSizeLiteral(fontSize!)}f';
          final weight = _kotlinGlanceFontWeight(fontWeight).value;
          return 'HomeWidgetFonts.textAscentPx(context, '
              '$_typefaceExpression, $size, '
              'weight = $weight, italic = $italic)';
        },
        isBitmap: false,
      );
}

/// Text the core plugin draws into a bitmap, shown as a tinted `Image`.
///
/// A bitmap needs the room it may take before it is drawn, which Glance cannot
/// answer for. The generated widget therefore composes twice: a measuring pass
/// the core plugin runs with no bounds, in which every such text renders as a
/// probe tagged with its [boundsKey], and the real one, in which each looks its
/// measured room back up under that key.
class HWBitmapTextRenderer extends HWKotlinTextRenderer {
  /// The font file the glyphs are drawn out of.
  final HWFontVariant variant;

  /// The size the glyphs are drawn at, which a bitmap cannot leave open.
  final double fontSize;

  /// The color the mask is tinted in, or null for [hwDefaultContentColor]: an
  /// untinted mask renders white on white.
  final HWColor? color;

  final bool italic;
  final bool underline;
  final bool lineThrough;
  final HWTextAlign? textAlign;

  const HWBitmapTextRenderer({
    required this.variant,
    required this.fontSize,
    this.color,
    this.italic = false,
    this.underline = false,
    this.lineThrough = false,
    this.textAlign,
  });

  @override
  Set<String> get kotlinImports => {
        'import androidx.glance.ColorFilter',
        'import androidx.glance.GlanceModifier',
        'import androidx.glance.Image',
        'import androidx.glance.ImageProvider',
        'import androidx.glance.LocalSize',
        'import es.antonborri.home_widget.HomeWidgetFonts',
        if (textAlign != null) 'import androidx.glance.text.TextAlign',
        ...(color?.kotlinImports ?? hwDefaultContentColorKotlinImports),
      };

  /// Whether the bitmap is as wide as the text has room for.
  ///
  /// It is otherwise cropped to the widest line, which leaves an alignment
  /// nothing to move the text within.
  bool get fillsWidth {
    final align = textAlign;
    return align != null && _kotlinTextAlign(align) != 'TextAlign.Start';
  }

  /// The Kotlin loading the font file the glyphs are drawn out of.
  String get _typefaceExpression {
    final family = escapeKotlinStringLiteral(variant.flutterFamilyKey);
    return 'HomeWidgetFonts.typeface(context, "$family", '
        '${variant.weight}, ${variant.italic})';
  }

  @override
  HWKotlinBaselineText get kotlinBaselineText => HWKotlinBaselineText(
        ascent: (dataExpr) =>
            'HomeWidgetFonts.textAscentPx(context, $_typefaceExpression, '
            '${hwSizeLiteral(fontSize)}f)',
        isBitmap: true,
      );

  /// The key the room for [text] is measured and looked back up under.
  ///
  /// It covers everything deciding how much the glyphs take: the expression
  /// they are read out of, the file they are drawn from, the size they are
  /// drawn at, and the alignment and decorations drawn around them. Two texts
  /// agreeing on all of that share a key, and with it the room the measuring
  /// pass found.
  String boundsKey(String text) {
    final parts = <String>[
      text,
      variant.flutterFamilyKey,
      '${variant.weight}',
      '${variant.italic}',
      hwSizeLiteral(fontSize),
      textAlign?.name ?? '',
      'underline=$underline',
      'lineThrough=$lineThrough',
    ];
    return fnv1a32(parts.join(_boundsKeySeparator))
        .toRadixString(16)
        .padLeft(8, '0');
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    required String text,
  }) {
    final pad = '    ' * indent;
    final typeface = _typefaceExpression;
    final tint =
        (color ?? hwDefaultContentColor).toKotlin(indent, dataExpr: dataExpr);
    final key = boundsKey(text);

    final buffer = StringBuffer();
    buffer.writeln('${pad}Image(');
    buffer.writeln('$pad    modifier = GlanceModifier,');
    buffer.writeln('$pad    provider = ImageProvider(');
    buffer.writeln(
      '$pad        if (textBounds.isProbe("$key", LocalSize.current)) '
      'HomeWidgetFonts.probeBitmap()',
    );
    buffer.writeln('$pad        else HomeWidgetFonts.textBitmap(');
    buffer.writeln('$pad            context,');
    buffer.writeln('$pad            $typeface,');
    buffer.writeln('$pad            $text,');
    buffer.writeln('$pad            fontSizeSp = ${hwSizeLiteral(fontSize)}f,');
    if (underline) {
      buffer.writeln('$pad            underline = true,');
    }
    if (lineThrough) {
      buffer.writeln('$pad            lineThrough = true,');
    }
    if (textAlign case final align?) {
      buffer.writeln(
        '$pad            textAlign = ${_kotlinTextAlign(align)},',
      );
    }
    buffer.writeln(
      '$pad            maxWidthDp = '
      'textBounds.width("$key", LocalSize.current),',
    );
    buffer.writeln(
      '$pad            maxHeightDp = '
      'textBounds.height("$key", LocalSize.current),',
    );
    if (fillsWidth) {
      buffer.writeln('$pad            fillWidth = true,');
    }
    buffer.writeln('$pad        )');
    buffer.writeln('$pad    ),');
    buffer.writeln(
      '$pad    contentDescription = '
      'if (textBounds.isProbe("$key", LocalSize.current)) '
      '"$_hwTextBoundsTag$key" else $text,',
    );
    buffer.writeln('$pad    colorFilter = ColorFilter.tint($tint),');
    buffer.write('$pad)');
    return buffer.toString();
  }
}

/// U+001F, spelled [String.fromCharCode] rather than written out: it separates
/// the parts [HWBitmapTextRenderer.boundsKey] digests, so that a text ending
/// where the next part begins cannot collide with another one.
final String _boundsKeySeparator = String.fromCharCode(31);

/// What a measuring pass recognizes a text probe by, `TEXT_BOUNDS_TAG` on the
/// Kotlin side, followed by the key the room is stored under.
const String _hwTextBoundsTag = 'hw_text_bounds:';

class HWRoleTextStyle extends HWTextStyle {
  final HWTextStyleRole role;

  const HWRoleTextStyle({
    required this.role,
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  });

  const HWRoleTextStyle.title({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  }) : role = HWTextStyleRole.title;

  const HWRoleTextStyle.headline({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  }) : role = HWTextStyleRole.headline;

  const HWRoleTextStyle.body({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  }) : role = HWTextStyleRole.body;

  const HWRoleTextStyle.callout({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  }) : role = HWTextStyleRole.callout;

  const HWRoleTextStyle.caption({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  }) : role = HWTextStyleRole.caption;

  const HWRoleTextStyle.captionSmall({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.fontFamily,
    super.package,
    super.androidFont,
    super.baseStyle,
  }) : role = HWTextStyleRole.captionSmall;
}

/// The size a custom font renders at when neither a size nor a role sets one.
///
/// A Glance `Text` falls back to the platform's own default, but picking a font
/// file needs a number, so text in a custom family lands on the body role's
/// size instead of on nothing.
const double hwDefaultFontSize = 16.0;

String _swiftFontWeight(HWFontWeight weight) {
  switch (weight) {
    case HWFontWeight.w100:
      return '.ultraLight';
    case HWFontWeight.w200:
      return '.thin';
    case HWFontWeight.w300:
      return '.light';
    case HWFontWeight.w400:
      return '.regular';
    case HWFontWeight.w500:
      return '.medium';
    case HWFontWeight.w600:
      return '.semibold';
    case HWFontWeight.w700:
      return '.bold';
    case HWFontWeight.w800:
      return '.heavy';
    case HWFontWeight.w900:
      return '.black';
    case HWFontWeight.normal:
      return '.regular';
    case HWFontWeight.bold:
      return '.bold';
  }
}

String _kotlinTextAlign(HWTextAlign align) {
  switch (align) {
    case HWTextAlign.start:
      return 'TextAlign.Start';
    case HWTextAlign.end:
      return 'TextAlign.End';
    case HWTextAlign.center:
      return 'TextAlign.Center';
    case HWTextAlign.justify:
      return 'TextAlign.Start'; // default fallback
  }
}

/// The Glance weight bucket text of [weight] renders in.
///
/// Glance has three, and the one a text lands in decides both the `FontWeight`
/// the style names and the weight the platform's own font is drawn at, so the
/// generated style and the ascent the row measures follow the one mapping. A
/// style naming no weight renders in Glance's own default, [HWFontWeight.w400].
_HWGlanceFontWeight _kotlinGlanceFontWeight(HWFontWeight? weight) {
  switch (weight) {
    case HWFontWeight.w100:
    case HWFontWeight.w200:
    case HWFontWeight.w300:
    case HWFontWeight.w400:
    case HWFontWeight.normal:
    case null:
      return _HWGlanceFontWeight.normal;
    case HWFontWeight.w500:
    case HWFontWeight.w600:
      return _HWGlanceFontWeight.medium;
    case HWFontWeight.w700:
    case HWFontWeight.w800:
    case HWFontWeight.w900:
    case HWFontWeight.bold:
      return _HWGlanceFontWeight.bold;
  }
}

/// One of the three weights a Glance `TextStyle` can name.
enum _HWGlanceFontWeight {
  normal('FontWeight.Normal', 400),
  medium('FontWeight.Medium', 500),
  bold('FontWeight.Bold', 700);

  const _HWGlanceFontWeight(this.kotlin, this.value);

  /// The `FontWeight` constant the generated style names.
  final String kotlin;

  /// The weight on the 100..900 scale Glance's own `TextAppearance` draws this
  /// bucket at, which is what the platform's own font is measured in.
  final int value;
}

String _kotlinFontWeight(HWFontWeight weight) =>
    _kotlinGlanceFontWeight(weight).kotlin;

String _swiftRole(HWTextStyleRole role) {
  switch (role) {
    case HWTextStyleRole.title:
      return 'title';
    case HWTextStyleRole.headline:
      return 'headline';
    case HWTextStyleRole.body:
      return 'body';
    case HWTextStyleRole.callout:
      return 'callout';
    case HWTextStyleRole.caption:
      return 'caption';
    case HWTextStyleRole.captionSmall:
      return 'caption2';
  }
}

double? _androidRoleFontSize(HWTextStyleRole? role) {
  switch (role) {
    case HWTextStyleRole.title:
      return 22.0;
    case HWTextStyleRole.headline:
      return 18.0;
    case HWTextStyleRole.body:
      return 16.0;
    case HWTextStyleRole.callout:
      return 14.0;
    case HWTextStyleRole.caption:
      return 12.0;
    case HWTextStyleRole.captionSmall:
      return 11.0;
    case null:
      return null;
  }
}

HWFontWeight? _androidRoleFontWeight(HWTextStyleRole? role) {
  switch (role) {
    case HWTextStyleRole.title:
      return HWFontWeight.normal;
    case HWTextStyleRole.headline:
      return HWFontWeight.w600;
    case HWTextStyleRole.body:
      return HWFontWeight.normal;
    case HWTextStyleRole.callout:
      return HWFontWeight.normal;
    case HWTextStyleRole.caption:
      return HWFontWeight.normal;
    case HWTextStyleRole.captionSmall:
      return HWFontWeight.w500;
    case null:
      return null;
  }
}
