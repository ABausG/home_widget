import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';
import 'package:home_widget_generator/src/utils/apply_swift_modifier.dart';
import 'package:home_widget_generator/src/utils/inject_glance_modifier.dart';
import 'package:test/test.dart';

void main() {
  group('HWImage', () {
    group('model', () {
      test('data constructor keeps the runtime image', () {
        const image = HWImage(HWImageData('avatar'));
        expect(image.imageData.key, 'avatar');
        expect(image.imageData.isAsset, isFalse);
      });

      test('asset constructor derives the key', () {
        const image = HWImage.asset('assets/images/logo.png');
        expect(image.imageData.key, 'assetsImagesLogoPng');
        expect(image.imageData.isAsset, isTrue);
        expect(image.imageData.assetPath, 'assets/images/logo.png');
      });

      test('asset constructor forwards the package to the data type', () {
        const image = HWImage.asset('assets/logo.png', package: 'my_icons');
        expect(image.assetPackage, 'my_icons');
        expect(image.imageData.package, 'my_icons');
        expect(image.imageData.assetPath, 'assets/logo.png');
        expect(
          image.imageData.effectiveAssetKey,
          'packages/my_icons/assets/logo.png',
        );
        expect(image.imageData.key, 'packagesMyIconsAssetsLogoPng');
        expect(image.dataDependencies, {
          const HWImageData.asset('assets/logo.png', package: 'my_icons'),
        });
      });

      test('assetPackage is null for the data constructor', () {
        expect(const HWImage(HWImageData('avatar')).assetPackage, isNull);
        expect(const HWImage.asset('assets/logo.png').assetPackage, isNull);
      });

      test('package assets read the prefixed bundle path', () {
        const image = HWImage.asset('assets/logo.png', package: 'my_icons');
        expect(
          image.toSwift(0, dataExpr: 'data'),
          contains('flutterAssetPath("packages/my_icons/assets/logo.png")'),
        );
        expect(
          image.toKotlin(0, dataExpr: 'data'),
          contains(
            'flutterAssetBitmap(context, '
            '"packages/my_icons/assets/logo.png", null, null)',
          ),
        );
      });

      test('asset constructor equals the explicit data constructor', () {
        const asset = HWImage.asset('assets/logo.png');
        const explicit = HWImage(HWImageData.asset('assets/logo.png'));
        expect(asset.dataType, explicit.dataType);
      });

      test('defaults', () {
        const image = HWImage(HWImageData('avatar'));
        expect(image.width, isNull);
        expect(image.height, isNull);
        expect(image.fit, HWImageFit.contain);
        expect(image.semanticLabel, isNull);
      });

      test('dataDependencies contains the image data', () {
        const image = HWImage(HWImageData('avatar'));
        expect(image.dataDependencies, {const HWImageData('avatar')});
      });

      test('dataDependencies for an asset uses the derived key', () {
        const image = HWImage.asset('assets/logo.png');
        expect(image.dataDependencies.single.key, 'assetsLogoPng');
      });

      test('accepts a timed image and keeps the wrapper as the dependency', () {
        const image = HWImage(HWTimedData(HWImageData('slide')));
        expect(image.imageData, const HWImageData('slide'));
        expect(image.dataType, isA<HWTimedData<dynamic>>());
        expect(
          image.dataDependencies,
          {const HWTimedData(HWImageData('slide'))},
        );
      });

      test('accepts a JSON leaf image and keeps the group as the dependency',
          () {
        const image = HWImage(HWJson('contact', HWImageData('avatar')));
        expect(image.imageData, const HWImageData('avatar'));
        expect(image.dataDependencies, {
          const HWJson('contact', HWImageData('avatar')),
        });
      });

      test('accepts a timed JSON leaf image', () {
        const image =
            HWImage(HWTimedData(HWJson('slot', HWImageData('picture'))));
        expect(image.imageData, const HWImageData('picture'));
      });

      test('imageData rejects data that is not an image', () {
        const image = HWImage(HWString('label'));
        expect(() => image.imageData, throwsA(isA<GeneratorError>()));
        const jsonText = HWImage(HWJson('contact', HWString('name')));
        expect(() => jsonText.imageData, throwsA(isA<GeneratorError>()));
      });
    });

    group('iOS (SwiftUI)', () {
      test('emits a guarded UIImage load for runtime data', () {
        const node = HWImage(HWImageData('avatar'));
        expect(
          node.toSwift(0, dataExpr: 'data'),
          'if let path = data.avatar, let uiImage = hwDecodeImage(path, nil, nil) {\n'
          '    Image(uiImage: uiImage)\n'
          '        .resizable()\n'
          '        .aspectRatio(contentMode: .fit)\n'
          '}',
        );
      });

      test('reads an asset image from the app bundle', () {
        const node = HWImage.asset('assets/logo.png');
        expect(
          node.toSwift(0, dataExpr: 'entry.widgetData'),
          contains('if let path = flutterAssetPath("assets/logo.png"),'),
        );
      });

      test('fit cover clips after the frame so the overflow is cut', () {
        const node = HWImage(
          HWImageData('a'),
          width: 40,
          height: 40,
          fit: HWImageFit.cover,
        );
        expect(
          node.toSwift(0, dataExpr: 'data'),
          contains(
            '        .aspectRatio(contentMode: .fill)\n'
            '        .frame(width: 40.0, height: 40.0)\n'
            '        .clipped()\n',
          ),
        );
      });

      test('fit fill is resizable only', () {
        const node = HWImage(HWImageData('a'), fit: HWImageFit.fill);
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.resizable()'));
        expect(result, isNot(contains('.aspectRatio')));
        expect(result, isNot(contains('.clipped()')));
      });

      test('emits frame only when width or height is set', () {
        expect(
          const HWImage(HWImageData('a'), width: 100)
              .toSwift(0, dataExpr: 'data'),
          contains('.frame(width: 100.0)'),
        );
        expect(
          const HWImage(HWImageData('a'), height: 50)
              .toSwift(0, dataExpr: 'data'),
          contains('.frame(height: 50.0)'),
        );
        expect(
          const HWImage(HWImageData('a'), width: 100, height: 50)
              .toSwift(0, dataExpr: 'data'),
          contains('.frame(width: 100.0, height: 50.0)'),
        );
        expect(
          const HWImage(HWImageData('a')).toSwift(0, dataExpr: 'data'),
          isNot(contains('.frame(')),
        );
      });

      test('emits and escapes the accessibility label', () {
        const node = HWImage(
          HWImageData('a'),
          semanticLabel: 'A "nice" photo',
        );
        expect(
          node.toSwift(0, dataExpr: 'data'),
          contains(r'.accessibilityLabel("A \"nice\" photo")'),
        );
      });

      test('escapes control characters in the accessibility label', () {
        const node = HWImage(
          HWImageData('a'),
          semanticLabel: 'Line one\nLine\ttwo',
        );
        expect(
          node.toSwift(0, dataExpr: 'data'),
          contains(r'.accessibilityLabel("Line one\nLine\ttwo")'),
        );
      });

      test('omits the accessibility label when null', () {
        const node = HWImage(HWImageData('a'));
        expect(
          node.toSwift(0, dataExpr: 'data'),
          isNot(contains('.accessibilityLabel')),
        );
      });

      test('passes the declared size to the decode helper', () {
        const node = HWImage(HWImageData('a'), width: 64, height: 32);
        expect(
          node.toSwift(0, dataExpr: 'data'),
          contains('hwDecodeImage(path, 64.0, 32.0)'),
        );
      });

      test('respects indent', () {
        const node = HWImage(HWImageData('avatar'));
        expect(
          node.toSwift(2, dataExpr: 'data'),
          '        if let path = data.avatar, let uiImage = hwDecodeImage(path, nil, nil) {\n'
          '            Image(uiImage: uiImage)\n'
          '                .resizable()\n'
          '                .aspectRatio(contentMode: .fit)\n'
          '        }',
        );
      });

      test('a timed image reads the same field as an untimed one', () {
        const node = HWImage(HWTimedData(HWImageData('slide')));
        expect(
          node.toSwift(0, dataExpr: 'data'),
          const HWImage(HWImageData('slide')).toSwift(0, dataExpr: 'data'),
        );
      });

      test('a JSON leaf image reads through the group', () {
        const node = HWImage(HWJson('contact', HWImageData('avatar')));
        expect(
          node.toSwift(0, dataExpr: 'data'),
          contains(
            'if let path = data.contact?.avatar, '
            'let uiImage = hwDecodeImage(path, nil, nil) {',
          ),
        );
      });

      test('swiftViewModifiers is empty', () {
        expect(const HWImage(HWImageData('a')).swiftViewModifiers, isEmpty);
      });

      test('applySwiftModifier wraps the conditional in a Group', () {
        const node = HWImage(HWImageData('a'));
        final wrapped = applySwiftModifier(
          node.toSwift(0, dataExpr: 'data'),
          '.padding(8.0)',
          0,
        );
        expect(wrapped, startsWith('Group {\n'));
        expect(wrapped, endsWith('\n}\n.padding(8.0)'));
      });
    });

    group('Android (Glance)', () {
      test('emits a subsampled bitmap decode for runtime data', () {
        const node = HWImage(HWImageData('avatar'));
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          'data.avatar?.let { path -> '
          'hwDecodeImageFile(context, path, null, null) }\n'
          '    ?.let { bitmap ->\n'
          '        Image(\n'
          '            provider = ImageProvider(bitmap),\n'
          '            contentDescription = null,\n'
          '            contentScale = ContentScale.Fit,\n'
          '        )\n'
          '    }',
        );
      });

      test('reads an asset image from the APK', () {
        const node = HWImage.asset('assets/logo.png');
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          startsWith(
            'flutterAssetBitmap(context, "assets/logo.png", null, null)'
            '?.let { bitmap ->',
          ),
        );
      });

      test('maps fit onto ContentScale', () {
        expect(
          const HWImage(HWImageData('a'), fit: HWImageFit.contain)
              .toKotlin(0, dataExpr: 'data'),
          contains('contentScale = ContentScale.Fit,'),
        );
        expect(
          const HWImage(HWImageData('a'), fit: HWImageFit.cover)
              .toKotlin(0, dataExpr: 'data'),
          contains('contentScale = ContentScale.Crop,'),
        );
        expect(
          const HWImage(HWImageData('a'), fit: HWImageFit.fill)
              .toKotlin(0, dataExpr: 'data'),
          contains('contentScale = ContentScale.FillBounds,'),
        );
      });

      test('emits a size modifier only when width or height is set', () {
        expect(
          const HWImage(HWImageData('a'), width: 100)
              .toKotlin(0, dataExpr: 'data'),
          contains('modifier = GlanceModifier.width(100.0.dp),'),
        );
        expect(
          const HWImage(HWImageData('a'), height: 50)
              .toKotlin(0, dataExpr: 'data'),
          contains('modifier = GlanceModifier.height(50.0.dp),'),
        );
        expect(
          const HWImage(HWImageData('a'), width: 100, height: 50)
              .toKotlin(0, dataExpr: 'data'),
          contains(
            'modifier = GlanceModifier.width(100.0.dp).height(50.0.dp),',
          ),
        );
        expect(
          const HWImage(HWImageData('a')).toKotlin(0, dataExpr: 'data'),
          isNot(contains('modifier =')),
        );
      });

      test('passes the declared size to the decode helper', () {
        expect(
          const HWImage(HWImageData('a'), width: 100, height: 50)
              .toKotlin(0, dataExpr: 'data'),
          startsWith(
            'data.a?.let { path -> '
            'hwDecodeImageFile(context, path, 100.0, 50.0) }',
          ),
        );
        expect(
          const HWImage.asset('assets/logo.png', width: 24)
              .toKotlin(0, dataExpr: 'data'),
          startsWith(
            'flutterAssetBitmap(context, "assets/logo.png", 24.0, null)',
          ),
        );
      });

      test('emits and escapes the content description', () {
        const node = HWImage(
          HWImageData('a'),
          semanticLabel: r'Cost: $5 "each"',
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(r'contentDescription = "Cost: \$5 \"each\"",'),
        );
      });

      test('escapes control characters in the content description', () {
        const node = HWImage(
          HWImageData('a'),
          semanticLabel: 'Line one\nLine\ttwo',
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(r'contentDescription = "Line one\nLine\ttwo",'),
        );
      });

      test('respects indent', () {
        const node = HWImage(HWImageData('avatar'));
        expect(
          node.toKotlin(1, dataExpr: 'data'),
          '    data.avatar?.let { path -> '
          'hwDecodeImageFile(context, path, null, null) }\n'
          '        ?.let { bitmap ->\n'
          '            Image(\n'
          '                provider = ImageProvider(bitmap),\n'
          '                contentDescription = null,\n'
          '                contentScale = ContentScale.Fit,\n'
          '            )\n'
          '        }',
        );
      });

      test('kotlinImports cover the emitted calls', () {
        expect(const HWImage(HWImageData('a')).kotlinImports, {
          'import android.graphics.BitmapFactory',
          'import androidx.glance.Image',
          'import androidx.glance.ImageProvider',
          'import androidx.glance.layout.ContentScale',
        });
      });

      test('kotlinImports add sizing imports for width and height', () {
        expect(
          const HWImage(HWImageData('a'), width: 10).kotlinImports,
          containsAll(<String>[
            'import androidx.compose.ui.unit.dp',
            'import androidx.glance.GlanceModifier',
            'import androidx.glance.layout.width',
          ]),
        );
        expect(
          const HWImage(HWImageData('a'), width: 10).kotlinImports,
          isNot(contains('import androidx.glance.layout.height')),
        );
        expect(
          const HWImage(HWImageData('a'), height: 10).kotlinImports,
          containsAll(<String>[
            'import androidx.compose.ui.unit.dp',
            'import androidx.glance.GlanceModifier',
            'import androidx.glance.layout.height',
          ]),
        );
        expect(
          const HWImage(HWImageData('a'), height: 10).kotlinImports,
          isNot(contains('import androidx.glance.layout.width')),
        );
      });

      test('injectGlanceModifier falls back to wrapping the chain in a Box',
          () {
        // The emitted Kotlin starts with a lowercase data access rather than a
        // capitalized composable call, so the modifier cannot be injected into
        // the Image(...) call and is applied to a surrounding Box instead.
        const node = HWImage(HWImageData('a'));
        final injected = injectGlanceModifier(
          node.toKotlin(0, dataExpr: 'data'),
          'fillMaxSize()',
        );
        expect(
          injected,
          startsWith('Box(modifier = GlanceModifier.fillMaxSize()) {\n'),
        );
        expect(injected, contains('    data.a?.let { path ->'));
        expect(injected, endsWith('\n}'));
      });

      test('a timed image reads the same field as an untimed one', () {
        const node = HWImage(HWTimedData(HWImageData('slide')));
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          const HWImage(HWImageData('slide')).toKotlin(0, dataExpr: 'data'),
        );
      });

      test('a JSON leaf image reads through the group', () {
        const node = HWImage(HWJson('contact', HWImageData('avatar')));
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          startsWith(
            'data.contact?.avatar?.let { path -> '
            'hwDecodeImageFile(context, path, null, null) }',
          ),
        );
      });
    });
  });
}
