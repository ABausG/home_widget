part of 'hw_widget.dart';

/// An icon widget for use in widgetBuilder.
///
/// Icons render as a glyph of their own font, which is copied next to the
/// generated widget and subset down to the glyphs the schema names — Flutter
/// tree-shakes icon fonts out of `flutter_assets`, so there is nothing to read
/// in place the way an asset image is.
///
/// Two const constructors:
/// - `HWIcon.fixed(Icons.favorite)` -- one hardcoded icon
/// - `HWIcon(HWIconData('mood', icons: [...]))` -- one of a fixed set, chosen
///   by the app at runtime
///
/// The data form takes an [HWIconData], optionally wrapped in an [HWJson]
/// and/or an [HWTimedData], exactly like [HWImage]. Nothing is rendered while
/// there is no stored value and the field declares no default.
///
/// The `icon` of [HWIcon.fixed] is a Flutter `IconData` constant, typed as
/// [Object] for the reason [HWIconData] spells out.
class HWIcon extends HWWidget implements HWDataWidget {
  /// The icon passed to [HWIcon.fixed] exactly as written, null otherwise.
  ///
  /// Only ever set on the const instance living inside the annotation: the
  /// decoder reads its codepoint and font and hands back an [HWIcon.glyph].
  final Object? icon;

  /// The glyph a constant icon renders, or null for the data form.
  final int? codePoint;

  /// The font a constant icon is drawn out of, or null for the data form,
  /// which reads it off its [HWIconData].
  final HWIconFont? font;

  /// Whether a constant icon mirrors in a right-to-left layout, as the
  /// `IconData.matchTextDirection` of the icon the schema named declares.
  ///
  /// Always false for the data form, which reads the flag off every entry of
  /// its [HWIconData] instead.
  final bool matchTextDirection;

  /// The icon data passed to the default constructor, null for a constant
  /// icon.
  final HWDataType<dynamic>? data;

  /// The edge length of the rendered glyph, in logical pixels.
  final double size;

  /// The color the glyph is tinted in, or null for the platform's primary
  /// content color.
  final HWColor? color;

  /// Accessibility description of the icon, or null for a decorative one.
  final String? semanticLabel;

  /// Namespace for the generated font resources this icon is drawn out of, as
  /// `hw_font_<snake_widget_class>`.
  ///
  /// Stamped on by the parser, like the one an [HWTextStyle] carries.
  final String? fontResourcePrefix;

  /// Renders the icon stored under [icon].
  ///
  /// [icon] is an [HWIconData], optionally wrapped in an [HWJson] to read it
  /// from a JSON group and/or an [HWTimedData] to make it time-based.
  const HWIcon(
    HWDataType<dynamic> icon, {
    this.size = 24,
    this.color,
    this.semanticLabel,
  })  : data = icon,
        icon = null,
        codePoint = null,
        font = null,
        matchTextDirection = false,
        fontResourcePrefix = null;

  /// Renders the hardcoded Flutter [icon], e.g. `Icons.favorite`.
  const HWIcon.fixed(
    Object this.icon, {
    this.size = 24,
    this.color,
    this.semanticLabel,
  })  : data = null,
        codePoint = null,
        font = null,
        matchTextDirection = false,
        fontResourcePrefix = null;

  /// Renders [codePoint] out of [font].
  ///
  /// What [HWIcon.fixed] decodes to, and the way to name a glyph without a
  /// Flutter `IconData` to point at.
  const HWIcon.glyph(
    int this.codePoint, {
    required HWIconFont this.font,
    this.size = 24,
    this.color,
    this.semanticLabel,
    this.matchTextDirection = false,
  })  : icon = null,
        data = null,
        fontResourcePrefix = null;

  /// [HWIcon] rebuilt by the parser with [fontResourcePrefix] resolved.
  ///
  /// Codegen-internal: built by the decoder and by `home_widget_cli`, not by
  /// app code.
  const HWIcon.resolved(
    HWDataType<dynamic> icon, {
    required this.fontResourcePrefix,
    this.size = 24,
    this.color,
    this.semanticLabel,
  })  : data = icon,
        icon = null,
        codePoint = null,
        font = null,
        matchTextDirection = false;

  /// [HWIcon.glyph] rebuilt by the parser with [fontResourcePrefix] resolved.
  ///
  /// Codegen-internal; see [HWIcon.resolved].
  const HWIcon.resolvedGlyph(
    int this.codePoint, {
    required HWIconFont this.font,
    required this.fontResourcePrefix,
    this.size = 24,
    this.color,
    this.semanticLabel,
    this.matchTextDirection = false,
  })  : icon = null,
        data = null;

