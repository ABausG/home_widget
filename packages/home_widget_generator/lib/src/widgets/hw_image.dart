part of 'hw_widget.dart';

/// Name of the Swift helper resolving a Flutter asset inside the containing
/// app's bundle, emitted once per generated file by [swiftFlutterAssetHelper].
const String swiftFlutterAssetFunction = 'flutterAssetPath';

/// Name of the Kotlin helper decoding a Flutter asset out of the APK, emitted
/// once per generated file by [kotlinFlutterAssetHelper].
const String kotlinFlutterAssetFunction = 'flutterAssetBitmap';

/// Name of the Kotlin helper decoding a saved image file, emitted once per
/// generated file by [kotlinImageFileHelper].
const String kotlinImageFileFunction = 'hwDecodeImageFile';

/// Name of the Swift helper decoding an image file at its display size,
/// emitted once per generated file by [swiftImageDecodeHelper].
const String swiftImageDecodeFunction = 'hwDecodeImage';

/// Fallback edge length in pixels for an [HWImage] that declares no size.
///
/// The Android counterpart falls back to the screen's shorter side, which no
/// widget exceeds. WidgetKit has no equivalent reading available inside an
/// extension, so a flat cap of the same order stands in for it.
const int swiftImageFallbackPixels = 1536;

/// Top-level Swift helper backing every [HWImage] in a generated file.
///
/// WidgetKit caps how much memory an extension may use while rendering, so a
/// full-resolution photo has to be downsampled rather than decoded whole. The
/// target is the image's declared size in pixels; one that sizes itself from
/// the layout falls back to [swiftImageFallbackPixels]. Mirrors
/// [kotlinImageSampleHelper], except that ImageIO scales to the exact bound
/// instead of a power-of-two step.
const String swiftImageDecodeHelper = '''
private func $swiftImageDecodeFunction(
  _ path: String, _ widthPt: Double?, _ heightPt: Double?
) -> UIImage? {
  guard
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
  else { return nil }
  let displayScale = UITraitCollection.current.displayScale
  let scale = displayScale > 0 ? displayScale : 3
  let fallback = CGFloat($swiftImageFallbackPixels)
  let targetWidth = widthPt.map { CGFloat(\$0) * scale } ?? fallback
  let targetHeight = heightPt.map { CGFloat(\$0) * scale } ?? fallback
  let maxPixelSize = Int(max(targetWidth, targetHeight).rounded())
  guard maxPixelSize > 0 else { return nil }
  let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceShouldCacheImmediately: true,
    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
  ]
  guard
    let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  else { return nil }
  return UIImage(cgImage: thumbnail, scale: scale, orientation: .up)
}''';

/// Name of the Kotlin helper computing a power-of-two `inSampleSize`, emitted
/// once per generated file by [kotlinImageSampleHelper].
const String kotlinImageSampleFunction = 'hwImageSampleSize';

/// Top-level Kotlin helper shared by every image decode in a generated file.
///
/// RemoteViews cap how much bitmap memory a widget may hand to the launcher, so
/// a full-resolution photo has to be subsampled before it is decoded. The target
/// is the image's declared size in pixels; an axis the widget declares no size
/// for follows the source's aspect ratio, or — with neither axis declared —
/// falls back to the screen's shorter side, which no widget exceeds.
const String kotlinImageSampleHelper = '''
private fun $kotlinImageSampleFunction(
    context: android.content.Context,
    bounds: BitmapFactory.Options,
    widthDp: Double?,
    heightDp: Double?,
): Int {
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return 1
    val metrics = context.resources.displayMetrics
    val fallback = minOf(metrics.widthPixels, metrics.heightPixels)
    val widthPx = widthDp?.let { (it * metrics.density).toInt() }
    val heightPx = heightDp?.let { (it * metrics.density).toInt() }
    val targetWidth = widthPx
        ?: heightPx?.let {
            (it.toLong() * bounds.outWidth / bounds.outHeight).toInt().coerceAtLeast(1)
        }
        ?: fallback
    val targetHeight = heightPx
        ?: widthPx?.let {
            (it.toLong() * bounds.outHeight / bounds.outWidth).toInt().coerceAtLeast(1)
        }
        ?: fallback
    if (targetWidth <= 0 || targetHeight <= 0) return 1
    var sampleSize = 1
    while (bounds.outWidth / (sampleSize * 2) >= targetWidth &&
        bounds.outHeight / (sampleSize * 2) >= targetHeight) {
        sampleSize *= 2
    }
    return sampleSize
}''';

