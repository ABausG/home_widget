// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class ConditionalStatusHomeWidget {
  const ConditionalStatusHomeWidget._();

  static Future<void> ensureInitialized() async {
    await HomeWidget.setAppGroupId('group.es.antonborri.generatorBasics');
  }

  static const String _paramPrefix = 'home_widget.ConditionalStatus';

  static Future<void> saveData({
    bool? hasData,
    bool? enabled,
  }) {
    return Future.wait([
      if (hasData != null) HomeWidget.saveWidgetData<bool>('$_paramPrefix.hasData', hasData),
      if (enabled != null) HomeWidget.saveWidgetData<bool>('$_paramPrefix.enabled', enabled),
    ]);
  }

  static Future<void> deleteData({
    bool hasData = false,
    bool enabled = false,
  }) {
    return Future.wait([
      if (hasData) HomeWidget.saveWidgetData('$_paramPrefix.hasData', null),
      if (enabled) HomeWidget.saveWidgetData('$_paramPrefix.enabled', null),
    ]);
  }

  static Future<({bool? hasData, bool? enabled})> getData() async {
    return (
      hasData: await HomeWidget.getWidgetData<bool>('$_paramPrefix.hasData'),
      enabled: await HomeWidget.getWidgetData<bool>('$_paramPrefix.enabled', defaultValue: true),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ConditionalStatusHomeWidgetReceiver',
      iOSName: 'ConditionalStatusHomeWidget',
    );
  }
}
