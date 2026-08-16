// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class LocalizedGreetingHomeWidget {
  const LocalizedGreetingHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.LocalizedGreeting';

  static Future<void> saveData({
    LocalizedGreetingHomeWidgetLocalizations? greeting,
  }) {
    return Future.wait([
      if (greeting != null) ...greeting.toMap().entries.map((entry) => HomeWidget.saveWidgetData<String>('${_$paramPrefix}.greeting.${entry.key}', entry.value, appGroupId: _$appGroupId)),
    ]);
  }

  static Future<void> deleteData({
    bool greeting = false,
  }) {
    return Future.wait([
      if (greeting) ...const ['en', 'de', 'pt-BR'].map((locale) => HomeWidget.saveWidgetData('${_$paramPrefix}.greeting.$locale', null, appGroupId: _$appGroupId)),
    ]);
  }

  static Future<({Map<String, String>? greeting})> getData() async {
    return (
      greeting: await _$readLocalized('${_$paramPrefix}.greeting'),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'LocalizedGreetingHomeWidgetReceiver',
      iOSName: 'LocalizedGreetingHomeWidget',
    );
  }

  static Future<Map<String, String>?> _$readLocalized(String key) async {
    final values = <String, String>{};
    for (final locale in const ['en', 'de', 'pt-BR']) {
      final value = await HomeWidget.getWidgetData<String>('$key.$locale', appGroupId: _$appGroupId);
      if (value != null) values[locale] = value;
    }
    return values.isEmpty ? null : values;
  }
}

class LocalizedGreetingHomeWidgetLocalizations {
  const LocalizedGreetingHomeWidgetLocalizations({
    required this.en,
    required this.de,
    required this.ptBR,
  });

  final String en;
  final String de;
  final String ptBR;

  Map<String, String> toMap() => {
        'en': en,
        'de': de,
        'pt-BR': ptBR,
      };
}
