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
}
