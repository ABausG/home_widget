// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class SizeAdaptiveDashboardHomeWidget {
  const SizeAdaptiveDashboardHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.SizeAdaptiveDashboard';

  static Future<void> saveData({
    int? score,
    String? scoreLabel,
    int? streak,
    String? motivation,
  }) {
    return Future.wait([
      if (score != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.score', score, appGroupId: _$appGroupId),
      if (scoreLabel != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.scoreLabel', scoreLabel, appGroupId: _$appGroupId),
      if (streak != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.streak', streak, appGroupId: _$appGroupId),
      if (motivation != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.motivation', motivation, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool score = false,
    bool scoreLabel = false,
    bool streak = false,
    bool motivation = false,
  }) {
    return Future.wait([
      if (score) HomeWidget.saveWidgetData('${_$paramPrefix}.score', null, appGroupId: _$appGroupId),
      if (scoreLabel) HomeWidget.saveWidgetData('${_$paramPrefix}.scoreLabel', null, appGroupId: _$appGroupId),
      if (streak) HomeWidget.saveWidgetData('${_$paramPrefix}.streak', null, appGroupId: _$appGroupId),
      if (motivation) HomeWidget.saveWidgetData('${_$paramPrefix}.motivation', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({int? score, String? scoreLabel, int? streak, String? motivation})> getData() async {
    return (
      score: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.score', defaultValue: 0, appGroupId: _$appGroupId),
      scoreLabel: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.scoreLabel', defaultValue: 'Points', appGroupId: _$appGroupId),
      streak: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.streak', defaultValue: 0, appGroupId: _$appGroupId),
      motivation: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.motivation', defaultValue: 'Keep it up!', appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'SizeAdaptiveDashboardHomeWidgetReceiver',
      iOSName: 'SizeAdaptiveDashboardHomeWidget',
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
      androidName: 'SizeAdaptiveDashboardHomeWidgetReceiver',
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
      androidName: 'SizeAdaptiveDashboardHomeWidgetReceiver',
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
      return androidClassName.endsWith('.SizeAdaptiveDashboardHomeWidgetReceiver');
    }
    return info.iOSKind == 'SizeAdaptiveDashboardHomeWidget';
  }
}
