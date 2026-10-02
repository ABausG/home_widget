part of 'hw_widget.dart';

/// An icon widget for use in widgetBuilder.
///
/// Icons render as a glyph of their own font, which is copied next to the
/// generated widget and subset down to the glyphs the schema names — Flutter
/// tree-shakes icon fonts out of `flutter_assets`, so there is nothing to read
/// in place the way an asset image is.
///
/// Const constructors:
/// - `HWIcon(HWIconData.fixed(Icons.favorite))` -- one hardcoded icon
/// - `HWIcon(HWIconData('mood', icons: [...]))` -- one of a fixed set, chosen
///   by the app at runtime
/// - `HWIcon.glyph(0xe87d, font: ...)` -- one hardcoded glyph, named without a
///   Flutter `IconData`
///
/// The data form takes an [HWIconData], optionally wrapped in an [HWJson] or
/// an [HWItemData] and/or an [HWTimedData], exactly like [HWImage]. Nothing is
/// rendered while there is no stored value and the field declares no default.
class HWIcon extends HWWidget implements HWDataWidget {
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

  /// The icon data passed to the default constructor, null for
  /// [HWIcon.glyph].
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
  /// from a JSON group or an [HWItemData] to read it from a list item, and/or
  /// an [HWTimedData] to make it time-based.
  const HWIcon(
    HWDataType<dynamic> icon, {
    this.size = 24,
    this.color,
    this.semanticLabel,
  })  : data = icon,
        codePoint = null,
        font = null,
        matchTextDirection = false,
        fontResourcePrefix = null;