  /// The icon field this widget renders, or null for a constant icon.
  ///
  /// Keeps the [HWTimedData] and [HWJson] wrappers, so the field is registered
  /// as time-based / as part of its group and the access expressions come out
  /// right; [iconData] strips them.
  HWDataType<dynamic>? get dataType => data;

  /// The icon field itself, with any [HWTimedData] and [HWJson] wrappers
  /// removed, or null for a constant icon.
  ///
  /// Throws a [GeneratorError] when the widget was handed something other than
  /// an [HWIconData], which only a hand-built tree can do — the decoder rejects
  /// it earlier.
  HWIconData? get iconData {
    final data = this.data;
    if (data == null) return null;
    final icon = iconLeafOf(data);
    if (icon != null) return icon;
    throw GeneratorError(
      'HWIcon requires an HWIconData, got: ${data.runtimeType}.',
    );
  }

  /// The font this icon is drawn out of.
  ///
  /// Throws a [GeneratorError] on a tree that was never decoded from a schema,
  /// where the icon is still the raw Flutter constant the annotation wrote.
  HWIconFont get iconFont {
    final resolved = font ?? iconData?.iconFont;
    if (resolved != null) return resolved;
    throw GeneratorError(
      'The font of this HWIcon is unknown. An icon has to be declared in a '
      '@HomeWidget annotation, or built with HWIcon.glyph.',
    );
  }

  /// The color the glyph is tinted in: [color], or the platform's primary
  /// content color.
  HWColor get effectiveColor =>
      color ?? const HWDefaultColor(HWColorRole.contentPrimary);

  @override
  Set<HWDataType<dynamic>> get dataDependencies {
    final data = this.data;
    return data == null ? const {} : {data};
  }

  @override
  Map<HWIconFont, Set<int>> get ownIconCodePoints {
    final data = iconData;
    if (data != null) return {iconFont: data.codePoints};
    final codePoint = this.codePoint;
    if (codePoint == null) return const {};
    return {
      iconFont: {codePoint},
    };
  }

  @override
  Set<HWNativeHelper> get renderHelpers => const {HWNativeHelper.hwBundledFont};

  @override
  Set<String> get kotlinImports => {
        'import androidx.compose.ui.unit.dp',
        'import androidx.glance.ColorFilter',
        'import androidx.glance.GlanceModifier',
        'import androidx.glance.Image',
        'import androidx.glance.ImageProvider',
        'import androidx.glance.layout.size',
        'import es.antonborri.home_widget.HomeWidgetFonts',
        ...effectiveColor.kotlinImports,
      };

  @override
  Set<String> get swiftViewModifiers => {
        ...effectiveColor.swiftViewModifiers,
        if (_swiftMirrorCondition != null)
          '@Environment(\\.layoutDirection) var layoutDirection',
      };

  /// Decodes an [HWIcon] from an analyzer constant.
  static HWIcon fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final size =
        WidgetValueDecoder.getField(obj, 'size')?.toDoubleValue() ?? 24;
    final colorObj = WidgetValueDecoder.getField(obj, 'color');
    final color = WidgetValueDecoder.decodeColor(colorObj);
    final semanticLabel =
        WidgetValueDecoder.getField(obj, 'semanticLabel')?.toStringValue();
    final fontResourcePrefix = decoder.fontResourcePrefix;

    final iconObj = WidgetValueDecoder.getField(obj, 'icon');
    if (iconObj != null && !iconObj.isNull) {
      final codePoint = WidgetValueDecoder.decodeIconCodePoint(iconObj);
      final font = WidgetValueDecoder.decodeIconFont(iconObj);
      if (codePoint == null || font == null) {
        throw GeneratorError(
          'Could not decode HWIcon.fixed. It takes a Flutter IconData such as '
          'Icons.favorite, got: ${iconObj.type?.element?.name}',
        );
      }
      return HWIcon.resolvedGlyph(
        codePoint,
        font: font,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        fontResourcePrefix: fontResourcePrefix,
        matchTextDirection:
            WidgetValueDecoder.decodeIconMatchTextDirection(iconObj),
      );
    }

    final dataObj = WidgetValueDecoder.getField(obj, 'data');
    final data = WidgetValueDecoder.decodeDataType(
      dataObj,
      defaultLocale: decoder.defaultLocale,
      resourcePrefix: decoder.resourcePrefix,
    );
    if (data != null && iconLeafOf(data) != null) {
      return HWIcon.resolved(
        data,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        fontResourcePrefix: fontResourcePrefix,
      );
    }

