import 'widgets/hw_color.dart';
import 'widgets/hw_widget.dart';

/// The rules by which a widget can be resized.
///
/// See: [AppWidgetProviderInfo.resizeMode](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#resizeMode)
enum HWAndroidResizeMode {
  /// The widget is not resizable.
  none,

  /// The widget is resizable horizontally.
  horizontal,

  /// The widget is resizable vertically.
  vertical,

  /// The widget is resizable both horizontally and vertically.
  horizontalAndVertical,
}

/// The category of widget. Whether it can be displayed on the home screen,
/// the keyguard, or both.
///
/// See: [AppWidgetProviderInfo.widgetCategory](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#widgetCategory)
enum HWAndroidWidgetCategory {
  /// The widget can be displayed on the home screen.
  homeScreen,

  /// The widget can be displayed on the keyguard.
  keyguard,

  /// The widget can be displayed in the search box.
  searchbox,
}

/// Configuration for the Android widget.
///
/// See: [AppWidgetProviderInfo](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo)
class HomeWidgetAndroidConfiguration {
  /// The package name of the app.
  ///
  /// If null, the plugin will attempt to detect the package name from
  /// the Android project.
  final String? packageName;

  /// The default width of the widget when added to a host, in dp.
  ///
  /// See: [AppWidgetProviderInfo.minWidth](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#minWidth)
  final int? minWidth;

  /// The default height of the widget when added to a host, in dp.
  ///
  /// See: [AppWidgetProviderInfo.minHeight](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#minHeight)
  final int? minHeight;

  /// The minimum width the widget can be resized to, in dp.
  ///
  /// See: [AppWidgetProviderInfo.minResizeWidth](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#minResizeWidth)
  final int? minResizeWidth;

  /// The minimum height the widget can be resized to, in dp.
  ///
  /// See: [AppWidgetProviderInfo.minResizeHeight](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#minResizeHeight)
  final int? minResizeHeight;

  /// The maximum width the widget can be resized to, in dp.
  ///
  /// **Note:** This field corresponds to `maxResizeWidth` on Android 12 (API level 31) and higher.
  ///
  /// See: [AppWidgetProviderInfo.maxResizeWidth](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#maxResizeWidth)
  final int? maxResizeWidth;

  /// The maximum height the widget can be resized to, in dp.
  ///
  /// **Note:** This field corresponds to `maxResizeHeight` on Android 12 (API level 31) and higher.
  ///
  /// See: [AppWidgetProviderInfo.maxResizeHeight](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#maxResizeHeight)
  final int? maxResizeHeight;

  /// The default width of the widget when added to a host, in cells.
  ///
  /// **Note:** This field corresponds to `targetCellWidth` on Android 12 (API level 31) and higher.
  ///
  /// See: [AppWidgetProviderInfo.targetCellWidth](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#targetCellWidth)
  final int? targetCellWidth;

  /// The default height of the widget when added to a host, in cells.
  ///
  /// **Note:** This field corresponds to `targetCellHeight` on Android 12 (API level 31) and higher.
  ///
  /// See: [AppWidgetProviderInfo.targetCellHeight](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#targetCellHeight)
  final int? targetCellHeight;

  /// The rules by which a widget can be resized.
  ///
  /// See: [AppWidgetProviderInfo.resizeMode](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#resizeMode)
  final HWAndroidResizeMode? resizeMode;

  /// The category of widget.
  ///
  /// See: [AppWidgetProviderInfo.widgetCategory](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#widgetCategory)
  final HWAndroidWidgetCategory? widgetCategory;

  /// The update period in milliseconds.
  ///
  /// See: [AppWidgetProviderInfo.updatePeriodMillis](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo#updatePeriodMillis)
  final int? updatePeriodMillis;

  /// Whether to wrap the widget in a `GlanceTheme`.
  ///
  /// Defaults to `true`. When true, the generated Android code will use
  /// `GlanceTheme { ... }` which generates local CompositionLocals for colors.
  final bool useGlanceTheme;

  /// The background color to be applied to the widget.
  ///
  /// Defaults to `HWDefaultColor(HWColorRole.defaultBackground)`.
  /// When not null, applies a `GlanceModifier.background(color)`.
  final HWColor? backgroundColor;

  /// Whether to apply default content padding to the widget.
  ///
  /// Defaults to `true`. If true, applies 16.dp root padding on Android.
  final bool applyContentPadding;

  /// Whether to apply fill modifier to the widget content.
  ///
  /// Defaults to `true`. If true, applies `GlanceModifier.fillMaxSize()`.
  final bool fillWidgetContent;

