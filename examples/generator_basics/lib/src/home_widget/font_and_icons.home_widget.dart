// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

class FontAndIconsHomeWidget {
  const FontAndIconsHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.FontAndIcons';

  static Future<void> saveData({
    FontAndIconsMoodIcon? mood,
  }) {
    return Future.wait([
      if (mood != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.mood', mood.codePoint, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool mood = false,
  }) {
    return Future.wait([
      if (mood) HomeWidget.saveWidgetData('${_$paramPrefix}.mood', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({FontAndIconsMoodIcon? mood})> getData() async {
    return (
      mood: FontAndIconsMoodIcon.fromCodePoint(await HomeWidget.getWidgetData<int>('${_$paramPrefix}.mood', defaultValue: 0xe6d9, appGroupId: _$appGroupId)),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'FontAndIconsHomeWidgetReceiver',
      iOSName: 'FontAndIconsHomeWidget',
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
      androidName: 'FontAndIconsHomeWidgetReceiver',
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
      androidName: 'FontAndIconsHomeWidgetReceiver',
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
      return androidClassName.endsWith('.FontAndIconsHomeWidgetReceiver');
    }
    return info.iOSKind == 'FontAndIconsHomeWidget';
  }
}

/// The icons the `mood` of this widget can show.
enum FontAndIconsMoodIcon {
  wbSunny(IconData(0xe6d9, fontFamily: 'MaterialIcons', fontPackage: null)),
  cloud(IconData(0xe16f, fontFamily: 'MaterialIcons', fontPackage: null)),
  umbrella(IconData(0xe68a, fontFamily: 'MaterialIcons', fontPackage: null)),
  acUnit(IconData(0xe037, fontFamily: 'MaterialIcons', fontPackage: null)),
  bolt(IconData(0xe0ee, fontFamily: 'MaterialIcons', fontPackage: null)),
  favoriteBorder(IconData(0xe25c, fontFamily: 'MaterialIcons', fontPackage: null)),
  star(IconData(0xe5f9, fontFamily: 'MaterialIcons', fontPackage: null)),
  pets(IconData(0xe4a1, fontFamily: 'MaterialIcons', fontPackage: null)),
  coffee(IconData(0xe178, fontFamily: 'MaterialIcons', fontPackage: null)),
  arrowForward(IconData(0xe09b, fontFamily: 'MaterialIcons', fontPackage: null, matchTextDirection: true));

  const FontAndIconsMoodIcon(this.icon);

  final IconData icon;

  int get codePoint => icon.codePoint;

  /// The value storing [codePoint], or null when this widget shows no icon
  /// for it.
  static FontAndIconsMoodIcon? fromCodePoint(int? codePoint) {
    if (codePoint == null) return null;
    for (final value in values) {
      if (value.codePoint == codePoint) return value;
    }
    return null;
  }
}
