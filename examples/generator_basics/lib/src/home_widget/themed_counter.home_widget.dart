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
}
