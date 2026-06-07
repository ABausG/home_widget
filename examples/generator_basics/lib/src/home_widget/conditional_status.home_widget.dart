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
}
