import 'package:home_widget_generator/home_widget_generator.dart';

/// Extension for [HWAndroidResizeMode] to provide XML value conversion.
extension HWAndroidResizeModeExtension on HWAndroidResizeMode {
  /// Converts the resize mode to its corresponding XML attribute value.
  String toXmlValue() => switch (this) {
        HWAndroidResizeMode.none => 'none',
        HWAndroidResizeMode.horizontal => 'horizontal',
        HWAndroidResizeMode.vertical => 'vertical',
        HWAndroidResizeMode.horizontalAndVertical => 'horizontal|vertical',
      };
}

/// Extension for [HWAndroidWidgetCategory] to provide XML value conversion.
extension HWAndroidWidgetCategoryExtension on HWAndroidWidgetCategory {
  /// Converts the widget category to its corresponding XML attribute value.
  String toXmlValue() => switch (this) {
        HWAndroidWidgetCategory.homeScreen => 'home_screen',
        HWAndroidWidgetCategory.keyguard => 'keyguard',
        HWAndroidWidgetCategory.searchbox => 'searchbox',
      };
}

/// Extension for [HWWidgetFamily] to provide Swift code conversion.
extension HWWidgetFamilyExtension on HWWidgetFamily {
  /// Converts the widget family to its corresponding Swift enum member access.
  String toSwiftValue() => switch (this) {
        HWWidgetFamily.systemSmall => '.systemSmall',
        HWWidgetFamily.systemMedium => '.systemMedium',
        HWWidgetFamily.systemLarge => '.systemLarge',
        HWWidgetFamily.systemExtraLarge => '.systemExtraLarge',
        HWWidgetFamily.accessoryCircular => '.accessoryCircular',
        HWWidgetFamily.accessoryRectangular => '.accessoryRectangular',
        HWWidgetFamily.accessoryInline => '.accessoryInline',
      };
}
