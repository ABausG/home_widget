import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('hwResourceSnakeCase', () {
    test('lower cases and collapses everything outside [a-z0-9]', () {
      expect(hwResourceSnakeCase('Chewy'), 'chewy');
      expect(hwResourceSnakeCase('MaterialIcons'), 'materialicons');
      expect(hwResourceSnakeCase('Roboto Mono'), 'roboto_mono');
      expect(hwResourceSnakeCase('My-Icons.v2'), 'my_icons_v2');
    });
  });

  group('hwFontResourcePrefix', () {
    test('namespaces a widget', () {
      expect(hwFontResourcePrefix('forecast'), 'hw_font_forecast');
    });
  });

  group('HWFontVariant', () {
    test('resourceSuffix carries family, weight and slant', () {
      const variant =
          HWFontVariant(family: 'Chewy', weight: 400, italic: false);
      expect(variant.resourceSuffix, 'chewy_400_n');
    });

    test('resourceSuffix carries the package when there is one', () {
      const variant = HWFontVariant(
        family: 'Roboto Mono',
        package: 'my_fonts',
        weight: 700,
        italic: true,
      );
      expect(variant.resourceSuffix, 'roboto_mono_my_fonts_700_i');
    });

    test('flutterFamilyKey namespaces a package family', () {
      expect(
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false)
            .flutterFamilyKey,
        'Chewy',
      );
      expect(
        const HWFontVariant(
          family: 'Chewy',
          package: 'my_fonts',
          weight: 400,
          italic: false,
        ).flutterFamilyKey,
        'packages/my_fonts/Chewy',
      );
    });

    test('equality covers every part of the file choice', () {
      const variant =
          HWFontVariant(family: 'Chewy', weight: 400, italic: false);
      expect(
        variant,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
      );
      expect(
        variant.hashCode,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false)
            .hashCode,
      );
      expect(
        variant,
        isNot(const HWFontVariant(family: 'Chewy', weight: 700, italic: false)),
      );
      expect(
        variant,
        isNot(const HWFontVariant(family: 'Chewy', weight: 400, italic: true)),
      );
      expect(
        variant,
        isNot(
          const HWFontVariant(
            family: 'Chewy',
            package: 'my_fonts',
            weight: 400,
            italic: false,
          ),
        ),
      );
      expect(variant.toString(), contains('Chewy'));
    });
  });

  group('HWIconFont', () {
    test('resource names', () {
      const font = HWIconFont(family: 'MaterialIcons');
      expect(font.resourceSuffix, 'icons_materialicons');
      expect(
        font.androidResourceName(hwFontResourcePrefix('forecast')),
        'hw_font_forecast_icons_materialicons',
      );
      expect(font.iosResourceName, 'hw_font_icons_materialicons');
    });

    test('resource names carry the package when there is one', () {
      const font =
          HWIconFont(family: 'CupertinoIcons', package: 'cupertino_icons');
      expect(font.resourceSuffix, 'icons_cupertinoicons_cupertino_icons');
      expect(
        font.iosResourceName,
        'hw_font_icons_cupertinoicons_cupertino_icons',
      );
      expect(
        font.androidResourceName(null),
        'hw_font_home_widget_icons_cupertinoicons_cupertino_icons',
      );
    });

    test('equality covers family and package', () {
      const font = HWIconFont(family: 'MaterialIcons');
      expect(font, const HWIconFont(family: 'MaterialIcons'));
      expect(font.hashCode, const HWIconFont(family: 'MaterialIcons').hashCode);
      expect(
        font,
        isNot(const HWIconFont(family: 'MaterialIcons', package: 'pack')),
      );
      expect(font.toString(), contains('MaterialIcons'));
    });
  });
}
