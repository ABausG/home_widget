// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class ThemedCounterHomeWidget {
  const ThemedCounterHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.ThemedCounter';

  static Future<void> saveData({
    int? count,
  }) {
    return Future.wait([
      if (count != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.count', count, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool count = false,
  }) {
    return Future.wait([
      if (count) HomeWidget.saveWidgetData('${_$paramPrefix}.count', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({int? count})> getData() async {
    return (
      count: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.count', defaultValue: 0, appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ThemedCounterHomeWidgetReceiver',
      iOSName: 'ThemedCounterHomeWidget',
    );
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