  /// Renders [codePoint] out of [font].
  ///
  /// What an [HWIconData.fixed] decodes to, and the way to name a glyph
  /// without a Flutter `IconData` to point at.
  const HWIcon.glyph(
    int this.codePoint, {
    required HWIconFont this.font,
    this.size = 24,
    this.color,
    this.semanticLabel,
    this.matchTextDirection = false,
  })  : data = null,
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
  }) : data = null;

  /// The icon data this widget renders, or null for [HWIcon.glyph].
  ///
  /// Keeps the [HWTimedData] and [HWJson] wrappers, so the field is registered
  /// as time-based / as part of its group and the access expressions come out
  /// right; [iconData] strips them.
  HWDataType<dynamic>? get dataType => data;

  /// The icon field itself, with any [HWTimedData] and [HWJson] wrappers
  /// removed, or null for [HWIcon.glyph].
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

  /// What an [HWIcon] that never went through the decoder fails with, where
  /// the icon is still the raw Flutter constant the annotation wrote.
  static const String _undecodedMessage =
      'The font of this HWIcon is unknown. An icon has to be declared in a '
      '@HomeWidget annotation, or built with HWIcon.glyph.';

  /// The font this icon is drawn out of.
  ///
  /// Throws a [GeneratorError] on a tree that was never decoded from a schema,
  /// where the icon is still the raw Flutter constant the annotation wrote.
  HWIconFont get iconFont {
    final resolved = font ?? iconData?.iconFont;
    if (resolved != null) return resolved;
    throw GeneratorError(_undecodedMessage);
  }

  /// The [HWIconData.fixed] this widget was handed directly, or null.
  HWIconData? get _fixedData {
    final data = this.data;
    return data is HWIconData && data.isFixed ? data : null;
  }

  /// The glyph a constant icon renders, whether it was named as one or handed
  /// over as a decoded [HWIconData.fixed]; null for the data form.
  int? get _glyph => codePoint ?? _fixedData?.fixedCodePoint;

  /// Whether a constant icon mirrors in a right-to-left layout.
  bool get _mirrors =>
      matchTextDirection || (_fixedData?.fixedMatchTextDirection ?? false);

  /// The icon field a glyphless icon renders, which only the stored form has.
  ///
  /// Throws the [GeneratorError] [iconFont] throws for a fixed icon the decoder
  /// never saw, which has no glyph yet and no field either.
  HWDataType<dynamic> get _boundDataType {
    final data = dataType;
    if (data != null && _fixedData == null) return data;
    throw GeneratorError(_undecodedMessage);
  }

  /// The color the glyph is tinted in: [color], or the platform's primary
  /// content color.
  HWColor get effectiveColor =>
      color ?? const HWDefaultColor(HWColorRole.contentPrimary);

  @override
  Set<HWDataType<dynamic>> get dataDependencies =>
      _dataDependenciesOf([if (data case final data?) data]);

  /// Empty for a fixed icon that never went through the decoder, whose glyph
  /// and font are not known yet.
  @override
  Map<HWIconFont, Set<int>> get ownIconCodePoints {
    final codePoint = _glyph;
    if (codePoint != null) {
      return {
        iconFont: {codePoint},
      };
    }
    final data = iconData;
    return data == null || data.isFixed
        ? const {}
        : {iconFont: data.codePoints};
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

  /// A glyph sits in the middle of a box larger than it is, which is what
  /// Flutter's `Icon` and Glance's `fitCenter` do with it.
  @override
  String get swiftFrameAlignment => '.center';

  /// Never: a padding would be taken out of the fixed size the glyph is drawn
  /// at.
  @override
  bool get kotlinPaddingAddsRoom => false;

  /// Decodes an [HWIcon] from an analyzer constant.
  static HWIcon fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final size =
        WidgetValueDecoder.getField(obj, 'size')?.toDoubleValue() ?? 24;
    final colorObj = WidgetValueDecoder.getField(obj, 'color');
    final color = WidgetValueDecoder.decodeColor(colorObj);
    final semanticLabel =
        WidgetValueDecoder.getField(obj, 'semanticLabel')?.toStringValue();
    final fontResourcePrefix = decoder.fontResourcePrefix;

    final glyph = WidgetValueDecoder.getField(obj, 'codePoint')?.toIntValue();
    if (glyph != null) {
      final fontObj = WidgetValueDecoder.getField(obj, 'font');
      final font = WidgetValueDecoder.decodeIconFontDeclaration(fontObj);
      if (font == null) {
        throw GeneratorError(
          'Could not decode HWIcon.glyph. Its font has to be an HWIconFont '
          'naming a family, got: ${fontObj?.type?.element?.name}',
        );
      }
      hwValidateCodePoint(glyph, 'This HWIcon');
      return HWIcon.resolvedGlyph(
        glyph,
        font: font,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        fontResourcePrefix: fontResourcePrefix,
        matchTextDirection:
            WidgetValueDecoder.decodeIconMatchTextDirection(obj),
      );
    }

    final dataObj = WidgetValueDecoder.getField(obj, 'data');
    final data = WidgetValueDecoder.decodeDataType(
      dataObj,
      defaultLocale: decoder.defaultLocale,
      resourcePrefix: decoder.resourcePrefix,
    );
    if (data is HWIconData && data.isFixed) {
      final codePoint = data.fixedCodePoint!;
      hwValidateCodePoint(codePoint, 'This HWIcon');
      return HWIcon.resolvedGlyph(
        codePoint,
        font: data.iconFont!,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        fontResourcePrefix: fontResourcePrefix,
        matchTextDirection: data.fixedMatchTextDirection,
      );
    }
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
      'wrapped in HWJson or HWItemData and/or HWTimedData, got: '
      '${dataObj?.type?.element?.name}',
    );
  }

  /// The SwiftUI modifiers every glyph carries, whatever it is rendered from.
  ///
  /// The frame makes the glyph the `size` by `size` box Flutter's `Icon` is and
  /// Android's `GlanceModifier.size` gives it, rather than whatever advance and
  /// line height the font happens to declare.
  List<String> _swiftGlyphModifiers(int indent, String dataExpr) {
    final font = '${HWNativeHelper.hwBundledFont.name}'
        '("${iconFont.iosResourceName}", size: ${hwSizeLiteral(size)})';
    final semanticLabel = this.semanticLabel;
    final mirror = _swiftMirrorCondition;
    final box = hwSizeLiteral(size);
    return [
      '.font($font)',
      '.frame(width: $box, height: $box)',
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
    if (_mirrors) return rightToLeft;
    if (_glyph != null) return null;
    return '$rightToLeft && hwMirroredIcons.contains(codePoint)';
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final buffer = StringBuffer();

    final codePoint = _glyph;
    final String bodyPad;
    if (codePoint == null) {
      final access = _boundDataType.swiftAccess(dataExpr);
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
    if (_mirrors) return ', matchTextDirection = true';
    if (_glyph != null) return '';
    return ', matchTextDirection = codePoint in hwMirroredIcons';
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent; // Use 4 spaces per indent level

    final codePoint = _glyph;
    if (codePoint != null) {
      final hex = _codePointLiteral(codePoint);
      return '$pad${_kotlinImage(indent, dataExpr, hex)}';
    }

    return _kotlinSavedGlyph(
      indent,
      dataExpr,
      (glyphIndent) =>
          '${'    ' * glyphIndent}${_kotlinImage(indent, dataExpr, 'codePoint')}',
    );
  }

  /// The data form draws nothing without a stored icon, so a stack lays out
  /// the glyph inside the check, and leaves no gap or `Box` behind without
  /// one.
  @override
  String _kotlinInStack(
    int indent, {
    required String dataExpr,
    required HWEmitContext context,
    required _HWKotlinStackSlot slot,
  }) {
    if (_glyph != null) {
      return super._kotlinInStack(
        indent,
        dataExpr: dataExpr,
        context: context,
        slot: slot,
      );
    }
    return _kotlinSavedGlyph(
      indent,
      dataExpr,
      (glyphIndent) => slot.lay(
        glyphIndent,
        context: context,
        emit: (imageIndent, _) =>
            '${'    ' * imageIndent}${_kotlinImage(indent, dataExpr, 'codePoint')}',
        reportsBaseline: kotlinReportsBaseline,
        paddingAddsRoom: kotlinPaddingAddsRoom,
        room: kotlinRoomIn(slot.axis),
      ),
    );
  }

  /// The data form's Glance code: the glyph [glyph] writes at the indent it is
  /// handed, drawing `codePoint`, only while there is a stored one.
  String _kotlinSavedGlyph(
    int indent,
    String dataExpr,
    String Function(int indent) glyph,
  ) {
    final pad = '    ' * indent;
    final access = _boundDataType.kotlinAccess(dataExpr);
    return '''
$pad$access?.let { codePoint ->
${glyph(indent + 1)}
$pad}''';
  }

  /// [codePoint] as the hexadecimal literal an icon is usually written as,
  /// which both platforms read the same way, once it is a glyph at all.
  static String _codePointLiteral(int codePoint) {
    hwValidateCodePoint(codePoint, 'This HWIcon');
    return hwCodePointLiteral(codePoint);
  }
}