  const HomeWidgetAndroidConfiguration({
    this.packageName,
    this.minWidth,
    this.minHeight,
    this.minResizeWidth,
    this.minResizeHeight,
    this.maxResizeWidth,
    this.maxResizeHeight,
    this.targetCellWidth,
    this.targetCellHeight,
    this.resizeMode,
    this.widgetCategory,
    this.updatePeriodMillis,
    this.useGlanceTheme = true,
    this.backgroundColor = const HWDefaultColor(HWColorRole.defaultBackground),
    this.applyContentPadding = true,
    this.fillWidgetContent = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetAndroidConfiguration &&
          packageName == other.packageName &&
          minWidth == other.minWidth &&
          minHeight == other.minHeight &&
          minResizeWidth == other.minResizeWidth &&
          minResizeHeight == other.minResizeHeight &&
          maxResizeWidth == other.maxResizeWidth &&
          maxResizeHeight == other.maxResizeHeight &&
          targetCellWidth == other.targetCellWidth &&
          targetCellHeight == other.targetCellHeight &&
          resizeMode == other.resizeMode &&
          widgetCategory == other.widgetCategory &&
          updatePeriodMillis == other.updatePeriodMillis &&
          useGlanceTheme == other.useGlanceTheme &&
          backgroundColor == other.backgroundColor &&
          applyContentPadding == other.applyContentPadding &&
          fillWidgetContent == other.fillWidgetContent;

  @override
  int get hashCode =>
      packageName.hashCode ^
      minWidth.hashCode ^
      minHeight.hashCode ^
      minResizeWidth.hashCode ^
      minResizeHeight.hashCode ^
      maxResizeWidth.hashCode ^
      maxResizeHeight.hashCode ^
      targetCellWidth.hashCode ^
      targetCellHeight.hashCode ^
      resizeMode.hashCode ^
      widgetCategory.hashCode ^
      updatePeriodMillis.hashCode ^
      useGlanceTheme.hashCode ^
      backgroundColor.hashCode ^
      applyContentPadding.hashCode ^
      fillWidgetContent.hashCode;
}

/// The size and shape of a widget.
///
/// See: [WidgetFamily](https://developer.apple.com/documentation/widgetkit/widgetfamily)
enum HWWidgetFamily {
  /// A small widget.
  systemSmall,

  /// A medium-sized widget.
  systemMedium,

  /// A large widget.
  systemLarge,

  /// An extra-large widget.
  systemExtraLarge,

  /// A circular accessory widget.
  accessoryCircular,

  /// A rectangular accessory widget.
  accessoryRectangular,

  /// An inline accessory widget.
  accessoryInline,
}

/// Configuration for the iOS widget.
///
/// See: [WidgetConfiguration](https://developer.apple.com/documentation/widgetkit/widgetconfiguration)
class HomeWidgetIOSConfiguration {
  /// The App Group ID allowing data sharing between the app and the widget.
  final String groupId;

  /// The supported widget families.
  ///
  /// See: [StaticConfiguration.supportedFamilies(_:)](https://developer.apple.com/documentation/widgetkit/staticconfiguration/supportedfamilies(_:))
  final List<HWWidgetFamily>? supportedFamilies;

  /// The background color to be applied to the widget.
  final HWColor? backgroundColor;

  /// Whether to apply default system content margin to the widget.
  ///
  /// Defaults to `true`. If false, disables the default system padding using contentMarginsDisabled().
  final bool applyContentPadding;

  const HomeWidgetIOSConfiguration({
    required this.groupId,
    this.supportedFamilies,
    this.backgroundColor,
    this.applyContentPadding = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetIOSConfiguration &&
          groupId == other.groupId &&
          supportedFamilies == other.supportedFamilies &&
          backgroundColor == other.backgroundColor &&
          applyContentPadding == other.applyContentPadding;

  @override
  int get hashCode =>
      groupId.hashCode ^
      supportedFamilies.hashCode ^
      backgroundColor.hashCode ^
      applyContentPadding.hashCode;
}

/// Annotation for generating home_widget native code.
class HomeWidget {
  /// The name of the widget.
  ///
  /// This corresponds to the `kind` in iOS WidgetKit and the `label` in Android
  /// receiver.
  final String name;

  /// A description of the widget.
  ///
  /// This is displayed in the widget gallery on iOS and Android.
  final String? description;

  /// The widget structure defined inline.
  final HWWidget? widget;

  /// The path to the generated Dart file.
  ///
  /// This file will contain helper methods for updating the widget data.
  final String? dartOutput;

  /// Configuration for the Android widget.
  final HomeWidgetAndroidConfiguration? android;

  /// Configuration for the iOS widget.
  final HomeWidgetIOSConfiguration? iOS;

  const HomeWidget({
    required this.name,
    this.description,
    this.widget,
    this.dartOutput,
    this.android,
    this.iOS,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidget &&
          name == other.name &&
          description == other.description &&
          widget == other.widget &&
          dartOutput == other.dartOutput &&
          android == other.android &&
          iOS == other.iOS;

  @override
  int get hashCode =>
      name.hashCode ^
      description.hashCode ^
      widget.hashCode ^
      dartOutput.hashCode ^
      android.hashCode ^
      iOS.hashCode;
}
