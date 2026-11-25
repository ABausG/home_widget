// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'dart:ui' show Color, ColorSpace;
import 'package:home_widget/home_widget.dart';

class ThemedCounterHomeWidget {
  const ThemedCounterHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.ThemedCounter';

  static Future<void> saveData({
    int? count,
    Color? accentLight,
    Color? accentDark,
  }) {
    return Future.wait([
      if (count != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.count', count, appGroupId: _$appGroupId),
      if (accentLight != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.accentLight', accentLight.withValues(colorSpace: ColorSpace.sRGB).toARGB32(), appGroupId: _$appGroupId),
      if (accentDark != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.accentDark', accentDark.withValues(colorSpace: ColorSpace.sRGB).toARGB32(), appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool count = false,
    bool accentLight = false,
    bool accentDark = false,
  }) {
    return Future.wait([
      if (count) HomeWidget.saveWidgetData('${_$paramPrefix}.count', null, appGroupId: _$appGroupId),
      if (accentLight) HomeWidget.saveWidgetData('${_$paramPrefix}.accentLight', null, appGroupId: _$appGroupId),
      if (accentDark) HomeWidget.saveWidgetData('${_$paramPrefix}.accentDark', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({int? count, Color? accentLight, Color? accentDark})> getData() async {
    return (
      count: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.count', defaultValue: 0, appGroupId: _$appGroupId),
      accentLight: _$color(await HomeWidget.getWidgetData<int>('${_$paramPrefix}.accentLight', defaultValue: 0xFF1D4ED8, appGroupId: _$appGroupId)),
      accentDark: _$color(await HomeWidget.getWidgetData<int>('${_$paramPrefix}.accentDark', defaultValue: 0xFF93C5FD, appGroupId: _$appGroupId)),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ThemedCounterHomeWidgetReceiver',
      iOSName: 'ThemedCounterHomeWidget',
    );
  }

  /// Asks the launcher to re-render this widget's gallery preview.
  ///
  /// Android 15 and newer only; returns false elsewhere and when the system
  /// rate limit (about two updates per hour and widget) was hit. The plugin
  /// registers the preview automatically when the app starts, so this is only
  /// needed after data changes that should show in the gallery right away.
  static Future<bool> updatePreview() async {
    return await HomeWidget.updateWidgetPreview(
      androidName: 'ThemedCounterHomeWidgetReceiver',
    ) ?? false;
  }

  /// Whether the launcher lets the app ask to add this widget to the home
  /// screen: Android 8 or newer with a launcher that supports pinning. Always
  /// false on iOS.
  static Future<bool> isRequestPinWidgetSupported() async {
    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  }

  /// Asks the launcher to add this widget to the home screen.
  ///
  /// Shows the system pin dialog where [isRequestPinWidgetSupported] is true
  /// and does nothing anywhere else.
  static Future<void> requestPinWidget() {
    return HomeWidget.requestPinWidget(
      androidName: 'ThemedCounterHomeWidgetReceiver',
    );
  }

  /// Every instance of this widget currently placed on a home screen.
  ///
  /// Android reports one entry per placed instance, iOS one entry per family
  /// the widget is placed in.
  static Future<List<HomeWidgetInfo>> getInstalledWidgets() async {
    final widgets = await HomeWidget.getInstalledWidgets();
    return widgets.where(_$isThisWidget).toList();
  }

  /// Whether at least one instance of this widget is on a home screen.
  static Future<bool> isInstalled() async {
    return (await getInstalledWidgets()).isNotEmpty;
  }

  /// Whether [info] describes this widget.
  ///
  /// Android reports the provider's short class name — `.Receiver` when it
  /// lives in the package of the application id, and the qualified name
  /// otherwise — which is why the suffix is matched.
  static bool _$isThisWidget(HomeWidgetInfo info) {
    final androidClassName = info.androidClassName;
    if (androidClassName != null) {
      return androidClassName.endsWith('.ThemedCounterHomeWidgetReceiver');
    }
    return info.iOSKind == 'ThemedCounterHomeWidget';
  }
}

Color? _$color(int? argb) => argb == null ? null : Color(argb);