/// Top-level Kotlin helper backing every runtime [HWImage] in a generated file.
const String kotlinImageFileHelper = '''
private fun $kotlinImageFileFunction(
    context: android.content.Context,
    path: String,
    widthDp: Double?,
    heightDp: Double?,
): android.graphics.Bitmap? = try {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        null
    } else {
        BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
                inSampleSize = $kotlinImageSampleFunction(context, bounds, widthDp, heightDp)
            },
        )
    }
} catch (_: Exception) {
    null
}''';

/// File-scope Swift helper backing every [HWImage.asset] in a generated file.
///
/// The widget extension is installed at `Runner.app/PlugIns/<name>.appex`, so
/// the containing app bundle — and with it `flutter_assets` — is two levels up
/// from the extension's own bundle.
const String swiftFlutterAssetHelper = '''
private func $swiftFlutterAssetFunction(_ asset: String) -> String? {
  let appBundleURL = Bundle.main.bundleURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let url = appBundleURL
    .appendingPathComponent("Frameworks/App.framework/flutter_assets")
    .appendingPathComponent(asset)
  return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
}''';

/// Top-level Kotlin helper backing every [HWImage.asset] in a generated file.
///
/// Flutter assets ship inside the APK under `assets/flutter_assets/`, which is
/// what the asset manager of the app context reads from.
const String kotlinFlutterAssetHelper = '''
private fun $kotlinFlutterAssetFunction(
    context: android.content.Context,
    asset: String,
    widthDp: Double?,
    heightDp: Double?,
): android.graphics.Bitmap? = try {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    context.assets.open("flutter_assets/\$asset").use {
        BitmapFactory.decodeStream(it, null, bounds)
    }
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        null
    } else {
        val options = BitmapFactory.Options().apply {
            inSampleSize = $kotlinImageSampleFunction(context, bounds, widthDp, heightDp)
        }
        context.assets.open("flutter_assets/\$asset").use {
            BitmapFactory.decodeStream(it, null, options)
        }
    }
} catch (_: Exception) {
    null
}''';

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
/// Two const constructors:
/// - `HWImage(HWImageData('avatar'))` -- runtime image, saved by the app
/// - `HWImage.asset('assets/logo.png')` -- Flutter asset, read from the bundle
class HWImage extends HWWidget implements HWDataWidget {
  /// The image data passed to the default constructor, null for
  /// [HWImage.asset].
  ///
  /// An [HWImageData], or an [HWJson] / [HWTimedData] (or both) wrapping one.
  /// Prefer [dataType], which is non-null for both constructors, or
  /// [imageData] for the [HWImageData] itself.
  final HWDataType<dynamic>? data;

  /// The Flutter asset path passed to [HWImage.asset], null otherwise.
  final String? assetPath;

  /// The `package` passed to [HWImage.asset], null for app assets.
  final String? assetPackage;

  /// Fixed width in logical pixels, or null to size from the layout.
  final double? width;

  /// Fixed height in logical pixels, or null to size from the layout.
  final double? height;

  /// How the image is inscribed into its bounds.
  final HWImageFit fit;

  /// Accessibility description of the image, or null for a decorative image.
  final String? semanticLabel;

  /// Renders the image stored under [image].
  ///
  /// [image] is an [HWImageData], optionally wrapped in an [HWJson] to read it
  /// from a JSON group and/or an [HWTimedData] to make it time-based.
  const HWImage(
    HWDataType<dynamic> image, {
    this.width,
    this.height,
    this.fit = HWImageFit.contain,
    this.semanticLabel,
  })  : data = image,
        assetPath = null,
        assetPackage = null;

  /// Renders the Flutter asset at [path].
  ///
  /// Set [package] to load the asset from a dependency instead of the app,
  /// exactly like `Image.asset(path, package: ...)`.
  ///
  /// Equivalent to `HWImage(HWImageData.asset(path, package: package))`.
  const HWImage.asset(
    String path, {
    String? package,
    this.width,
    this.height,
    this.fit = HWImageFit.contain,
    this.semanticLabel,
  })  : data = null,
        assetPath = path,
        assetPackage = package;

