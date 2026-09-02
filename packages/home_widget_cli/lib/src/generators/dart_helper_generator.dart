import 'package:dart_style/dart_style.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';
import '../models/widget_spec.dart';
import '../util/naming.dart';

/// Generates a Dart helper class with type-safe accessors for widget data.
class DartHelperGenerator {
  /// The widget specification to generate helpers for.
  final WidgetSpec spec;

  /// Creates a new [DartHelperGenerator] for the given [spec].
  DartHelperGenerator(this.spec);

  /// Generates the Dart helper source code.
  ///
  /// The timed-data file this writes — decimal epoch-millis string keys,
  /// each mapping to a flat JSON object of that timestamp's values — must
  /// stay in step with `resolveTimedValues` in android_generator.dart and
  /// `loadTimedEntries` in ios_generator.dart. A root [HWLocalizedString]
  /// field's timed values are written as locale-tag-to-text objects rather
  /// than plain values; the Kotlin and Swift readers must decode them the
  /// same way.
  String generate() {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final timedFields = spec.timedDataFields;
    final hasTimedData = timedFields.isNotEmpty;
    // Timed JSON groups are intentionally absent from [spec.jsonDataGroups]
    // (timed fields live inside the timed data file), but they reuse the exact
    // same generated `*JsonData` classes. The validator forbids sharing a root
    // key between a timed and an untimed field, so class names never collide.
    final timedJsonGroups = spec.timedJsonDataGroups;
    final timedClass = '${spec.className}TimedData';
    final timedImages = spec.timedImageFields;
    final jsonImages = spec.jsonImageFields;
    final timedJsonImages = spec.timedJsonImageFields;
    // Every timed image key is namespaced by its timestamp, so the timed save
    // path and its pruning cover the JSON leaves of a timed group too.
    final allTimedImageKeys = <String>[
      for (final image in timedImages) image.key,
      for (final image in timedJsonImages) image.storageKey,
    ];
    final hasImageFields = spec.hasRuntimeImages;
    final hasDataFields =
        primitiveFields.isNotEmpty || jsonGroups.isNotEmpty || hasTimedData;
    final appGroupId = spec.data.iOS?.groupId;
    final usesAppGroupId = hasDataFields && appGroupId != null;

    final receiverName = '${spec.className}HomeWidgetReceiver';
    final String androidName;
    final bool androidNameIsQualified;
    if (spec.data.android != null && spec.data.android!.packageName != null) {
      androidName = '${spec.data.android!.packageName}.$receiverName';
      androidNameIsQualified = true;
    } else {
      androidName = receiverName;
      androidNameIsQualified = false;
    }
    final String androidNameArg = androidNameIsQualified
        ? "qualifiedAndroidName: '$androidName'"
        : "androidName: '$androidName'";

    final buffer = StringBuffer();
    buffer.writeln('// dart format off');
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();
    if (spec.hasWidgetUrl) {
      buffer.writeln("import 'dart:async';");
    }
    // Localized fields store their translations as a single JSON blob, so they
    // need `dart:convert` too — but none of the file plumbing JSON groups use.
    if (jsonGroups.isNotEmpty ||
        _translationFields.isNotEmpty ||
        hasTimedData) {
      buffer.writeln("import 'dart:convert';");
    }
    // `dart:io` carries both the JSON/timed file plumbing and the `Platform`
    // check deciding which platform's widget URL a click has to match.
    if (jsonGroups.isNotEmpty || hasTimedData || spec.hasWidgetUrl) {
      buffer.writeln("import 'dart:io';");
    }
    if (jsonGroups.isNotEmpty && !hasTimedData) {
      buffer.writeln("import 'dart:typed_data';");
    }
    if (hasTimedData) {
      buffer.writeln("import 'package:flutter/foundation.dart';");
    }
    if (hasImageFields) {
      buffer.writeln("import 'package:flutter/widgets.dart';");
    }
    buffer.writeln("import 'package:home_widget/home_widget.dart';");
    buffer.writeln();

    final className = _helperClassName;

    buffer.writeln('class $className {');
    buffer.writeln('  const $className._();');
    buffer.writeln();

    if (hasDataFields) {
      if (usesAppGroupId) {
        buffer.writeln("  static const String _\$appGroupId = '$appGroupId';");
        buffer.writeln();
      }
      buffer.writeln(
        "  static const String _\$paramPrefix = 'home_widget.${spec.className}';",
      );
      buffer.writeln();
      for (final field in _translationFields) {
        _writeDefaultsConstant(buffer, field);
        buffer.writeln();
      }
      buffer.writeln('  static Future<void> saveData({');
      for (final field in primitiveFields) {
        if (field is HWImageData) {
          buffer.writeln('    ImageProvider? ${field.key},');
          continue;
        }
        final type = field is HWLocalizedString
            ? _translationsClassName
            : field.dartType;
        buffer.writeln('    $type? ${field.key},');
      }
      for (final group in jsonGroups) {
        final jsonClass = _dartJsonClassName(group.key);
        buffer.writeln('    $jsonClass? ${group.key},');
      }
      if (hasTimedData) {
        buffer.writeln('    Map<DateTime, $timedClass>? timedData,');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in primitiveFields) {
        if (field is HWImageData) {
          buffer.writeln(
            "      if (${field.key} != null) HomeWidget.saveImage('"
            r"${_$paramPrefix}."
            "${field.key}', ${field.key}${_appGroupIdArg(usesAppGroupId)}),",
          );
          continue;
        }
        if (field is HWLocalizedString) {
          buffer.writeln(
            "      if (${field.key} != null) HomeWidget.saveWidgetData<String>('"
            r"${_$paramPrefix}."
            "${field.key}', jsonEncode(${field.key}.toMap())"
            "${_appGroupIdArg(usesAppGroupId)}),",
          );
          continue;
        }
        final type = field.dartType;
        buffer.writeln(
          "      if (${field.key} != null) HomeWidget.saveWidgetData<$type>('"
          r"${_$paramPrefix}."
          "${field.key}', ${field.key}${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      for (final group in jsonGroups) {
        final images = jsonImages.where((i) => i.rootKey == group.key).toList();
        buffer.writeln('      if (${group.key} != null) () async {');
        final valuesExpr =
            images.isEmpty ? '${group.key}.toJson()' : '_${group.key}Json';
        if (images.isNotEmpty) {
          buffer.writeln(
            '        final $valuesExpr = ${group.key}.toJson();',
          );
          for (final image in images) {
            _writeJsonImageSave(
              buffer,
              indent: '        ',
              image: image,
              objectExpr: group.key,
              ownerNullable: false,
              mapExpr: valuesExpr,
              keyLiteral: r'${_$paramPrefix}.' + image.storageKey,
              usesAppGroupId: usesAppGroupId,
            );
          }
        }
        buffer.writeln(
          "        await HomeWidget.saveFile('"
          r"${_$paramPrefix}."
          "${group.key}', Uint8List.fromList(utf8.encode(jsonEncode($valuesExpr))), extension: 'json'${_appGroupIdArg(usesAppGroupId)});",
        );
        buffer.writeln('      }(),');
      }
      if (hasTimedData) {
        buffer.writeln('      if (timedData != null) () async {');
        buffer.writeln(
          '        final _timedTimes = timedData.keys.toList()..sort();',
        );
        if (allTimedImageKeys.isNotEmpty) {
          // Read before anything is written: the file about to be overwritten
          // is the only record of which per-timestamp images exist.
          buffer.writeln(
            '        final _storedTimes = await _\$storedTimedKeys();',
          );
        }
        buffer.writeln('        if (_timedTimes.isEmpty) {');
        buffer.writeln(
          "          await HomeWidget.saveWidgetData('"
          r"${_$paramPrefix}."
          "timedData', null${_appGroupIdArg(usesAppGroupId)});",
        );
        if (allTimedImageKeys.isNotEmpty) {
          buffer.writeln(
            '          await _\$deleteTimedImages(_storedTimes);',
          );
        }
        _writeGuardedScheduleCall(
          buffer,
          indent: '          ',
          call: 'HomeWidget.cancelScheduledWidgetUpdates($androidNameArg)',
          cancels: true,
        );
        buffer.writeln('          return;');
        buffer.writeln('        }');
        if (allTimedImageKeys.isEmpty) {
          buffer.writeln('        final _timedJson = <String, dynamic>{');
          buffer.writeln('          for (final _time in _timedTimes)');
          buffer.writeln(
            '            _time.toUtc().millisecondsSinceEpoch.toString(): '
            'timedData[_time]!.toJson(),',
          );
          buffer.writeln('        };');
        } else {
          buffer.writeln('        final _timedJson = <String, dynamic>{};');
          buffer.writeln('        for (final _time in _timedTimes) {');
          buffer.writeln(
            '          final _millis = _time.toUtc().millisecondsSinceEpoch;',
          );
          buffer.writeln('          final _entry = timedData[_time]!;');
          buffer.writeln('          final _values = _entry.toJson();');
          for (final image in timedImages) {
            final local = _timedImageLocal(image.key);
            buffer.writeln('          final $local = _entry.${image.key};');
            buffer.writeln('          if ($local != null) {');
            buffer.writeln(
              "            _values['${image.key}'] = "
              "await HomeWidget.saveImage('"
              r"${_$paramPrefix}."
              'timedData.${image.key}.'
              r'$_millis'
              "', $local${_appGroupIdArg(usesAppGroupId)});",
            );
            // A timestamp that keeps its slot but loses its image would
            // otherwise leave the PNG of the previous schedule behind, with
            // nothing left pointing at it.
            buffer.writeln(
              '          } else if (_storedTimes.contains(_millis)) {',
            );
            buffer.writeln(
              "            await HomeWidget.saveWidgetData<String>('"
              r"${_$paramPrefix}."
              'timedData.${image.key}.'
              r'$_millis'
              "', null${_appGroupIdArg(usesAppGroupId)});",
            );
            buffer.writeln('          }');
          }
          for (final image in timedJsonImages) {
            _writeJsonImageSave(
              buffer,
              indent: '          ',
              image: image,
              objectExpr: '_entry.${image.rootKey}',
              ownerNullable: true,
              mapExpr: "(_values['${image.rootKey}']! "
                  'as Map<String, dynamic>)',
              keyLiteral: r'${_$paramPrefix}.timedData.'
                  '${image.storageKey}'
                  r'.$_millis',
              usesAppGroupId: usesAppGroupId,
              deleteGuard: '_storedTimes.contains(_millis)',
            );
          }
          buffer.writeln(
            '          _timedJson[_millis.toString()] = _values;',
          );
          buffer.writeln('        }');
        }
        buffer.writeln(
          "        await HomeWidget.saveFile('"
          r"${_$paramPrefix}."
          "timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json'${_appGroupIdArg(usesAppGroupId)});",
        );
        if (allTimedImageKeys.isNotEmpty) {
          buffer.writeln(
            '        await _\$deleteTimedImages(_storedTimes.where('
            '(_millis) => !_timedJson.containsKey(_millis.toString())));',
          );
        }
        _writeGuardedScheduleCall(
          buffer,
          indent: '        ',
          call:
              'HomeWidget.scheduleWidgetUpdates(_timedTimes, $androidNameArg)',
        );
        buffer.writeln('      }(),');
      }
      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln();

      buffer.writeln('  static Future<void> deleteData({');
      for (final field in primitiveFields) {
        buffer.writeln('    bool ${field.key} = false,');
      }
      for (final group in jsonGroups) {
        buffer.writeln('    bool ${group.key} = false,');
      }
      if (hasTimedData) {
        buffer.writeln('    bool timedData = false,');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in primitiveFields) {
        // Localized fields need no special case: all their translations
        // live in one entry, so clearing that key clears all of them.
        buffer.writeln(
          "      if (${field.key}) HomeWidget.saveWidgetData('"
          r"${_$paramPrefix}."
          "${field.key}', null${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      for (final group in jsonGroups) {
        final images = jsonImages.where((i) => i.rootKey == group.key).toList();
        if (images.isEmpty) {
          buffer.writeln(
            "      if (${group.key}) HomeWidget.saveWidgetData('"
            r"${_$paramPrefix}."
            "${group.key}', null${_appGroupIdArg(usesAppGroupId)}),",
          );
          continue;
        }
        // The blob is only half the group: each image leaf owns a PNG of its
        // own, which clearing the blob key does not reach.
        buffer.writeln('      if (${group.key}) () async {');
        buffer.writeln(
          "        await HomeWidget.saveWidgetData('"
          r"${_$paramPrefix}."
          "${group.key}', null${_appGroupIdArg(usesAppGroupId)});",
        );
        for (final image in images) {
          buffer.writeln(
            "        await HomeWidget.saveWidgetData<String>('"
            r"${_$paramPrefix}."
            "${image.storageKey}', null${_appGroupIdArg(usesAppGroupId)});",
          );
        }
        buffer.writeln('      }(),');
      }
      if (hasTimedData) {
        buffer.writeln('      if (timedData) () async {');
        if (allTimedImageKeys.isNotEmpty) {
          buffer.writeln(
            '        final _storedTimes = await _\$storedTimedKeys();',
          );
        }
        buffer.writeln(
          "        await HomeWidget.saveWidgetData('"
          r"${_$paramPrefix}."
          "timedData', null${_appGroupIdArg(usesAppGroupId)});",
        );
        if (allTimedImageKeys.isNotEmpty) {
          buffer.writeln('        await _\$deleteTimedImages(_storedTimes);');
        }
        _writeGuardedScheduleCall(
          buffer,
          indent: '        ',
          call: 'HomeWidget.cancelScheduledWidgetUpdates($androidNameArg)',
          cancels: true,
        );
        buffer.writeln('      }(),');
      }
      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln();

      final recordFieldParts = <String>[
        ...primitiveFields.map(
          (f) => f is HWLocalizedString
              ? '$_translationsClassName ${f.key}'
              : '${f.dartType}? ${f.key}',
        ),
        ...jsonGroups.map((g) => '${_dartJsonClassName(g.key)}? ${g.key}'),
        if (hasTimedData) 'Map<DateTime, $timedClass>? timedData',
      ];
      final recordFields = recordFieldParts.join(', ');
      final topLevelImages = primitiveFields.whereType<HWImageData>().toList();
      if (_translationFields.isNotEmpty ||
          hasTimedData ||
          topLevelImages.isNotEmpty) {
        buffer.writeln('  /// Reads every stored value back.');
        buffer.writeln('  ///');
      }
      if (_translationFields.isNotEmpty) {
        buffer.writeln(
          '  /// Localized fields come back fully populated: anything stored '
          'by [saveData]',
        );
        buffer.writeln(
          '  /// is merged over the compiled defaults, so every locale always '
          'has text.',
        );
        if (_localizedFields.isNotEmpty) {
          buffer.writeln(
            '  /// To read the raw stored blob instead — to tell an override '
            'apart from a',
          );
          buffer.writeln(
            '  /// shipped default — use `HomeWidget.getWidgetData` on the '
            'preferences key.',
          );
        }
        if (hasTimedData || topLevelImages.isNotEmpty) {
          buffer.writeln('  ///');
        }
      }
      if (hasTimedData) {
        buffer.writeln(
          '  /// The keys of [timedData] are local-time [DateTime]s, so they '
          'compare equal to a',
        );
        buffer.writeln(
          '  /// local [DateTime] for the same instant. Timestamps are stored '
          'as epoch',
        );
        buffer.writeln(
          '  /// milliseconds: sub-millisecond precision of the saved keys is '
          'not preserved.',
        );
        buffer.writeln(
          '  /// Keys are compared by instant, so a local [DateTime] and its '
          '`toUtc()` twin',
        );
        buffer.writeln(
          '  /// denote the same entry and only one of them survives a save.',
        );
      }
      if (topLevelImages.isNotEmpty) {
        if (hasTimedData) {
          buffer.writeln('  ///');
        }
        final names = topLevelImages.map((f) => '[${f.key}]').join(', ');
        buffer.writeln(
          '  /// $names ${topLevelImages.length == 1 ? 'comes' : 'come'} back '
          'as the file path of the PNG',
        );
        buffer.writeln(
          '  /// `saveData` wrote, not as an `ImageProvider`, and the file it '
          'points at may',
        );
        buffer.writeln(
          '  /// since have been removed. Nested and timed images are handed '
          'back as an',
        );
        buffer.writeln('  /// `ImageProvider` instead.');
      }
      buffer.writeln(
        '  static Future<({$recordFields})> getData() async {',
      );
      for (final group in jsonGroups) {
        final jsonClass = _dartJsonClassName(group.key);
        buffer.writeln(
          "    final _${group.key}Path = await HomeWidget.getWidgetData<String>('"
          r"${_$paramPrefix}."
          "${group.key}'${_appGroupIdArg(usesAppGroupId)});",
        );
        buffer.writeln('    $jsonClass? ${group.key};');
        buffer.writeln('    if (_${group.key}Path != null) {');
        buffer.writeln('      try {');
        buffer.writeln(
          '        final raw = await File(_${group.key}Path).readAsString();',
        );
        buffer.writeln(
          '        final decoded = jsonDecode(raw);',
        );
        buffer.writeln(
          '        if (decoded is Map<String, dynamic>) ${group.key} = $jsonClass.fromJson(decoded);',
        );
        buffer.writeln('      } on Exception {');
        buffer.writeln('        ${group.key} = null;');
        buffer.writeln('      }');
        buffer.writeln('    }');
      }
      if (hasTimedData) {
        buffer.writeln(
          "    final _timedDataPath = await HomeWidget.getWidgetData<String>('"
          r"${_$paramPrefix}."
          "timedData'${_appGroupIdArg(usesAppGroupId)});",
        );
        buffer.writeln('    Map<DateTime, $timedClass>? timedData;');
        buffer.writeln('    if (_timedDataPath != null) {');
        buffer.writeln('      try {');
        buffer.writeln(
          '        final raw = await File(_timedDataPath).readAsString();',
        );
        buffer.writeln('        final decoded = jsonDecode(raw);');
        buffer.writeln('        if (decoded is Map<String, dynamic>) {');
        buffer.writeln('          final entries = <DateTime, $timedClass>{};');
        buffer.writeln('          for (final entry in decoded.entries) {');
        buffer.writeln(
          '            final millis = int.tryParse(entry.key);',
        );
        buffer.writeln('            if (millis == null) continue;');
        buffer.writeln('            final value = entry.value;');
        buffer.writeln(
          '            entries[DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal()] = '
          '$timedClass.fromJson(value is Map<String, dynamic> ? value : null);',
        );
        buffer.writeln('          }');
        buffer.writeln('          timedData = entries;');
        buffer.writeln('        }');
        buffer.writeln('      } on Exception {');
        buffer.writeln('        timedData = null;');
        buffer.writeln('      }');
        buffer.writeln('    }');
      }
      buffer.writeln('    return (');
      for (final field in primitiveFields) {
        if (field is HWLocalizedString) {
          buffer.writeln(
            "      ${field.key}: _\$mergeTranslations(${_defaultsFieldName(field)}, "
            "await _\$readLocalized('"
            r"${_$paramPrefix}."
            "${field.key}')),",
          );
          continue;
        }
        final type = field.dartType;
        final defaultValue = field.defaultValue;
        var defaultLiteral = '';
        if (defaultValue != null) {
          defaultLiteral = defaultValue is String
              ? ", defaultValue: '${escapeDartStringLiteral(defaultValue)}'"
              : ', defaultValue: $defaultValue';
        }
        buffer.writeln(
          "      ${field.key}: await HomeWidget.getWidgetData<$type>('"
          r"${_$paramPrefix}."
          "${field.key}'$defaultLiteral${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      for (final group in jsonGroups) {
        buffer.writeln('      ${group.key}: ${group.key},');
      }
      if (hasTimedData) {
        buffer.writeln('      timedData: timedData,');
      }
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln();
    buffer.writeln('  static Future<bool?> updateWidget() {');

    final iosName =
        spec.data.iOS != null ? '${spec.className}HomeWidget' : null;

    buffer.writeln('    return HomeWidget.updateWidget(');
    buffer.writeln('      $androidNameArg,');
    if (iosName != null) {
      buffer.writeln("      iOSName: '$iosName',");
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    if (spec.hasWidgetUrl) {
      buffer.writeln();
      _writeLaunchHelpers(buffer);
    }
    if (allTimedImageKeys.isNotEmpty) {
      buffer.writeln();
      _writeTimedImageHelpers(buffer, allTimedImageKeys, usesAppGroupId);
    }
    if (_localizedFields.isNotEmpty) {
      buffer.writeln();
      _writeLocalizedReader(buffer, usesAppGroupId);
    }
    if (_translationFields.isNotEmpty) {
      buffer.writeln();
      _writeTranslationsMerger(buffer);
    }

    buffer.writeln('}');

    if (_translationFields.isNotEmpty) {
      buffer.writeln();
      _writeTranslationsClass(buffer);
    }

    if (hasTimedData) {
      buffer.writeln();
      _writeDartTimedDataClass(
        buffer: buffer,
        className: timedClass,
        timedFields: timedFields,
      );
    }

    for (final group in [...jsonGroups, ...timedJsonGroups]) {
      final jsonClass = _dartJsonClassName(group.key);
      final tree = _buildJsonTree(group.children);
      buffer.writeln();
      _writeDartJsonNodeClass(
        buffer: buffer,
        className: jsonClass,
        node: tree,
        isRoot: true,
      );
    }
    final usedReaders = <String>{
      for (final group in [...jsonGroups, ...timedJsonGroups])
        for (final field in group.children) _dartReadFunction(field.type),
      for (final member in _timedMembers(timedFields))
        if (!member.jsonRoot) _dartTimedReadFunction(member.leafType!),
    };
    if (usedReaders.isNotEmpty) {
      buffer.writeln();
      _writeDartJsonReaders(buffer, usedReaders);
    }

    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(buffer.toString());
  }

  /// Keyed localized strings, stored as one JSON blob of locale tag to text
  /// under a preferences key of their own.
  ///
  /// Shared with the native generators so the Dart API cannot drift from the
  /// keys they read.
  List<HWLocalizedString> get _localizedFields => spec.keyedLocalizedStrings;

  /// Every localized string the generated Dart API hands out as a translations
  /// object, whether it is stored under its own key or inside a timed entry.
  ///
  /// Both flavours need the compiled defaults and the merger: the difference is
  /// only which reader supplies the stored map.
  List<HWLocalizedString> get _translationFields =>
      [..._localizedFields, ...spec.timedLocalizedStrings];

  String get _helperClassName => '${spec.className}HomeWidget';

  List<String> get _supportedLocales =>
      spec.data.localization?.supportedLocales ?? const <String>[];

  String get _translationsClassName =>
      '${spec.className}HomeWidgetTranslations';

  /// The identifier of the field holding [field]'s compiled translations. One
  /// per keyed string, since a widget may declare several.
  String _defaultsFieldName(HWLocalizedString field) => '${field.key}Defaults';

  /// The compiled translations for one keyed string, exposed on the helper
  /// class so callers can read the shipped text without going through
  /// `getData`.
  void _writeDefaultsConstant(StringBuffer buffer, HWLocalizedString field) {
    buffer.writeln(
      '  /// The translations compiled into the widget for `${field.key}`.',
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// `getData` merges anything stored by `saveData` over these, so a',
    );
    buffer.writeln(
      '  /// locale the app never pushed still resolves to shipped text.',
    );
    buffer.writeln(
      '  static const $_translationsClassName ${_defaultsFieldName(field)} =',
    );
    buffer.writeln('      $_translationsClassName(');
    for (final locale in _supportedLocales) {
      final value = field.defaultTranslations[locale] ?? '';
      buffer.writeln(
        '        ${localeIdentifier(locale)}: '
        "'${escapeDartStringLiteral(value)}',",
      );
    }
    buffer.writeln('      );');
  }

  /// Merges a stored translation blob over the compiled defaults.
  void _writeTranslationsMerger(StringBuffer buffer) {
    buffer.writeln(
      '  static $_translationsClassName _\$mergeTranslations(',
    );
    buffer.writeln('    $_translationsClassName defaults,');
    buffer.writeln('    Map<String, String>? stored,');
    buffer.writeln('  ) {');
    buffer.writeln('    if (stored == null) return defaults;');
    buffer.writeln('    return $_translationsClassName(');
    for (final locale in _supportedLocales) {
      final identifier = localeIdentifier(locale);
      buffer.writeln(
        "      $identifier: stored['${escapeDartStringLiteral(locale)}'] "
        '?? defaults.$identifier,',
      );
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  /// Emits the save (and clear) of one image sitting at the leaf of a JSON
  /// group, into the group's already-serialized map.
  ///
  /// [objectExpr] names the object the group's data hangs off — the `saveData`
  /// parameter itself, or the timed entry — and [ownerNullable] says whether
  /// the first hop off it can be null. [mapExpr] is the map `toJson` produced
  /// for that group; every ancestor map along the path is guaranteed to be
  /// there whenever the image is non-null, because the same objects had to be
  /// non-null for it to be reachable.
  ///
  /// [deleteGuard], when set, narrows the clear-out of a missing image to the
  /// keys that can actually hold a file (the timed case, where a key exists per
  /// timestamp rather than once).
  void _writeJsonImageSave(
    StringBuffer buffer, {
    required String indent,
    required JsonImageField image,
    required String objectExpr,
    required bool ownerNullable,
    required String mapExpr,
    required String keyLiteral,
    required bool usesAppGroupId,
    String? deleteGuard,
  }) {
    final path = image.path;
    final local = _jsonImageLocal(image.storageKey);

    final access = StringBuffer(objectExpr);
    for (var i = 0; i < path.length; i++) {
      access.write(i == 0 && !ownerNullable ? '.' : '?.');
      access.write(path[i]);
    }

    var parentMap = mapExpr;
    for (var i = 0; i < path.length - 1; i++) {
      parentMap = "($parentMap['${path[i]}']! as Map<String, dynamic>)";
    }

    final appGroupArg = _appGroupIdArg(usesAppGroupId);
    buffer.writeln('${indent}final $local = $access;');
    buffer.writeln('${indent}if ($local != null) {');
    buffer.writeln(
      "$indent  $parentMap['${path.last}'] = "
      "await HomeWidget.saveImage('$keyLiteral', $local$appGroupArg);",
    );
    buffer.writeln(
      deleteGuard == null
          ? '$indent} else {'
          : '$indent} else if ($deleteGuard) {',
    );
    buffer.writeln(
      "$indent  await HomeWidget.saveWidgetData<String>('$keyLiteral', "
      'null$appGroupArg);',
    );
    buffer.writeln('$indent}');
  }

  /// Emits the helpers telling the app that the widget was tapped.
  ///
  /// Emitted only for specs configuring a widget URL, which is what makes the
  /// platforms report a click at all.
  void _writeLaunchHelpers(StringBuffer buffer) {
    final urlFields = _widgetUrlFields;

    for (final entry in urlFields.entries) {
      final platform = _widgetUrlPlatform(entry.key);
      buffer.writeln(
        '  /// The URL a tap on the widget opens the app with$platform, as the '
        'app',
      );
      buffer.writeln('  /// will receive it.');
      buffer.writeln('  ///');
      buffer.writeln(
        '  /// The configured `widgetUrl` carrying the `homeWidget` query',
      );
      buffer.writeln(
        '  /// parameter, parsed — so its scheme is lower-cased, exactly like',
      );
      buffer.writeln('  /// the URL handed to the app.');
      buffer.writeln(
        "  static final Uri ${entry.key} = "
        "Uri.parse('${escapeDartStringLiteral(entry.value)}');",
      );
      buffer.writeln();
    }
    buffer.writeln(
      '  /// The URL the app was launched with by a tap on the widget, or null',
    );
    buffer.writeln('  /// when it was started any other way.');
    buffer.writeln('  ///');
    _writeFilterDoc(buffer);
    buffer
        .writeln('  static Future<Uri?> initiallyLaunchedFromWidget() async {');
    buffer.writeln(
      '    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();',
    );
    buffer.writeln('    if (uri == null || !_\$matchesWidgetUrl(uri)) {');
    buffer.writeln('      return null;');
    buffer.writeln('    }');
    buffer.writeln('    return uri;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  /// The URL of every tap on the widget while the app is running.',
    );
    buffer.writeln(
      '  ///',
    );
    buffer.writeln(
      '  /// A tap that started the app in the first place is not replayed here',
    );
    buffer.writeln(
      '  /// — read [initiallyLaunchedFromWidget] for that one, or listen to',
    );
    buffer.writeln('  /// [launchedFromWidget] for both.');
    buffer.writeln('  ///');
    _writeFilterDoc(buffer);
    buffer.writeln('  static Stream<Uri> get widgetClicked =>');
    buffer.writeln('      HomeWidget.widgetClicked');
    buffer.writeln(
      '          .where((uri) => uri != null && _\$matchesWidgetUrl(uri))',
    );
    buffer.writeln('          .cast<Uri>();');
    buffer.writeln();
    buffer.writeln('  /// Every tap on the widget, launch included.');
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// Yields the launch URL first when the app was started by a tap on',
    );
    buffer.writeln(
      '  /// the widget, then every tap that follows while it runs. Taps landing',
    );
    buffer.writeln(
      '  /// while the launch URL is still being read are kept, not dropped.',
    );
    buffer.writeln('  ///');
    _writeFilterDoc(buffer);
    buffer.writeln('  static Stream<Uri> launchedFromWidget() async* {');
    buffer.writeln('    final clicks = StreamController<Uri>();');
    buffer.writeln('    final subscription = HomeWidget.widgetClicked.listen(');
    buffer.writeln('      (uri) {');
    buffer.writeln(
      '        if (uri != null && _\$matchesWidgetUrl(uri)) clicks.add(uri);',
    );
    buffer.writeln('      },');
    buffer.writeln('      onDone: clicks.close,');
    buffer.writeln('    );');
    buffer.writeln('    try {');
    buffer.writeln(
      '      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();',
    );
    buffer.writeln(
      '      if (initial != null && _\$matchesWidgetUrl(initial)) yield initial;',
    );
    buffer.writeln('      yield* clicks.stream;');
    buffer.writeln('    } finally {');
    buffer.writeln('      await subscription.cancel();');
    buffer.writeln('      await clicks.close();');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      "  /// Whether [uri] is the URL this platform's widget opens.",
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// Schemes are compared case-insensitively: the URL reaches the app '
      'parsed,',
    );
    buffer.writeln(
      '  /// which lower-cases the scheme it was written with.',
    );
    buffer.writeln('  static bool _\$matchesWidgetUrl(Uri uri) {');
    buffer.writeln('    final url = _\$platformWidgetUrl;');
    buffer.writeln('    if (url == null) return false;');
    buffer.writeln(
      '    return _\$lowerCaseScheme(uri) == _\$lowerCaseScheme(url);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  /// The URL the widget opens on the platform the app is running on, or',
    );
    buffer.writeln('  /// null where it opens none.');
    buffer.writeln('  static Uri? get _\$platformWidgetUrl {');
    final androidField = urlFields.containsKey('widgetUrl')
        ? 'widgetUrl'
        : urlFields.containsKey('androidWidgetUrl')
            ? 'androidWidgetUrl'
            : null;
    final iosField = urlFields.containsKey('widgetUrl')
        ? 'widgetUrl'
        : urlFields.containsKey('iosWidgetUrl')
            ? 'iosWidgetUrl'
            : null;
    if (androidField != null) {
      buffer.writeln('    if (Platform.isAndroid) return $androidField;');
    }
    if (iosField != null) {
      buffer.writeln('    if (Platform.isIOS) return $iosField;');
    }
    buffer.writeln('    return null;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  static String _\$lowerCaseScheme(Uri uri) {');
    buffer.writeln('    final text = uri.toString();');
    buffer.writeln(
      '    return uri.scheme.toLowerCase() + text.substring(uri.scheme.length);',
    );
    buffer.writeln('  }');
  }

  /// The doc-comment paragraph every launch helper carries, naming what the
  /// emitted filter lets through.
  void _writeFilterDoc(StringBuffer buffer) {
    buffer.writeln(
      '  /// Only the URL this widget opens on the platform the app is running',
    );
    buffer.writeln(
      '  /// on is reported; a tap on any other widget is not.',
    );
    final androidUrl = spec.androidWidgetUrl;
    final iosUrl = spec.iosWidgetUrl;
    final without = androidUrl == null
        ? 'Android'
        : iosUrl == null
            ? 'iOS'
            : null;
    if (without != null) {
      buffer.writeln(
        '  /// Nothing is ever reported on $without, where the widget opens no '
        'URL',
      );
      buffer.writeln('  /// of its own.');
    }
  }

  /// The runtime URLs exposed on the generated class, by field name.
  ///
  /// Both platforms share one field when they open the same URL, which is the
  /// common case; a platform override splits them apart.
  Map<String, String> get _widgetUrlFields {
    final androidUrl = spec.androidWidgetUrl;
    final iosUrl = spec.iosWidgetUrl;
    if (androidUrl != null && androidUrl == iosUrl) {
      return {'widgetUrl': androidUrl};
    }
    return {
      if (androidUrl != null) 'androidWidgetUrl': androidUrl,
      if (iosUrl != null) 'iosWidgetUrl': iosUrl,
    };
  }

  String _widgetUrlPlatform(String fieldName) => switch (fieldName) {
        'androidWidgetUrl' => ' on Android',
        'iosWidgetUrl' => ' on iOS',
        _ => '',
      };

  /// Emits the two helpers that keep per-timestamp image files in step with the
  /// timeline.
  ///
  /// The timestamps of the stored timeline are the only record of which images
  /// exist: each one was written under `<prefix>.timedData.<field>.<millis>`,
  /// so clearing that key deletes both the preferences entry and the PNG.
  /// [imageKeys] holds the `<field>` part of every timed image, a JSON group's
  /// dotted leaf paths included.
  void _writeTimedImageHelpers(
    StringBuffer buffer,
    List<String> imageKeys,
    bool usesAppGroupId,
  ) {
    buffer.writeln('  static Future<List<int>> _\$storedTimedKeys() async {');
    buffer.writeln(
      "    final path = await HomeWidget.getWidgetData<String>('"
      r"${_$paramPrefix}."
      "timedData'${_appGroupIdArg(usesAppGroupId)});",
    );
    buffer.writeln('    if (path == null) return const [];');
    buffer.writeln('    try {');
    buffer.writeln(
      '      final decoded = jsonDecode(await File(path).readAsString());',
    );
    buffer.writeln(
      '      if (decoded is! Map<String, dynamic>) return const [];',
    );
    buffer.writeln('      return [');
    buffer.writeln('        for (final key in decoded.keys)');
    buffer
        .writeln('          if (int.tryParse(key) case final millis?) millis,');
    buffer.writeln('      ];');
    buffer.writeln('    } on Exception {');
    buffer.writeln('      return const [];');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  static Future<void> _\$deleteTimedImages(Iterable<int> times) async {',
    );
    buffer.writeln('    await Future.wait([');
    buffer.writeln('      for (final _millis in times)');
    final keys = imageKeys.map((key) => "'$key'").join(', ');
    buffer.writeln('        for (final _key in const [$keys])');
    buffer.writeln(
      "          HomeWidget.saveWidgetData<String>('"
      r"${_$paramPrefix}.timedData.$_key.$_millis"
      "', null${_appGroupIdArg(usesAppGroupId)}),",
    );
    buffer.writeln('    ]);');
    buffer.writeln('  }');
  }

  /// Reads the stored translation blob for [key] back into a raw map, which
  /// `getData` then merges over the compiled defaults.
  ///
  /// Mirrors the leniency of the native readers — anything that is not a JSON
  /// object of strings reads back as null instead of throwing.
  void _writeLocalizedReader(StringBuffer buffer, bool usesAppGroupId) {
    buffer.writeln(
      '  static Future<Map<String, String>?> _\$readLocalized(String key) async {',
    );
    buffer.writeln(
      "    final raw = await HomeWidget.getWidgetData<String>(key"
      '${_appGroupIdArg(usesAppGroupId)});',
    );
    buffer.writeln('    if (raw == null) return null;');
    buffer.writeln('    Object? decoded;');
    buffer.writeln('    try {');
    buffer.writeln('      decoded = jsonDecode(raw);');
    buffer.writeln('    } on FormatException {');
    buffer.writeln('      return null;');
    buffer.writeln('    }');
    buffer.writeln('    if (decoded is! Map) return null;');
    buffer.writeln('    final values = <String, String>{};');
    buffer.writeln('    decoded.forEach((locale, value) {');
    buffer.writeln(
      '      if (locale is String && value is String) values[locale] = value;',
    );
    buffer.writeln('    });');
    buffer.writeln('    return values.isEmpty ? null : values;');
    buffer.writeln('  }');
  }

  /// A translation set for one string, with every supported locale required so
  /// that adding a locale becomes a compile error until it is translated.
  void _writeTranslationsClass(StringBuffer buffer) {
    final locales = _supportedLocales;
    buffer.writeln('class $_translationsClassName {');
    buffer.writeln('  const $_translationsClassName({');
    for (final locale in locales) {
      buffer.writeln('    required this.${localeIdentifier(locale)},');
    }
    buffer.writeln('  });');
    buffer.writeln();
    for (final locale in locales) {
      buffer.writeln('  final String ${localeIdentifier(locale)};');
    }
    buffer.writeln();
    buffer.writeln('  Map<String, String> toMap() => {');
    for (final locale in locales) {
      buffer.writeln("        '$locale': ${localeIdentifier(locale)},");
    }
    buffer.writeln('      };');
    buffer.writeln();
    _writeResolve(buffer);
    buffer.writeln('}');
  }

  /// `resolve(tag)` — the widget's own matching chain, for one explicit tag.
  ///
  /// Must stay in step with `hwResolveLocalized` in the Kotlin and Swift
  /// helpers, or a preview would disagree with what the widget renders.
  void _writeResolve(StringBuffer buffer) {
    final baseIdentifier = _baseLocaleIdentifier;
    buffer.writeln(
      '  /// The text this set resolves to for the BCP-47 locale [tag].',
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// Tries the exact tag (`pt-PT`), then the tag with its last subtag',
    );
    buffer.writeln(
      '  /// dropped, and so on down to the bare language (`zh-Hant-TW` →',
    );
    buffer.writeln(
      '  /// `zh-Hant` → `zh`), then any entry with the same language but a',
    );
    buffer.writeln(
      '  /// different region or script (`pt-BR`; the lexicographically',
    );
    buffer.writeln(
      "  /// smallest wins if several match), and finally the widget's default",
    );
    buffer.writeln(
      '  /// locale. Matching is case-insensitive, and `_` is treated as `-`.',
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// The widget natively runs these same steps against *every* entry',
    );
    buffer.writeln(
      "  /// of the OS preferred-language list in order; this answers for one",
    );
    buffer.writeln(
      '  /// explicit tag, which is what previews and tests need.',
    );
    buffer.writeln('  String resolve(String tag) {');
    // Tags are case-insensitive per BCP-47, so both sides fold to lower case.
    // The native resolvers only ever see canonically cased tags, so folding
    // here cannot conflate two genuinely different tags.
    buffer.writeln('    final values = {');
    buffer.writeln('      for (final entry in toMap().entries)');
    buffer.writeln('        entry.key.toLowerCase(): entry.value,');
    buffer.writeln('    };');
    buffer.writeln(
      "    final normalized = tag.replaceAll('_', '-').toLowerCase();",
    );
    if (baseIdentifier == null) {
      buffer.writeln("    return values[normalized] ?? '';");
      buffer.writeln('  }');
      return;
    }
    // Progressive truncation: zh-Hant-TW -> zh-Hant -> zh.
    buffer.writeln('    var candidate = normalized;');
    buffer.writeln('    while (true) {');
    buffer.writeln('      final match = values[candidate];');
    buffer.writeln('      if (match != null) return match;');
    buffer.writeln("      final cut = candidate.lastIndexOf('-');");
    buffer.writeln('      if (cut <= 0) break;');
    buffer.writeln('      candidate = candidate.substring(0, cut);');
    buffer.writeln('    }');
    buffer.writeln('    final language = candidate;');
    buffer.writeln('    String? sibling;');
    buffer.writeln('    for (final key in values.keys) {');
    buffer.writeln("      if (key.split('-').first != language) continue;");
    buffer.writeln(
      '      if (sibling == null || key.compareTo(sibling) < 0) sibling = key;',
    );
    buffer.writeln('    }');
    buffer.writeln('    if (sibling != null) {');
    buffer.writeln('      final match = values[sibling];');
    buffer.writeln('      if (match != null) return match;');
    buffer.writeln('    }');
    buffer.writeln('    return $baseIdentifier;');
    buffer.writeln('  }');
  }

  /// The field holding the widget's default-locale text, or null when there is
  /// no usable default locale.
  String? get _baseLocaleIdentifier {
    final locales = _supportedLocales;
    if (locales.isEmpty) return null;
    final defaultLocale = spec.data.localization?.defaultLocale;
    if (defaultLocale != null && locales.contains(defaultLocale)) {
      return localeIdentifier(defaultLocale);
    }
    return localeIdentifier(locales.first);
  }

  /// Emits an `await`ed scheduling [call] wrapped in a try/catch.
  ///
  /// Scheduling widget updates is a side effect of persisting timed data; a
  /// platform failure there (missing permission, unavailable alarm manager,
  /// no plugin implementation on the host platform) must never make the
  /// `saveData`/`deleteData` future report a failed write.
  ///
  /// Set [cancels] on the paths that take the timeline away again, so the
  /// emitted comment and error context describe what actually happened.
  void _writeGuardedScheduleCall(
    StringBuffer buffer, {
    required String indent,
    required String call,
    bool cancels = false,
  }) {
    final comment = cancels
        ? '// Cancelling is best effort; the data was deleted.'
        : '// Scheduling is best effort; the data was saved.';
    final description = cancels
        ? 'cancelling scheduled updates for the ${spec.className} widget'
        : 'scheduling updates for the ${spec.className} widget';
    buffer.writeln('${indent}try {');
    buffer.writeln('$indent  await $call;');
    buffer.writeln('$indent} catch (error, stackTrace) {');
    buffer.writeln('$indent  $comment');
    buffer.writeln('$indent  FlutterError.reportError(');
    buffer.writeln('$indent    FlutterErrorDetails(');
    buffer.writeln('$indent      exception: error,');
    buffer.writeln('$indent      stack: stackTrace,');
    buffer.writeln("$indent      library: 'home_widget',");
    buffer.writeln(
      "$indent      context: ErrorDescription('$description'),",
    );
    buffer.writeln('$indent    ),');
    buffer.writeln('$indent  );');
    buffer.writeln('$indent}');
  }

  /// Local variable holding the `ImageProvider` of a plain timed image.
  ///
  /// Kept in a namespace of its own, and separate from [_jsonImageLocal], so no
  /// pair of image fields in one save loop can derive the same name.
  String _timedImageLocal(String key) => '_timedImage_$key';

  /// Local variable holding the `ImageProvider` of an image at a JSON leaf.
  ///
  /// The dotted storage key is unambiguous by construction, so mapping its
  /// separators to `_` keeps distinct leaves distinct.
  String _jsonImageLocal(String storageKey) =>
      '_jsonImage_${storageKey.replaceAll(RegExp('[^A-Za-z0-9]'), '_')}';

  String _appGroupIdArg(bool usesAppGroupId) =>
      usesAppGroupId ? r', appGroupId: _$appGroupId' : '';

  String _dartJsonClassName(String key) => '${toPascalCase(key)}JsonData';

  _JsonPathNode _buildJsonTree(List<JsonDataField> fields) {
    final root = _JsonPathNode();
    for (final field in fields) {
      var node = root;
      for (final segment in field.path) {
        node = node.children.putIfAbsent(segment, _JsonPathNode.new);
      }
      node.leafType = field.type;
    }
    return root;
  }

  void _writeDartJsonNodeClass({
    required StringBuffer buffer,
    required String className,
    required _JsonPathNode node,
    required bool isRoot,
  }) {
    buffer.writeln('class $className {');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final leaf = child.leafType!;
        if (leaf is HWImageData) {
          buffer.writeln('  /// The image stored at this leaf.');
          buffer.writeln('  ///');
          buffer.writeln(
            '  /// `saveData` writes it to its own PNG and puts that path in '
            'the blob;',
          );
          buffer.writeln(
            '  /// `getData` hands it back as a `FileImage` of that PNG.',
          );
          buffer.writeln('  final ImageProvider? $key;');
          continue;
        }
        buffer.writeln('  final ${leaf.dartType}? $key;');
      } else {
        final childClass = _dartChildClassName(className, key);
        buffer.writeln('  final $childClass? $key;');
      }
    }
    buffer.writeln();
    buffer.writeln('  const $className({');
    for (final key in node.children.keys) {
      buffer.writeln('    this.$key,');
    }
    buffer.writeln('  });');
    buffer.writeln();
    buffer
        .writeln('  factory $className.fromJson(Map<String, dynamic>? json) {');
    buffer.writeln('    json ??= const {};');
    buffer.writeln('    return $className(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final fallback = _dartDefaultLiteral(child.leafType!);
        buffer.writeln(
          "      $key: ${_dartReadFunction(child.leafType!)}(json['$key'])$fallback,",
        );
      } else {
        final childClass = _dartChildClassName(className, key);
        buffer.writeln(
          "      $key: json['$key'] is Map<String, dynamic> ? $childClass.fromJson(json['$key'] as Map<String, dynamic>) : null,",
        );
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType is HWImageData && child.children.isEmpty) {
        // Deliberately absent: only `saveData` knows the path this image's PNG
        // was written to, and it puts it into this map afterwards.
        continue;
      }
      if (child.leafType != null && child.children.isEmpty) {
        buffer.writeln("      if ($key != null) '$key': $key,");
      } else {
        buffer.writeln("      if ($key != null) '$key': $key!.toJson(),");
      }
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');

    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.children.isNotEmpty || child.leafType == null) {
        buffer.writeln();
        final childClass = _dartChildClassName(className, key);
        _writeDartJsonNodeClass(
          buffer: buffer,
          className: childClass,
          node: child,
          isRoot: false,
        );
      }
    }
  }

  /// Members of the generated `<ClassName>TimedData` class, in declaration
  /// order, with JSON root keys collapsed to a single member.
  List<_TimedMember> _timedMembers(List<HWTimedData<dynamic>> timedFields) {
    final members = <_TimedMember>[];
    for (final timed in timedFields) {
      final field = timed.data;
      if (field is HWJson) {
        if (members.any((m) => m.key == field.key)) continue;
        members.add(
          _TimedMember(
            key: field.key,
            type: _dartJsonClassName(field.key),
            jsonRoot: true,
          ),
        );
      } else {
        if (members.any((m) => m.key == field.key)) continue;
        members.add(
          _TimedMember(
            key: field.key,
            // A localized value is a locale map, not a string: the member has
            // to be the translations class so `saveData` cannot be handed the
            // text of a single unnamed locale. An image is handed over as an
            // ImageProvider and only its saved path reaches the entry's JSON.
            type: field is HWLocalizedString
                ? _translationsClassName
                : field is HWImageData
                    ? 'ImageProvider'
                    : field.dartType,
            jsonRoot: false,
            leafType: field,
          ),
        );
      }
    }
    return members;
  }

  void _writeDartTimedDataClass({
    required StringBuffer buffer,
    required String className,
    required List<HWTimedData<dynamic>> timedFields,
  }) {
    final members = _timedMembers(timedFields);

    buffer.writeln('class $className {');
    for (final member in members) {
      if (member.isImage) {
        buffer.writeln(
          '  /// The image shown from this entry\'s timestamp on.',
        );
        buffer.writeln('  ///');
        buffer.writeln(
          '  /// `saveData` writes it to its own PNG and stores that path in '
          'the entry;',
        );
        buffer.writeln(
          '  /// `getData` hands it back as a `FileImage` of that PNG.',
        );
      }
      buffer.writeln('  final ${member.type}? ${member.key};');
    }
    buffer.writeln();
    buffer.writeln('  const $className({');
    for (final member in members) {
      buffer.writeln('    this.${member.key},');
    }
    buffer.writeln('  });');
    buffer.writeln();
    buffer
        .writeln('  factory $className.fromJson(Map<String, dynamic>? json) {');
    buffer.writeln('    json ??= const {};');
    buffer.writeln('    return $className(');
    for (final member in members) {
      final key = member.key;
      final leafType = member.leafType;
      if (member.jsonRoot) {
        buffer.writeln(
          "      $key: json['$key'] is Map<String, dynamic> ? ${member.type}.fromJson(json['$key'] as Map<String, dynamic>) : null,",
        );
      } else if (member.isImage) {
        buffer.writeln("      $key: _readFileImage(json['$key']),");
      } else if (leafType is HWLocalizedString) {
        // Same merge as `getData` runs on an untimed field, so an entry that
        // carries only some locales still reads back complete.
        buffer.writeln(
          "      $key: $_helperClassName._\$mergeTranslations("
          '$_helperClassName.${_defaultsFieldName(leafType)}, '
          "_readTranslations(json['$key'])),",
        );
      } else {
        final fallback = _dartDefaultLiteral(leafType!);
        buffer.writeln(
          "      $key: ${_dartReadFunction(leafType)}(json['$key'])$fallback,",
        );
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final member in members) {
      final key = member.key;
      // Images are deliberately absent: only `saveData` knows the path an
      // entry's PNG was written to, and it adds it to this map afterwards.
      if (member.isImage) continue;
      if (member.jsonRoot) {
        buffer.writeln("      if ($key != null) '$key': $key!.toJson(),");
      } else if (member.leafType is HWLocalizedString) {
        // Every locale travels in the entry; the native readers merge it over
        // the compiled translations again on the other side.
        buffer.writeln("      if ($key != null) '$key': $key!.toMap(),");
      } else {
        buffer.writeln("      if ($key != null) '$key': $key,");
      }
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  /// Emits only the `_read*` helpers in [usedReaders] so generated files never
  /// contain unused private functions (which trip `unused_element`).
  void _writeDartJsonReaders(StringBuffer buffer, Set<String> usedReaders) {
    if (usedReaders.contains('_readString')) {
      buffer.writeln(
        'String? _readString(Object? value) => value is String ? value : null;',
      );
    }
    if (usedReaders.contains('_readInt')) {
      buffer.writeln(
        'int? _readInt(Object? value) => value is num ? value.toInt() : null;',
      );
    }
    if (usedReaders.contains('_readDouble')) {
      buffer.writeln(
        'double? _readDouble(Object? value) => value is num ? value.toDouble() : null;',
      );
    }
    if (usedReaders.contains('_readBool')) {
      buffer.writeln(
        'bool? _readBool(Object? value) => value is bool ? value : null;',
      );
    }
    if (usedReaders.contains('_readFileImage')) {
      // The stored value is the absolute path of the PNG `saveData` wrote; a
      // path whose file is gone reads back as null, like a missing image.
      buffer.writeln('ImageProvider? _readFileImage(Object? value) {');
      buffer.writeln('  if (value is! String || value.isEmpty) return null;');
      buffer.writeln('  final file = File(value);');
      buffer.writeln('  return file.existsSync() ? FileImage(file) : null;');
      buffer.writeln('}');
    }
    if (usedReaders.contains('_readTranslations')) {
      // Lenient in the same way as the native decoders: anything that is not a
      // JSON object of strings reads back as null and leaves the compiled
      // translations in place.
      buffer.writeln('Map<String, String>? _readTranslations(Object? value) {');
      buffer.writeln('  if (value is! Map) return null;');
      buffer.writeln('  final values = <String, String>{};');
      buffer.writeln('  value.forEach((locale, text) {');
      buffer.writeln(
        '    if (locale is String && text is String) values[locale] = text;',
      );
      buffer.writeln('  });');
      buffer.writeln('  return values.isEmpty ? null : values;');
      buffer.writeln('}');
    }
  }

  String _dartReadFunction(HWDataType<dynamic> field) {
    if (field is HWString) return '_readString';
    if (field is HWInt) return '_readInt';
    if (field is HWDouble) return '_readDouble';
    if (field is HWBool) return '_readBool';
    // The stored value is a path; the Dart API hands back the image itself.
    if (field is HWImageData) return '_readFileImage';
    return '_readString';
  }

  /// [_dartReadFunction] for a member of the timed data class.
  ///
  /// Only here does a localized value arrive as its own locale map; at a JSON
  /// leaf it is a plain string, so [_dartReadFunction] must not branch on the
  /// type itself.
  String _dartTimedReadFunction(HWDataType<dynamic> field) =>
      field is HWLocalizedString
          ? '_readTranslations'
          : _dartReadFunction(field);

  String _dartChildClassName(String parentClass, String key) {
    final base = parentClass.endsWith('JsonData')
        ? parentClass.substring(0, parentClass.length - 'JsonData'.length)
        : parentClass;
    return '$base${toPascalCase(key)}JsonData';
  }

  String _dartDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return '';
    if (defaultValue is String) {
      return " ?? '${escapeDartStringLiteral(defaultValue)}'";
    }
    return ' ?? $defaultValue';
  }
}

class _JsonPathNode {
  final Map<String, _JsonPathNode> children = {};
  HWDataType<dynamic>? leafType;
}

/// A single member of the generated `<ClassName>TimedData` class.
class _TimedMember {
  final String key;
  final String type;
  final bool jsonRoot;
  final HWDataType<dynamic>? leafType;

  const _TimedMember({
    required this.key,
    required this.type,
    required this.jsonRoot,
    this.leafType,
  });

  /// Whether this member carries an `ImageProvider` rather than a JSON value.
  bool get isImage => leafType is HWImageData;
}
