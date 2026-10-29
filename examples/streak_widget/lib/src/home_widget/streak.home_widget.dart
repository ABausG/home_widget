// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

class StreakHomeWidget {
  const StreakHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.streakWidget';

  static const String _$paramPrefix = 'home_widget.Streak';

  /// Writes every value handed to it, and leaves out what it was not given.
  ///
  /// A picture this widget itself wrote, handed back by [getData] and since
  /// removed from disk, is saved as no picture rather than failing the call:
  /// a nested, timed or per-item one is cleared, a top-level one keeps the
  /// path it had.
  static Future<void> saveData({
    bool? frozen,
    int? streak,
    bool? completed,
    Map<DateTime, StreakTimedData>? timedData,
  }) async {
    final _timedImages_mascot = {
      if (timedData != null)
        for (final MapEntry(key: _time, value: _entry) in timedData.entries)
          _time: await _$readImage(_entry.mascot),
    };
    await Future.wait([
      if (frozen != null) HomeWidget.saveWidgetData<bool>('${_$paramPrefix}.frozen', frozen, appGroupId: _$appGroupId),
      if (streak != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.streak', streak, appGroupId: _$appGroupId),
      if (completed != null) HomeWidget.saveWidgetData<bool>('${_$paramPrefix}.completed', completed, appGroupId: _$appGroupId),
      if (timedData != null) () async {
        final _timedTimes = timedData.keys.toList()..sort();
        final _storedTimes = await _$storedTimedKeys();
        if (_timedTimes.isEmpty) {
          await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
          await _$deleteTimedImages(_storedTimes);
          try {
            await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'StreakHomeWidgetReceiver');
          } catch (error, stackTrace) {
            // Cancelling is best effort; the data was deleted.
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'home_widget',
                context: ErrorDescription('cancelling scheduled updates for the Streak widget'),
              ),
            );
          }
          return;
        }
        final _timedJson = <String, dynamic>{};
        for (final _time in _timedTimes) {
          final _millis = _time.toUtc().millisecondsSinceEpoch;
          final _entry = timedData[_time]!;
          final _values = _entry.toJson();
          final _timedImage_mascot = _timedImages_mascot[_time];
          if (_timedImage_mascot != null) {
            _values['mascot'] = await _$saveImage('${_$paramPrefix}.timedData.mascot.$_millis', _timedImage_mascot);
          } else if (_storedTimes.contains(_millis)) {
            await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.timedData.mascot.$_millis', null, appGroupId: _$appGroupId);
          }
          _timedJson[_millis.toString()] = _values;
        }
        await HomeWidget.saveFile('${_$paramPrefix}.timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json', appGroupId: _$appGroupId);
        await _$deleteTimedImages(_storedTimes.where((_millis) => !_timedJson.containsKey(_millis.toString())));
        try {
          await HomeWidget.scheduleWidgetUpdates(_timedTimes, androidName: 'StreakHomeWidgetReceiver');
        } catch (error, stackTrace) {
          // Scheduling is best effort; the data was saved.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'home_widget',
              context: ErrorDescription('scheduling updates for the Streak widget'),
            ),
          );
        }
      }(),
    ]);
  }

  static Future<void> deleteData({
    bool frozen = false,
    bool streak = false,
    bool completed = false,
    bool timedData = false,
  }) {
    return Future.wait([
      if (frozen) HomeWidget.saveWidgetData('${_$paramPrefix}.frozen', null, appGroupId: _$appGroupId),
      if (streak) HomeWidget.saveWidgetData('${_$paramPrefix}.streak', null, appGroupId: _$appGroupId),
      if (completed) HomeWidget.saveWidgetData('${_$paramPrefix}.completed', null, appGroupId: _$appGroupId),
      if (timedData) () async {
        final _storedTimes = await _$storedTimedKeys();
        await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
        await _$deleteTimedImages(_storedTimes);
        try {
          await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'StreakHomeWidgetReceiver');
        } catch (error, stackTrace) {
          // Cancelling is best effort; the data was deleted.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'home_widget',
              context: ErrorDescription('cancelling scheduled updates for the Streak widget'),
            ),
          );
        }
      }(),
    ]);
  }

  /// Reads every stored value back.
  ///
  /// The keys of [timedData] are local-time [DateTime]s, so they compare equal to a
  /// local [DateTime] for the same instant. Timestamps are stored as epoch
  /// milliseconds: sub-millisecond precision of the saved keys is not preserved.
  /// Keys are compared by instant, so a local [DateTime] and its `toUtc()` twin
  /// denote the same entry and only one of them survives a save.
  static Future<({bool? frozen, int? streak, bool? completed, Map<DateTime, StreakTimedData>? timedData})> getData() async {
    final _timedDataPath = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.timedData', appGroupId: _$appGroupId);
    Map<DateTime, StreakTimedData>? timedData;
    if (_timedDataPath != null) {
      try {
        final raw = await File(_timedDataPath).readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final entries = <DateTime, StreakTimedData>{};
          for (final entry in decoded.entries) {
            final millis = int.tryParse(entry.key);
            if (millis == null) continue;
            final value = entry.value;
            entries[DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal()] = StreakTimedData.fromJson(value is Map<String, dynamic> ? value : null);
          }
          timedData = entries;
        }
      } on Exception {
        timedData = null;
      }
    }
    return (
      frozen: await HomeWidget.getWidgetData<bool>('${_$paramPrefix}.frozen', defaultValue: false, appGroupId: _$appGroupId),
      streak: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.streak', defaultValue: 0, appGroupId: _$appGroupId),
      completed: await HomeWidget.getWidgetData<bool>('${_$paramPrefix}.completed', defaultValue: false, appGroupId: _$appGroupId),
      timedData: timedData,
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'StreakHomeWidgetReceiver',
      iOSName: 'StreakHomeWidget',
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
      androidName: 'StreakHomeWidgetReceiver',
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
      androidName: 'StreakHomeWidgetReceiver',
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
      return androidClassName.endsWith('.StreakHomeWidgetReceiver');
    }
    return info.iOSKind == 'StreakHomeWidget';
  }

  static Future<ImageProvider?> _$readImage(ImageProvider? image) async {
    if (image is! FileImage) return image;
    final path = image.file.path;
    final name = path.substring(path.lastIndexOf('/') + 1);
    if (!name.startsWith('${_$paramPrefix}.') || !name.endsWith('.png')) {
      return image;
    }
    try {
      return MemoryImage(await image.file.readAsBytes());
    } on FileSystemException {
      return null;
    }
  }

  static Future<String> _$saveImage(String key, ImageProvider image) async {
    final path = await HomeWidget.saveImage(key, image, appGroupId: _$appGroupId);
    await FileImage(File(path)).evict();
    return path;
  }

  static Future<List<int>> _$storedTimedKeys() async {
    final path = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.timedData', appGroupId: _$appGroupId);
    if (path == null) return const [];
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      if (decoded is! Map<String, dynamic>) return const [];
      return [
        for (final key in decoded.keys)
          if (int.tryParse(key) case final millis?) millis,
      ];
    } on Exception {
      return const [];
    }
  }

  static Future<void> _$deleteTimedImages(Iterable<int> times) async {
    await Future.wait([
      for (final _millis in times)
        for (final _key in const ['mascot'])
          HomeWidget.saveWidgetData<String>('${_$paramPrefix}.timedData.$_key.$_millis', null, appGroupId: _$appGroupId),
    ]);
  }
}

class StreakTimedData {
  /// The image shown from this entry's timestamp on.
  ///
  /// `saveData` writes it to its own PNG and stores that path in the entry;
  /// `getData` hands it back as a `FileImage` of that PNG.
  final ImageProvider? mascot;
  final String? message;

  const StreakTimedData({
    this.mascot,
    this.message,
  });

  factory StreakTimedData.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return StreakTimedData(
      mascot: _readFileImage(json['mascot']),
      message: _readString(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (message != null) 'message': message,
    };
  }
}

String? _readString(Object? value) => value is String ? value : null;
ImageProvider? _readFileImage(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final file = File(value);
  return file.existsSync() ? FileImage(file) : null;
}
