import 'package:home_widget_cli/src/models/extensions.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWAndroidResizeModeExtension.toXmlValue', () {
    test('maps every variant', () {
      expect(HWAndroidResizeMode.none.toXmlValue(), 'none');
      expect(HWAndroidResizeMode.horizontal.toXmlValue(), 'horizontal');
      expect(HWAndroidResizeMode.vertical.toXmlValue(), 'vertical');
      expect(
        HWAndroidResizeMode.horizontalAndVertical.toXmlValue(),
        'horizontal|vertical',
      );
    });
  });

  group('HWAndroidWidgetCategoryExtension.toXmlValue', () {
    test('maps every variant', () {
      expect(HWAndroidWidgetCategory.homeScreen.toXmlValue(), 'home_screen');
      expect(HWAndroidWidgetCategory.keyguard.toXmlValue(), 'keyguard');
      expect(HWAndroidWidgetCategory.searchbox.toXmlValue(), 'searchbox');
    });
  });

  group('HWWidgetFamilyExtension.toSwiftValue', () {
    test('maps every variant', () {
      expect(HWWidgetFamily.systemSmall.toSwiftValue(), '.systemSmall');
      expect(HWWidgetFamily.systemMedium.toSwiftValue(), '.systemMedium');
      expect(HWWidgetFamily.systemLarge.toSwiftValue(), '.systemLarge');
      expect(
        HWWidgetFamily.systemExtraLarge.toSwiftValue(),
        '.systemExtraLarge',
      );
      expect(
        HWWidgetFamily.systemExtraLargePortrait.toSwiftValue(),
        '.systemExtraLargePortrait',
      );
      expect(
        HWWidgetFamily.accessoryCircular.toSwiftValue(),
        '.accessoryCircular',
      );
      expect(
        HWWidgetFamily.accessoryRectangular.toSwiftValue(),
        '.accessoryRectangular',
      );
      expect(
        HWWidgetFamily.accessoryInline.toSwiftValue(),
        '.accessoryInline',
      );
    });
  });

  group('HWWidgetFamilyExtension.minimumIosVersion', () {
    test('leaves the families of the deployment target ungated', () {
      expect(HWWidgetFamily.systemSmall.minimumIosVersion, isNull);
      expect(HWWidgetFamily.systemMedium.minimumIosVersion, isNull);
      expect(HWWidgetFamily.systemLarge.minimumIosVersion, isNull);
    });

    test('names the version every newer family arrived with', () {
      expect(HWWidgetFamily.systemExtraLarge.minimumIosVersion, '15.0');
      expect(HWWidgetFamily.accessoryCircular.minimumIosVersion, '16.0');
      expect(HWWidgetFamily.accessoryRectangular.minimumIosVersion, '16.0');
      expect(HWWidgetFamily.accessoryInline.minimumIosVersion, '16.0');
      expect(
        HWWidgetFamily.systemExtraLargePortrait.minimumIosVersion,
        '27.0',
      );
    });
  });

  group('HWWidgetFamilyExtension.needsCompilerGate', () {
    test('only the portrait extra-large is missing from older toolchains', () {
      for (final family in HWWidgetFamily.values) {
        expect(
          family.needsCompilerGate,
          family == HWWidgetFamily.systemExtraLargePortrait,
          reason: family.name,
        );
      }
    });
  });
}
