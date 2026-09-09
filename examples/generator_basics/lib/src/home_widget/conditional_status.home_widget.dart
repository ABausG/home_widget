// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class ConditionalStatusHomeWidget {
  const ConditionalStatusHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.ConditionalStatus';

  static Future<void> saveData({
    bool? hasData,
    bool? enabled,
  }) {
    return Future.wait([
      if (hasData != null) HomeWidget.saveWidgetData<bool>('${_$paramPrefix}.hasData', hasData, appGroupId: _$appGroupId),
      if (enabled != null) HomeWidget.saveWidgetData<bool>('${_$paramPrefix}.enabled', enabled, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool hasData = false,
    bool enabled = false,
  }) {
    return Future.wait([
      if (hasData) HomeWidget.saveWidgetData('${_$paramPrefix}.hasData', null, appGroupId: _$appGroupId),
      if (enabled) HomeWidget.saveWidgetData('${_$paramPrefix}.enabled', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({bool? hasData, bool? enabled})> getData() async {
    return (
      hasData: await HomeWidget.getWidgetData<bool>('${_$paramPrefix}.hasData', appGroupId: _$appGroupId),
      enabled: await HomeWidget.getWidgetData<bool>('${_$paramPrefix}.enabled', defaultValue: true, appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ConditionalStatusHomeWidgetReceiver',
      iOSName: 'ConditionalStatusHomeWidget',
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
      androidName: 'ConditionalStatusHomeWidgetReceiver',
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
      return androidClassName.endsWith('.ConditionalStatusHomeWidgetReceiver');
    }
    return info.iOSKind == 'ConditionalStatusHomeWidget';
  }
}