  /// The data field this widget renders, for either constructor.
  ///
  /// Keeps the [HWTimedData] and [HWJson] wrappers, so the field is registered
  /// as time-based / as part of its group and the access expressions come out
  /// right; [imageData] strips them.
  HWDataType<dynamic> get dataType =>
      data ?? HWImageData.asset(assetPath!, package: assetPackage);

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
  Set<HWDataType<dynamic>> get dataDependencies => {dataType};

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      'import android.graphics.BitmapFactory',
      'import androidx.glance.Image',
      'import androidx.glance.ImageProvider',
      'import androidx.glance.layout.ContentScale',
    };
    if (width != null || height != null) {
      imports.add('import androidx.compose.ui.unit.dp');
      imports.add('import androidx.glance.GlanceModifier');
    }
    if (width != null) {
      imports.add('import androidx.glance.layout.width');
    }
    if (height != null) {
      imports.add('import androidx.glance.layout.height');
    }
    return imports;
  }

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

    // HWImage.asset stores the raw path; the storage key is derived from it.
    final assetPath =
        WidgetValueDecoder.getField(obj, 'assetPath')?.toStringValue();
    if (assetPath != null) {
      return HWImage.asset(
        assetPath,
        package:
            WidgetValueDecoder.getField(obj, 'assetPackage')?.toStringValue(),
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
      );
    }

    final dataObj = WidgetValueDecoder.getField(obj, 'data');
    final data = WidgetValueDecoder.decodeDataType(dataObj);
    if (data != null && imageLeafOf(data) != null) {
      return HWImage(
        data,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
      );
    }

    throw GeneratorError(
      'Could not decode HWImage. HWImage requires an HWImageData, optionally '
      'wrapped in HWJson and/or HWTimedData, got: '
      '${dataObj?.type?.element?.name}',
    );
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final buffer = StringBuffer();

    final image = imageData;
    final pathExpr = image.isAsset
        ? '$swiftFlutterAssetFunction('
            '"${escapeSwiftStringLiteral(image.effectiveAssetKey!)}")'
        : dataType.swiftAccess(dataExpr);
    final sizeArgs = '${width ?? 'nil'}, ${height ?? 'nil'}';
    buffer.writeln(
      '${pad}if let path = $pathExpr, '
      'let uiImage = $swiftImageDecodeFunction(path, $sizeArgs) {',
    );
    buffer.writeln('$pad    Image(uiImage: uiImage)');
    buffer.writeln('$pad        .resizable()');

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
  String toKotlin(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final buffer = StringBuffer();

    final image = imageData;
    final sizeArgs = '${width ?? 'null'}, ${height ?? 'null'}';
    final String closePad;
    if (image.isAsset) {
      final asset = escapeKotlinStringLiteral(image.effectiveAssetKey!);
      buffer.writeln(
        '$pad$kotlinFlutterAssetFunction(context, "$asset", $sizeArgs)'
        '?.let { bitmap ->',
      );
      closePad = pad;
    } else {
      final access = dataType.kotlinAccess(dataExpr);
      buffer.writeln(
        '$pad$access?.let { path -> '
        '$kotlinImageFileFunction(context, path, $sizeArgs) }',
      );
      buffer.writeln('$pad    ?.let { bitmap ->');
      closePad = '$pad    ';
    }
    final bodyPad = '$closePad    ';
    buffer.writeln('${bodyPad}Image(');
    buffer.writeln('$bodyPad    provider = ImageProvider(bitmap),');

    final semanticLabel = this.semanticLabel;
    final description = semanticLabel == null
        ? 'null'
        : '"${escapeKotlinStringLiteral(semanticLabel)}"';
    buffer.writeln('$bodyPad    contentDescription = $description,');
    buffer.writeln('$bodyPad    contentScale = ${_kotlinContentScale()},');

    final modifiers = <String>[
      if (width != null) 'width($width.dp)',
      if (height != null) 'height($height.dp)',
    ];
    if (modifiers.isNotEmpty) {
      buffer.writeln(
        '$bodyPad    modifier = GlanceModifier.${modifiers.join('.')},',
      );
    }

    buffer.writeln('$bodyPad)');
    buffer.write('$closePad}');
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
