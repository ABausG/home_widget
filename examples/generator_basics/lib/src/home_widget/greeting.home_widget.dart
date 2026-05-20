// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class GreetingHomeWidget {
  const GreetingHomeWidget._();

  static Future<void> ensureInitialized() async {
    await HomeWidget.setAppGroupId('group.es.antonborri.generatorBasics');
  }

  static const String _paramPrefix = 'home_widget.Greeting';

  static Future<void> saveData({
    String? name,
  }) {
    return Future.wait([
      if (name != null) HomeWidget.saveWidgetData<String>('$_paramPrefix.name', name),
    ]);
  }

  static Future<void> deleteData({
    bool name = false,
  }) {
    return Future.wait([
      if (name) HomeWidget.saveWidgetData('$_paramPrefix.name', null),
    ]);
  }

  static Future<({String? name})> getData() async {
    return (
      name: await HomeWidget.getWidgetData<String>('$_paramPrefix.name', defaultValue: 'world'),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'GreetingHomeWidgetReceiver',
      iOSName: 'GreetingHomeWidget',
    );
  }
}