    throw GeneratorError(
      'Could not decode HWIcon. HWIcon requires an HWIconData, optionally '
      'wrapped in HWJson and/or HWTimedData, got: '
      '${dataObj?.type?.element?.name}',
    );
  }

  /// The SwiftUI modifiers every glyph carries, whatever it is rendered from.
  List<String> _swiftGlyphModifiers(int indent, String dataExpr) {
    final font = '${HWNativeHelper.hwBundledFont.name}'
        '("${iconFont.iosResourceName}", size: ${hwSizeLiteral(size)})';
    final semanticLabel = this.semanticLabel;
    final mirror = _swiftMirrorCondition;
    return [
      '.font($font)',
      '.foregroundColor(${effectiveColor.toSwift(indent, dataExpr: dataExpr)})',
      if (semanticLabel != null)
        '.accessibilityLabel("${escapeSwiftStringLiteral(semanticLabel)}")'
      else
        '.accessibilityHidden(true)',
      if (mirror != null) '.scaleEffect(x: $mirror ? -1 : 1, y: 1)',
    ];
  }

  /// The Swift condition under which the glyph is drawn mirrored, or null for
  /// a constant icon that is not directional.
  ///
  /// Reads `layoutDirection`, which [swiftViewModifiers] declares on the
  /// generated view alongside it, and — for the data form — the file-level
  /// `hwMirroredIcons` the generator emits.
  String? get _swiftMirrorCondition {
    const rightToLeft = 'layoutDirection == .rightToLeft';
    if (matchTextDirection) return rightToLeft;
    if (data == null) return null;
    return '$rightToLeft && hwMirroredIcons.contains(codePoint)';
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final buffer = StringBuffer();

    final codePoint = this.codePoint;
    final String bodyPad;
    if (codePoint == null) {
      final access = dataType!.swiftAccess(dataExpr);
      buffer.writeln(
        '${pad}if let codePoint = $access, '
        'let value = UInt32(exactly: codePoint), '
        'let scalar = UnicodeScalar(value) {',
      );
      buffer.writeln('$pad    Text(String(scalar))');
      bodyPad = '$pad    ';
    } else {
      final hex = _codePointLiteral(codePoint);
      buffer.writeln('${pad}Text(String(UnicodeScalar(UInt32($hex))!))');
      bodyPad = pad;
    }

    for (final modifier in _swiftGlyphModifiers(indent, dataExpr)) {
      buffer.writeln('$bodyPad    $modifier');
    }

    if (codePoint == null) {
      buffer.write('$pad}');
      return buffer.toString();
    }
    return buffer.toString().trimRight();
  }

  /// The Glance `Image(...)` call drawing [codePointExpr] out of the icon font.
  ///
  /// One line, and with the modifier first, so a parent injecting a
  /// `GlanceModifier` finds the one this call already carries and chains onto
  /// it rather than passing a second one.
  String _kotlinImage(int indent, String dataExpr, String codePointExpr) {
    final semanticLabel = this.semanticLabel;
    final description = semanticLabel == null
        ? 'null'
        : '"${escapeKotlinStringLiteral(semanticLabel)}"';
    final resource = iconFont.androidResourceName(fontResourcePrefix);
    final tint = effectiveColor.toKotlin(indent, dataExpr: dataExpr);
    final sizeLiteral = hwSizeLiteral(size);
    return 'Image(modifier = GlanceModifier.size($sizeLiteral.dp), '
        'provider = ImageProvider('
        'HomeWidgetFonts.iconBitmap(context, R.font.$resource, '
        '$codePointExpr, ${sizeLiteral}f$_kotlinMatchTextDirection)), '
        'contentDescription = $description, '
        'colorFilter = ColorFilter.tint($tint))';
  }

  /// The `matchTextDirection` argument of the `iconBitmap` call, leading comma
  /// included, or the empty string when a constant icon is not directional and
  /// the argument is left to its default.
  ///
  /// The data form asks the file-level `hwMirroredIcons` the generator emits.
  String get _kotlinMatchTextDirection {
    if (matchTextDirection) return ', matchTextDirection = true';
    if (data == null) return '';
    return ', matchTextDirection = codePoint in hwMirroredIcons';
  }

  @override
  String toKotlinIn(
    int indent, {
    required String dataExpr,
    required HWKotlinConstraints constraints,
  }) {
    final pad = '    ' * indent; // Use 4 spaces per indent level

    final codePoint = this.codePoint;
    if (codePoint != null) {
      final hex = _codePointLiteral(codePoint);
      return '$pad${_kotlinImage(indent, dataExpr, hex)}';
    }

    final buffer = StringBuffer();
    final access = dataType!.kotlinAccess(dataExpr);
    buffer.writeln('$pad$access?.let { codePoint ->');
    buffer.writeln('$pad    ${_kotlinImage(indent, dataExpr, 'codePoint')}');
    buffer.write('$pad}');
    return buffer.toString();
  }

  /// [codePoint] as the hexadecimal literal an icon is usually written as,
  /// which both platforms read the same way.
  static String _codePointLiteral(int codePoint) =>
      '0x${codePoint.toRadixString(16).toUpperCase()}';
}
