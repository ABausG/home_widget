// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

class ImageShowcaseHomeWidget {
  const ImageShowcaseHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.ImageShowcase';

  static Future<void> saveData({
    ImageProvider? picture,
    ContactJsonData? contact,
    Map<DateTime, ImageShowcaseTimedData>? timedData,
  }) {
    return Future.wait([
      if (picture != null) HomeWidget.saveImage('${_$paramPrefix}.picture', picture, appGroupId: _$appGroupId),
      if (contact != null) () async {
        final _contactJson = contact.toJson();
        final _imageContactAvatar = contact.avatar;
        if (_imageContactAvatar != null) {
          _contactJson['avatar'] = await HomeWidget.saveImage('${_$paramPrefix}.contact.avatar', _imageContactAvatar, appGroupId: _$appGroupId);
        } else {
          await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.contact.avatar', null, appGroupId: _$appGroupId);
        }
        await HomeWidget.saveFile('${_$paramPrefix}.contact', Uint8List.fromList(utf8.encode(jsonEncode(_contactJson))), extension: 'json', appGroupId: _$appGroupId);
      }(),
      if (timedData != null) () async {
        final _timedTimes = timedData.keys.toList()..sort();
        final _storedTimes = await _$storedTimedKeys();
        if (_timedTimes.isEmpty) {
          await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
          await _$deleteTimedImages(_storedTimes);
          try {
            await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'ImageShowcaseHomeWidgetReceiver');
          } catch (error, stackTrace) {
            // Scheduling is best effort; the data was saved.
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'home_widget',
                context: ErrorDescription('scheduling updates for the ImageShowcase widget'),
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
          final _imageSlide = _entry.slide;
          if (_imageSlide != null) {
            _values['slide'] = await HomeWidget.saveImage('${_$paramPrefix}.timedData.slide.$_millis', _imageSlide, appGroupId: _$appGroupId);
          } else if (_storedTimes.contains(_millis)) {
            await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.timedData.slide.$_millis', null, appGroupId: _$appGroupId);
          }
          _timedJson[_millis.toString()] = _values;
        }
        await HomeWidget.saveFile('${_$paramPrefix}.timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json', appGroupId: _$appGroupId);
        await _$deleteTimedImages(_storedTimes.where((_millis) => !_timedJson.containsKey(_millis.toString())));
        try {
          await HomeWidget.scheduleWidgetUpdates(_timedTimes, androidName: 'ImageShowcaseHomeWidgetReceiver');
        } catch (error, stackTrace) {
          // Scheduling is best effort; the data was saved.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'home_widget',
              context: ErrorDescription('scheduling updates for the ImageShowcase widget'),
            ),
          );
        }
      }(),
    ]);
  }

  static Future<void> deleteData({
    bool picture = false,
    bool contact = false,
    bool timedData = false,
  }) {
    return Future.wait([
      if (picture) HomeWidget.saveWidgetData('${_$paramPrefix}.picture', null, appGroupId: _$appGroupId),
      if (contact) () async {
        await HomeWidget.saveWidgetData('${_$paramPrefix}.contact', null, appGroupId: _$appGroupId);
        await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.contact.avatar', null, appGroupId: _$appGroupId);
      }(),
      if (timedData) () async {
        final _storedTimes = await _$storedTimedKeys();
        await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
        await _$deleteTimedImages(_storedTimes);
        try {
          await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'ImageShowcaseHomeWidgetReceiver');
        } catch (error, stackTrace) {
          // Scheduling is best effort; the data was saved.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'home_widget',
              context: ErrorDescription('scheduling updates for the ImageShowcase widget'),
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
  static Future<({String? picture, ContactJsonData? contact, Map<DateTime, ImageShowcaseTimedData>? timedData})> getData() async {
    final _contactPath = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.contact', appGroupId: _$appGroupId);
    ContactJsonData? contact;
    if (_contactPath != null) {
      try {
        final raw = await File(_contactPath).readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) contact = ContactJsonData.fromJson(decoded);
      } on Exception {
        contact = null;
      }
    }
    final _timedDataPath = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.timedData', appGroupId: _$appGroupId);
    Map<DateTime, ImageShowcaseTimedData>? timedData;
    if (_timedDataPath != null) {
      try {
        final raw = await File(_timedDataPath).readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final entries = <DateTime, ImageShowcaseTimedData>{};
          for (final entry in decoded.entries) {
            final millis = int.tryParse(entry.key);
            if (millis == null) continue;
            final value = entry.value;
            entries[DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal()] = ImageShowcaseTimedData.fromJson(value is Map<String, dynamic> ? value : null);
          }
          timedData = entries;
        }
      } on Exception {
        timedData = null;
      }
    }
    return (
      picture: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.picture', appGroupId: _$appGroupId),
      contact: contact,
      timedData: timedData,
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'ImageShowcaseHomeWidgetReceiver',
      iOSName: 'ImageShowcaseHomeWidget',
    );
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
        for (final _key in const ['slide'])
          HomeWidget.saveWidgetData<String>('${_$paramPrefix}.timedData.$_key.$_millis', null, appGroupId: _$appGroupId),
    ]);
  }
}

class ImageShowcaseTimedData {
  /// The image shown from this entry's timestamp on.
  ///
  /// `saveData` writes it to its own PNG and stores that path in the entry;
  /// `getData` hands it back as a `FileImage` of that PNG.
  final ImageProvider? slide;

  const ImageShowcaseTimedData({
    this.slide,
  });

  factory ImageShowcaseTimedData.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return ImageShowcaseTimedData(
      slide: _readFileImage(json['slide']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
    };
  }
}

class ContactJsonData {
  /// The image stored at this leaf.
  ///
  /// `saveData` writes it to its own PNG and puts that path in the blob;
  /// `getData` hands it back as a `FileImage` of that PNG.
  final ImageProvider? avatar;
  final String? name;

  const ContactJsonData({
    this.avatar,
    this.name,
  });

  factory ContactJsonData.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return ContactJsonData(
      avatar: _readFileImage(json['avatar']),
      name: _readString(json['name']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
    };
  }
}

String? _readString(Object? value) => value is String ? value : null;
ImageProvider? _readFileImage(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final file = File(value);
  return file.existsSync() ? FileImage(file) : null;
}
