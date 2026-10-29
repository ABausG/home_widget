// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

class WeekForecastHomeWidget {
  const WeekForecastHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.WeekForecast';

  static Future<void> saveData({
    String? city,
    String? unit,
    List<WeekForecastDaysItem>? days,
  }) {
    return Future.wait([
      if (city != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.city', city, appGroupId: _$appGroupId),
      if (unit != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.unit', unit, appGroupId: _$appGroupId),
      if (days != null) () async {
        await HomeWidget.saveFile('${_$paramPrefix}.days', Uint8List.fromList(utf8.encode(jsonEncode([for (final _item in days) _item.toJson()]))), extension: 'json', appGroupId: _$appGroupId);
      }(),
    ]);
  }

  static Future<void> deleteData({
    bool city = false,
    bool unit = false,
    bool days = false,
  }) {
    return Future.wait([
      if (city) HomeWidget.saveWidgetData('${_$paramPrefix}.city', null, appGroupId: _$appGroupId),
      if (unit) HomeWidget.saveWidgetData('${_$paramPrefix}.unit', null, appGroupId: _$appGroupId),
      if (days) HomeWidget.saveWidgetData('${_$paramPrefix}.days', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({String? city, String? unit, List<WeekForecastDaysItem>? days})> getData() async {
    final _daysPath = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.days', appGroupId: _$appGroupId);
    List<WeekForecastDaysItem>? days;
    if (_daysPath != null) {
      try {
        final _daysJson = jsonDecode(await File(_daysPath).readAsString());
        if (_daysJson is List) days = [for (final _item in _daysJson) WeekForecastDaysItem.fromJson(_item is Map<String, dynamic> ? _item : null)];
      } on Exception {
        days = null;
      }
    }
    return (
      city: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.city', defaultValue: 'Nowhere', appGroupId: _$appGroupId),
      unit: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.unit', defaultValue: '°', appGroupId: _$appGroupId),
      days: days,
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'WeekForecastHomeWidgetReceiver',
      iOSName: 'WeekForecastHomeWidget',
    );
  }

  /// Asks the launcher to re-render this widget's gallery preview.
  ///
  /// Android 15 and newer only; returns false elsewhere and when the system
  /// rate limit (about two updates per hour and widget) was hit. The plugin
  /// registers the preview automatically when the app starts, so this is only
  /// needed after data changes that should show in the gallery right away.
  static Future<bool> updatePreview() async {
    return await HomeWidget.updateWidgetPreview(
      androidName: 'WeekForecastHomeWidgetReceiver',
    ) ?? false;
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
      androidName: 'WeekForecastHomeWidgetReceiver',
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
      return androidClassName.endsWith('.WeekForecastHomeWidgetReceiver');
    }
    return info.iOSKind == 'WeekForecastHomeWidget';
  }
}

/// The icons the `condition` of this widget can show.
enum WeekForecastConditionIcon {
  wbSunny(IconData(0xe6d9, fontFamily: 'MaterialIcons', fontPackage: null)),
  cloud(IconData(0xe16f, fontFamily: 'MaterialIcons', fontPackage: null)),
  umbrella(IconData(0xe68a, fontFamily: 'MaterialIcons', fontPackage: null)),
  thunderstorm(IconData(0xf07cb, fontFamily: 'MaterialIcons', fontPackage: null)),
  acUnit(IconData(0xe037, fontFamily: 'MaterialIcons', fontPackage: null));

  const WeekForecastConditionIcon(this.icon);

  final IconData icon;

  int get codePoint => icon.codePoint;

  /// The value storing [codePoint], or null when this widget shows no icon
  /// for it.
  static WeekForecastConditionIcon? fromCodePoint(int? codePoint) {
    if (codePoint == null) return null;
    for (final value in values) {
      if (value.codePoint == codePoint) return value;
    }
    return null;
  }
}

class WeekForecastDaysItem {
  final DateTime? day;
  final WeekForecastConditionIcon? condition;
  final int? temperature;

  const WeekForecastDaysItem({
    this.day,
    this.condition,
    this.temperature,
  });

  factory WeekForecastDaysItem.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return WeekForecastDaysItem(
      day: _readDateTime(json['day']),
      condition: WeekForecastConditionIcon.fromCodePoint(_readInt(json['condition']) ?? 0xe16f),
      temperature: _readInt(json['temperature']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (day != null) 'day': day!.toUtc().toIso8601String(),
      if (condition != null) 'condition': condition!.codePoint,
      if (temperature != null) 'temperature': temperature,
    };
  }
}

int? _readInt(Object? value) => value is num ? value.toInt() : null;
DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
