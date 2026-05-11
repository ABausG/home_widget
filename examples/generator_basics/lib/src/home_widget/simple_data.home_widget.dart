// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class SimpleDataHomeWidget {
  const SimpleDataHomeWidget._();

  static Future<void> ensureInitialized() async {
    await HomeWidget.setAppGroupId('group.es.antonborri.generatorBasics');
  }

  static const String _paramPrefix = 'home_widget.SimpleData';

  static Future<void> saveData({
    String? label,
    int? value,
  }) {
    return Future.wait([
      if (label != null) HomeWidget.saveWidgetData<String>('$_paramPrefix.label', label),
      if (value != null) HomeWidget.saveWidgetData<int>('$_paramPrefix.value', value),
    ]);
  }

  static Future<void> deleteData({
    bool label = false,
    bool value = false,
  }) {
    return Future.wait([
      if (label) HomeWidget.saveWidgetData('$_paramPrefix.label', null),
      if (value) HomeWidget.saveWidgetData('$_paramPrefix.value', null),
    ]);
  }

  static Future<({String? label, int? value})> getData() async {
    return (
      label: await HomeWidget.getWidgetData<String>('$_paramPrefix.label'),
      value: await HomeWidget.getWidgetData<int>('$_paramPrefix.value'),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'SimpleDataHomeWidgetReceiver',
      iOSName: 'SimpleDataHomeWidget',
    );
  }
}
