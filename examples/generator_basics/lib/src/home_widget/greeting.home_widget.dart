// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class GreetingHomeWidget {
  const GreetingHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.Greeting';

  static Future<void> saveData({
    String? name,
  }) {
    return Future.wait([
      if (name != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.name', name, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool name = false,
  }) {
    return Future.wait([
      if (name) HomeWidget.saveWidgetData('${_$paramPrefix}.name', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({String? name})> getData() async {
    return (
      name: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.name', defaultValue: 'world', appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'GreetingHomeWidgetReceiver',
      iOSName: 'GreetingHomeWidget',
    );
  }
}
