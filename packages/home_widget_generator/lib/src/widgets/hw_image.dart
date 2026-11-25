part of 'hw_widget.dart';

/// How an [HWImage] is inscribed into its layout bounds.
///
/// Maps to SwiftUI `aspectRatio(contentMode:)` and Glance `ContentScale`.
enum HWImageFit {
  /// Scales the image down to fit, preserving its aspect ratio.
  contain,

  /// Fills the bounds, preserving the aspect ratio and clipping the overflow.
  cover,

  /// Stretches the image to the bounds, ignoring its aspect ratio.
  fill,
}

/// How iOS renders an [HWImage] while the Home Screen is set to Tinted or
/// Clear, where the system tints the widget's content.
///
/// Maps to SwiftUI's `widgetAccentedRenderingMode(_:)`, which iOS 18 and later
/// apply; earlier versions and Android ignore it.
enum HWAccentedRendering {
  /// The image is drawn in the accent tint, the system default.
  accented,

  /// The image is drawn desaturated, in shades of gray.
  desaturated,

  /// The image is drawn desaturated and then tinted.
  accentedDesaturated,

  /// The image keeps its colors, for photos and artwork.
  fullColor,
}

/// An image widget for use in widgetBuilder.
///
/// A runtime image is supplied as an `ImageProvider` through the generated
/// `saveData(...)`. Nothing is rendered until one has been saved; combine with
/// `HWDataExists` to show a placeholder instead.
///
/// An asset image is read straight out of the installed app bundle at render
/// time, so it shows before the app has ever run and needs no stored data.
///
/// A runtime image may also be time-based —
/// `HWImage(HWTimedData(HWImageData('avatar')))` — in which case the app hands
/// one `ImageProvider` per timestamp to the generated
/// `saveData(timedData: ...)` and the widget swaps pictures on its own.
///
/// It may equally sit at the leaf of a JSON group —
/// `HWImage(HWJson('contact', HWImageData('avatar')))` — so a picture travels
/// with the rest of a record, and the two combine as
/// `HWTimedData(HWJson('contact', HWImageData('avatar')))`.
///
/// `HWImageData.asset` is rejected inside both wrappers by the home_widget_cli
/// validator at generation time: an asset ships with the app, so there is
/// nothing to store and nothing to vary.
///
/// Two kinds of image data:
/// - `HWImage(HWImageData('avatar'))` -- runtime image, saved by the app
/// - `HWImage(HWImageData.asset('assets/logo.png'))` -- Flutter asset, read
///   from the bundle
class HWImage extends HWWidget implements HWDataWidget {
  /// The image data this widget renders.
  ///
  /// An [HWImageData], or an [HWJson] / [HWTimedData] (or both) wrapping one;
  /// [imageData] is the [HWImageData] itself.
  final HWDataType<dynamic> data;

  /// Fixed width in logical pixels, or null to size from the layout.
  final double? width;

  /// Fixed height in logical pixels, or null to size from the layout.
  final double? height;

  /// How the image is inscribed into its bounds.
  final HWImageFit fit;

  /// Accessibility description of the image, or null for a decorative image.
  final String? semanticLabel;

  /// How iOS renders the image on a Home Screen set to Tinted or Clear, or
  /// null for the system default, which flattens it to the tint.
  final HWAccentedRendering? iosAccentedRendering;

  /// Whether the Glance `Image` fills the width of the `Box` around it.
  final bool _kotlinFillsWidth;

  /// Whether the Glance `Image` fills the height of the `Box` around it.
  final bool _kotlinFillsHeight;

  /// Renders the image stored under [image].
  ///
  /// [image] is an [HWImageData], optionally wrapped in an [HWJson] to read it
  /// from a JSON group or an [HWItemData] to read it from a list item, and/or
  /// an [HWTimedData] to make it time-based, or an [HWAppearanceData] picking
  /// one of several by the system appearance.
  const HWImage(
    HWDataType<dynamic> image, {
    this.width,
    this.height,
    this.fit = HWImageFit.contain,
    this.semanticLabel,
    this.iosAccentedRendering,
  })  : data = image,
        _kotlinFillsWidth = false,
        _kotlinFillsHeight = false;

  /// [image], its Glance `Image` filling the axes named.
  HWImage._kotlinFilling(
    HWImage image, {
    required bool width,
    required bool height,
  })  : data = image.data,
        width = image.width,
        height = image.height,
        fit = image.fit,
        semanticLabel = image.semanticLabel,
        iosAccentedRendering = image.iosAccentedRendering,
        _kotlinFillsWidth = width,
        _kotlinFillsHeight = height;

