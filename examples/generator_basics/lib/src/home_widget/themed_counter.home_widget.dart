// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class ThemedCounterHomeWidget {
  const ThemedCounterHomeWidget._();

  static Future<void> ensureInitialized() async {
    await HomeWidget.setAppGroupId('group.es.antonborri.generatorBasics');
  }

  static const String _paramPrefix = 'home_widget.ThemedCounter';

  static Future<void> saveData({
    int? count,
  }) {
    return Future.wait([
      if (count != null) HomeWidget.saveWidgetData<int>('$_paramPrefix.count', count),
    ]);
  }

  static Future<void> deleteData({
    bool count = false,
  }) {
    return Future.wait([
      if (count) HomeWidget.saveWidgetData('$_paramPrefix.count', null),
    ]);
  }

  static Future<({int? count})> getData() async {
    return (
      count: await HomeWidget.getWidgetData<int>('$_paramPrefix.count', defaultValue: 0),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ThemedCounterHomeWidgetReceiver',
      iOSName: 'ThemedCounterHomeWidget',
    );
  }
}
