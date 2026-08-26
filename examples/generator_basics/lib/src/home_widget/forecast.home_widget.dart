// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:home_widget/home_widget.dart';

class ForecastHomeWidget {
  const ForecastHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.Forecast';

  static Future<void> saveData({
    String? city,
    Map<DateTime, ForecastTimedData>? timedData,
  }) {
    return Future.wait([
      if (city != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.city', city, appGroupId: _$appGroupId),
      if (timedData != null) () async {
        final _timedTimes = timedData.keys.toList()..sort();
        if (_timedTimes.isEmpty) {
          await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
          try {
            await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'ForecastHomeWidgetReceiver');
          } catch (_) {
            // Scheduling is best effort; the data was saved.
          }
          return;
        }
        final _timedJson = <String, dynamic>{
          for (final _time in _timedTimes)
            _time.toUtc().millisecondsSinceEpoch.toString(): timedData[_time]!.toJson(),
        };
        await HomeWidget.saveFile('${_$paramPrefix}.timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json', appGroupId: _$appGroupId);
        try {
          await HomeWidget.scheduleWidgetUpdates(_timedTimes, androidName: 'ForecastHomeWidgetReceiver');
        } catch (_) {
          // Scheduling is best effort; the data was saved.
        }
      }(),
    ]);
  }

  static Future<void> deleteData({
    bool city = false,
    bool timedData = false,
  }) {
    return Future.wait([
      if (city) HomeWidget.saveWidgetData('${_$paramPrefix}.city', null, appGroupId: _$appGroupId),
      if (timedData) () async {
        await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
        try {
          await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'ForecastHomeWidgetReceiver');
        } catch (_) {
          // Scheduling is best effort; the data was saved.
        }
      }(),
    ]);
  }

  /// Reads the stored widget data.
  ///
  /// The keys of [timedData] are local-time [DateTime]s, so they compare equal to a
  /// local [DateTime] for the same instant. Timestamps are stored as epoch
  /// milliseconds: sub-millisecond precision of the saved keys is not preserved.
  static Future<({String? city, Map<DateTime, ForecastTimedData>? timedData})> getData() async {
    final _timedDataPath = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.timedData', appGroupId: _$appGroupId);
    Map<DateTime, ForecastTimedData>? timedData;
    if (_timedDataPath != null) {
      try {
        final raw = await File(_timedDataPath).readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final entries = <DateTime, ForecastTimedData>{};
          for (final entry in decoded.entries) {
            final millis = int.tryParse(entry.key);
            if (millis == null) continue;
            final value = entry.value;
            entries[DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal()] = ForecastTimedData.fromJson(value is Map<String, dynamic> ? value : null);
          }
          timedData = entries;
        }
      } on Exception {
        timedData = null;
      }
    }
    return (
      city: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.city', defaultValue: 'Nowhere', appGroupId: _$appGroupId),
      timedData: timedData,
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ForecastHomeWidgetReceiver',
      iOSName: 'ForecastHomeWidget',
    );
  }
}

class ForecastTimedData {
  final String? condition;
  final int? temperature;

  const ForecastTimedData({
    this.condition,
    this.temperature,
  });

  factory ForecastTimedData.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return ForecastTimedData(
      condition: _readString(json['condition']) ?? 'No forecast',
      temperature: _readInt(json['temperature']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (condition != null) 'condition': condition,
      if (temperature != null) 'temperature': temperature,
    };
  }
}

String? _readString(Object? value) => value is String ? value : null;
int? _readInt(Object? value) => value is num ? value.toInt() : null;