  /// The data field this widget renders.
  ///
  /// Keeps the [HWTimedData] and [HWJson] wrappers, so the field is registered
  /// as time-based / as part of its group and the access expressions come out
  /// right; [imageData] strips them.
  HWDataType<dynamic> get dataType => data;

  /// The image itself, with any [HWTimedData] and [HWJson] wrappers removed.
  ///
  /// Throws a [GeneratorError] when the widget was handed something other than
  /// an [HWImageData], which only a hand-built tree can do — the decoder
  /// rejects it earlier.
  HWImageData get imageData {
    final image = imageLeafOf(dataType);
    if (image != null) return image;
    throw GeneratorError(
      'HWImage requires an HWImageData, got: ${dataType.runtimeType}.',
    );
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies =>
      _dataDependenciesOf([dataType]);

  @override
  Iterable<HWDataType<dynamic>> get ownValues => [dataType];

  @override
  Set<String> get swiftViewModifiers => dataType.swiftViewModifiers;

  /// A picture sits in the middle of a box larger than it is, which is what
  /// Flutter's `Image` and Glance's `fitCenter` do with it.
  @override
  String get swiftFrameAlignment => '.center';

  @override
  Set<HWNativeHelper> get renderHelpers => {
        HWNativeHelper.hwDecodeImage,
        if (iosAccentedRendering != null) HWNativeHelper.hwAccentedRendering,
        if (_kotlinPairs) ...HWAppearanceChoice.kotlinImageHelpers,
      };

  /// Whether Android hands the launcher the bitmaps of both appearances, for
  /// an [HWAppearanceData] of images.
  bool get _kotlinPairs => dataType is HWAppearanceData;

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      if (_kotlinPairs) ...{
        ...HWAppearanceChoice.kotlinPairImports,
        'import androidx.glance.GlanceModifier',
      } else ...{
        'import androidx.glance.Image',
        'import androidx.glance.ImageProvider',
      },
      'import androidx.glance.layout.ContentScale',
    };
    final modifiers = _kotlinModifiers;
    if (modifiers.isNotEmpty) {
      imports.add('import androidx.glance.GlanceModifier');
    }
    for (final modifier in modifiers) {
      imports.addAll(HWSizedBox._kotlinModifierImports(modifier));
    }
    return imports;
  }

  /// The Glance modifiers sizing the `Image`: its own size along an axis that
  /// has one, a fill along an open axis asked to.
  List<String> get _kotlinModifiers {
    if (_kotlinFillsWidth && _kotlinFillsHeight) return const ['fillMaxSize()'];
    return [
      if (width != null)
        'width($width.dp)'
      else if (_kotlinFillsWidth)
        'fillMaxWidth()',
      if (height != null)
        'height($height.dp)'
      else if (_kotlinFillsHeight)
        'fillMaxHeight()',
    ];
  }

  /// A picture fills each axis it leaves open, the way SwiftUI resizes it to
  /// the frame of the box; an axis it sizes itself stays as it is.
  @override
  HWWidget? _kotlinFilling({required bool width, required bool height}) {
    final fillsWidth = (width || _kotlinFillsWidth) && this.width == null;
    final fillsHeight = (height || _kotlinFillsHeight) && this.height == null;
    if (fillsWidth == _kotlinFillsWidth && fillsHeight == _kotlinFillsHeight) {
      return null;
    }
    return HWImage._kotlinFilling(this, width: fillsWidth, height: fillsHeight);
  }

  /// Only on Glance, as [_kotlinFilling]: SwiftUI's frame already resizes the
  /// picture.
  @override
  HWWidget? _sizedInside(
    double? width,
    double? height, {
    required bool glance,
  }) =>
      glance
          ? _kotlinFilling(width: width != null, height: height != null)
          : null;

  /// Decodes an [HWImage] from an analyzer constant.
  static HWImage fromDartObject(DartObject obj) {
    final width = WidgetValueDecoder.getField(obj, 'width')?.toDoubleValue();
    final height = WidgetValueDecoder.getField(obj, 'height')?.toDoubleValue();
    final fit = WidgetValueDecoder.decodeEnum(
          WidgetValueDecoder.getField(obj, 'fit'),
          HWImageFit.values,
        ) ??
        HWImageFit.contain;
    final semanticLabel =
        WidgetValueDecoder.getField(obj, 'semanticLabel')?.toStringValue();
    final iosAccentedRendering = WidgetValueDecoder.decodeEnum(
      WidgetValueDecoder.getField(obj, 'iosAccentedRendering'),
      HWAccentedRendering.values,
    );

    final dataObj = WidgetValueDecoder.getField(obj, 'data');
    final data = WidgetValueDecoder.decodeDataType(dataObj);
    if (data != null && imageLeafOf(data) != null) {
      return HWImage(
        data,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        iosAccentedRendering: iosAccentedRendering,
      );
    }

    throw GeneratorError(
      'Could not decode HWImage. HWImage requires an HWImageData, optionally '
      'wrapped in HWJson or HWItemData and/or HWTimedData, or an '
      'HWAppearanceData of them, got: ${dataObj?.type?.element?.name}',
    );
  }

  /// The Swift `UIImage?` the image of [side] decodes to.
  String _swiftSideImage(HWDataType<dynamic> side, String dataExpr) {
    final sizeArgs = '${width ?? 'nil'}, ${height ?? 'nil'}';
    final decode = HWNativeHelper.hwDecodeImage.name;
    final image = imageLeafOf(side)!;
    final path = side.swiftVariantValue(dataExpr);
    if (image.isAsset) return '$decode($path, $sizeArgs)';
    return '$path.flatMap { $decode(\$0, $sizeArgs) }';
  }

  /// The Kotlin `Bitmap?` the image of [side] decodes to.
  String _kotlinSideBitmap(HWDataType<dynamic> side, String dataExpr) {
    final sizeArgs = '${width ?? 'null'}, ${height ?? 'null'}';
    final decode = HWNativeHelper.hwDecodeImage.name;
    final image = imageLeafOf(side)!;
    final path = side.kotlinVariantValue(dataExpr);
    if (image.isAsset) return '$decode(context, $path, $sizeArgs)';
    return '$path?.let { path -> $decode(context, path, $sizeArgs) }';
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final buffer = StringBuffer();

    final image = imageData;
    final sizeArgs = '${width ?? 'nil'}, ${height ?? 'nil'}';
    final decode = HWNativeHelper.hwDecodeImage.name;
    final data = dataType;
    if (data is HWAppearanceData) {
      final picked = data.swiftPick((side) => _swiftSideImage(side, dataExpr));
      buffer.writeln('${pad}if let uiImage = $picked {');
    } else if (image.isAsset) {
      final asset = escapeSwiftStringLiteral(image.effectiveAssetKey!);
      buffer.writeln(
        '${pad}if let uiImage = $decode("$asset", $sizeArgs) {',
      );
    } else {
      final access = dataType.swiftAccess(dataExpr);
      buffer.writeln(
        '${pad}if let path = $access, '
        'let uiImage = $decode(path, $sizeArgs) {',
      );
    }
    if (iosAccentedRendering case final rendering?) {
      buffer.writeln(
        '$pad    ${HWNativeHelper.hwAccentedRendering.name}('
        'Image(uiImage: uiImage).resizable(), "${rendering.name}")',
      );
    } else {
      buffer.writeln('$pad    Image(uiImage: uiImage)');
      buffer.writeln('$pad        .resizable()');
    }

    switch (fit) {
      case HWImageFit.contain:
        buffer.writeln('$pad        .aspectRatio(contentMode: .fit)');
      case HWImageFit.cover:
        buffer.writeln('$pad        .aspectRatio(contentMode: .fill)');
      case HWImageFit.fill:
        break;
    }

    final frameArgs = <String>[
      if (width != null) 'width: $width',
      if (height != null) 'height: $height',
    ];
    if (frameArgs.isNotEmpty) {
      buffer.writeln('$pad        .frame(${frameArgs.join(', ')})');
    }

    // `clipped()` trims to the bounds it is applied in, so it only removes the
    // overflow of a `.fill` aspect ratio once the frame has been set.
    if (fit == HWImageFit.cover) {
      buffer.writeln('$pad        .clipped()');
    }

    final semanticLabel = this.semanticLabel;
    if (semanticLabel != null) {
      buffer.writeln(
        '$pad        .accessibilityLabel'
        '("${escapeSwiftStringLiteral(semanticLabel)}")',
      );
    }

    buffer.write('$pad}');
    return buffer.toString();
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) =>
      _kotlinDecoded(indent, dataExpr, _kotlinPicture);

  /// Nothing is drawn until a bitmap is decoded, so a stack lays out the
  /// `Image` inside the check, and leaves no gap or `Box` behind without one.
  @override
  String _kotlinInStack(
    int indent, {
    required String dataExpr,
    required HWEmitContext context,
    required _HWKotlinStackSlot slot,
  }) =>
      _kotlinDecoded(
        indent,
        dataExpr,
        (pictureIndent) => slot.lay(
          pictureIndent,
          context: context,
          emit: (indent, _) => _kotlinPicture(indent),
          reportsBaseline: false,
          paddingAddsRoom: _kotlinPictureTakesPadding,
          room: const HWKotlinRoom(),
        ),
      );

  @override
  Set<String> _kotlinImportsInStack(_HWKotlinStackSlot slot) => slot.imports(
        importsIn: kotlinImportsIn,
        reportsBaseline: false,
        paddingAddsRoom: _kotlinPictureTakesPadding,
        room: const HWKotlinRoom(),
      );

  /// Whether a padding put on the `Image` itself adds room around it, rather
  /// than being taken out of a fixed width or height.
  bool get _kotlinPictureTakesPadding => width == null && height == null;

  /// The Glance code decoding the picture and drawing it once there is one:
  /// the `Image` [picture] writes at the indent it is handed, showing `bitmap`.
  String _kotlinDecoded(
    int indent,
    String dataExpr,
    String Function(int indent) picture,
  ) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final buffer = StringBuffer();

    final image = imageData;
    final sizeArgs = '${width ?? 'null'}, ${height ?? 'null'}';
    final decode = HWNativeHelper.hwDecodeImage.name;
    final data = dataType;
    final int pictureIndent;
    if (data is HWAppearanceData) {
      final pair = HWAppearanceChoice.kotlinPair(
        light: _kotlinSideBitmap(data.light, dataExpr),
        dark: _kotlinSideBitmap(data.dark, dataExpr),
      );
      buffer.writeln('$pad$pair?.let { bitmaps ->');
      pictureIndent = indent + 1;
    } else if (image.isAsset) {
      final asset = escapeKotlinStringLiteral(image.effectiveAssetKey!);
      buffer.writeln(
        '$pad$decode(context, "$asset", $sizeArgs)'
        '?.let { bitmap ->',
      );
      pictureIndent = indent + 1;
    } else {
      final access = dataType.kotlinAccess(dataExpr);
      buffer.writeln(
        '$pad$access?.let { path -> '
        '$decode(context, path, $sizeArgs) }',
      );
      buffer.writeln('$pad    ?.let { bitmap ->');
      pictureIndent = indent + 2;
    }
    buffer.writeln(picture(pictureIndent));
    buffer.write('${'    ' * (pictureIndent - 1)}}');
    return buffer.toString();
  }

  /// The Glance `Image` showing the decoded `bitmap`, [indent] levels deep, or
  /// the pair of the decoded `bitmaps` of either appearance.
  String _kotlinPicture(int indent) {
    final pad = '    ' * indent;
    final semanticLabel = this.semanticLabel;
    final description = semanticLabel == null
        ? 'null'
        : '"${escapeKotlinStringLiteral(semanticLabel)}"';
    final modifiers = _kotlinModifiers;

    if (_kotlinPairs) {
      final modifier = modifiers.map((m) => '.$m').join();
      return '''
$pad${HWNativeHelper.hwAppearanceImage.kotlinName}(
$pad    modifier = GlanceModifier$modifier,
$pad    size = GlanceModifier$modifier,
$pad    context = context,
$pad    images = bitmaps,
$pad    contentDescription = $description,
$pad    contentScale = ${_kotlinContentScale()},
$pad)''';
    }

    final buffer = StringBuffer();
    buffer.writeln('${pad}Image(');
    buffer.writeln('$pad    provider = ImageProvider(bitmap),');
    buffer.writeln('$pad    contentDescription = $description,');
    buffer.writeln('$pad    contentScale = ${_kotlinContentScale()},');

    if (modifiers.isNotEmpty) {
      buffer.writeln(
        '$pad    modifier = GlanceModifier.${modifiers.join('.')},',
      );
    }

    buffer.write('$pad)');
    return buffer.toString();
  }

  String _kotlinContentScale() {
    switch (fit) {
      case HWImageFit.contain:
        return 'ContentScale.Fit';
      case HWImageFit.cover:
        return 'ContentScale.Crop';
      case HWImageFit.fill:
        return 'ContentScale.FillBounds';
    }
  }
}
