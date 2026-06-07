// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class SimpleDataHomeWidget {
  const SimpleDataHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.SimpleData';

  static Future<void> saveData({
    String? label,
    int? value,
  }) {
    return Future.wait([
      if (label != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.label', label, appGroupId: _$appGroupId),
      if (value != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.value', value, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool label = false,
    bool value = false,
  }) {
    return Future.wait([
      if (label) HomeWidget.saveWidgetData('${_$paramPrefix}.label', null, appGroupId: _$appGroupId),
      if (value) HomeWidget.saveWidgetData('${_$paramPrefix}.value', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({String? label, int? value})> getData() async {
    return (
      label: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.label', appGroupId: _$appGroupId),
      value: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.value', appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'SimpleDataHomeWidgetReceiver',
      iOSName: 'SimpleDataHomeWidget',
    );
  }
}
