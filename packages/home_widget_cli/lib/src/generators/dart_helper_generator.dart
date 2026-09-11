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
    final jsonGroups = spec.jsonDataGroups;
    // Timed JSON groups are intentionally absent from [spec.jsonDataGroups]
    // (timed fields live inside the timed data file), but they reuse the exact
    // same generated `*JsonData` classes. The validator forbids sharing a root
    // key between a timed and an untimed field, so class names never collide.
    final timedJsonGroups = spec.timedJsonDataGroups;
    final timedFields = spec.timedDataFields;
    final hasTimedData = timedFields.isNotEmpty;
    final className = _helperClassName;
    final iosName = _iosName;

    final imports = <String>[
      if (spec.hasWidgetUrl) "import 'dart:async';",
      // Localized fields store their translations as a single JSON blob, so
      // they need `dart:convert` too — but none of the file plumbing JSON
      // groups use.
      if (jsonGroups.isNotEmpty ||
          _translationFields.isNotEmpty ||
          hasTimedData)
        "import 'dart:convert';",
      // `dart:io` carries both the JSON/timed file plumbing and the `Platform`
      // check deciding which platform's widget URL a click has to match.
      if (jsonGroups.isNotEmpty || hasTimedData || spec.hasWidgetUrl)
        "import 'dart:io';",
      if (jsonGroups.isNotEmpty && !hasTimedData) "import 'dart:typed_data';",
      if (hasTimedData) "import 'package:flutter/foundation.dart';",
      if (_usesAppGroupId && spec.hasFlavors)
        "import 'package:flutter/services.dart';",
      if (spec.hasRuntimeImages) "import 'package:flutter/widgets.dart';",
      "import 'package:home_widget/home_widget.dart';",
    ];

    final buffer = StringBuffer();
    buffer.write('''
// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

''');

    for (final import in imports) {
      buffer.writeln(import);
    }

    buffer.write('''

class $className {
  const $className._();

''');

    if (_hasDataFields) {
      buffer.write(_dataMembers());
    }

    buffer.write('''

  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      $_androidNameArg,
''');

    if (iosName != null) {
      buffer.writeln("      iOSName: '$iosName',");
    }

    buffer.write('''
    );
  }
''');

    if (spec.data.android != null) {
      _appendSection(buffer, _updatePreviewHelper());
      _appendSection(buffer, _pinHelpers());
    }
    _appendSection(buffer, _installHelpers());

    _appendSection(buffer, spec.hasWidgetUrl ? _launchHelpers() : null);
    _appendSection(
      buffer,
      _allTimedImageKeys.isNotEmpty ? _timedImageHelpers() : null,
    );
    _appendSection(
      buffer,
      _localizedFields.isNotEmpty ? _localizedReader() : null,
    );
    _appendSection(
      buffer,
      _translationFields.isNotEmpty ? _translationsMerger() : null,
    );

    buffer.writeln('}');

    _appendSection(
      buffer,
      _translationFields.isNotEmpty ? _translationsClass() : null,
    );

    _appendSection(buffer, hasTimedData ? _timedDataClass(timedFields) : null);

    for (final group in [...jsonGroups, ...timedJsonGroups]) {
      _appendSection(
        buffer,
        _jsonNodeClass(
          className: _dartJsonClassName(group.key),
          node: _buildJsonTree(group.children),
        ),
      );
    }
    final usedReaders = <String>{
      for (final group in [...jsonGroups, ...timedJsonGroups])
        for (final field in group.children) _dartReadFunction(field.type),
      for (final member in _timedMembers(timedFields))
        if (!member.jsonRoot) _dartTimedReadFunction(member.leafType!),
      // A top-level date is stored as a string and parsed back by `getData`
      // through the same reader its JSON and timed spellings use.
      for (final field in spec.primitiveDataFields)
        if (field is HWDateTime) _dartReadFunction(field),
    };
    _appendSection(
      buffer,
      usedReaders.isNotEmpty ? _jsonReaders(usedReaders) : null,
    );

    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(buffer.toString());
  }

  /// Appends [section] to [buffer] on its own blank-line-separated block, or
  /// does nothing when there is none to add.
  void _appendSection(StringBuffer buffer, String? section) {
    if (section == null) return;
    buffer
      ..writeln()
      ..write(section);
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

  /// The WidgetKit kind of this widget, or null where no iOS widget exists.
  String? get _iosName =>
      spec.data.iOS != null ? '${spec.className}HomeWidget' : null;

  /// The Android receiver this widget's helpers name.
  String get _receiverName => '${spec.className}HomeWidgetReceiver';

  /// The argument naming that receiver, qualified where the annotation says
  /// which package it lives in.
  String get _androidNameArg {
    final packageName = spec.data.android?.packageName;
    return packageName == null
        ? "androidName: '$_receiverName'"
        : "qualifiedAndroidName: '$packageName.$_receiverName'";
  }

  /// Whether the widget stores anything at all, and so carries the data
  /// methods.
  bool get _hasDataFields =>
      spec.primitiveDataFields.isNotEmpty ||
      spec.jsonDataGroups.isNotEmpty ||
      spec.timedDataFields.isNotEmpty;

  /// Whether every data call names the App Group it reads and writes through.
  bool get _usesAppGroupId => _hasDataFields && spec.data.iOS?.groupId != null;

  /// Every timed image key is namespaced by its timestamp, so the timed save
  /// path and its pruning cover the JSON leaves of a timed group too.
  List<String> get _allTimedImageKeys => [
        for (final image in spec.timedImageFields) image.key,
        for (final image in spec.timedJsonImageFields) image.storageKey,
      ];

  List<String> get _supportedLocales =>
      spec.data.localization?.supportedLocales ?? const <String>[];

  String get _translationsClassName =>
      '${spec.className}HomeWidgetTranslations';

  String get _timedDataClassName => '${spec.className}TimedData';

  /// The literal the generated code stores [suffix] under: the widget's param
  /// prefix, then the key.
  String _paramKey(String suffix) => "'\${_\$paramPrefix}.$suffix'";

  /// The identifier of the field holding [field]'s compiled translations. One
  /// per keyed string, since a widget may declare several.
  String _defaultsFieldName(HWLocalizedString field) => '${field.key}Defaults';

  /// The App Group constant, the param prefix, the compiled translations and
  /// the three data methods a widget with stored data carries.
  String _dataMembers() {
    final buffer = StringBuffer();
    if (_usesAppGroupId) {
      buffer
        ..write(_appGroupIdDeclaration(spec.data.iOS!.groupId))
        ..writeln();
    }
    buffer.write('''
  static const String _\$paramPrefix = 'home_widget.${spec.className}';

''');
    for (final field in _translationFields) {
      buffer
        ..write(_defaultsConstant(field))
        ..writeln();
    }
    buffer
      ..write(_saveDataMethod())
      ..writeln()
      ..write(_deleteDataMethod())
      ..writeln()
      ..write(_getDataMethod())
      ..writeln();
    return buffer.toString();
  }

  /// Emits the App Group the data calls write to.
  ///
  /// A widget declaring flavors resolves it from the flavor the app was built
  /// with, since one generated helper serves them all; the base group answers
  /// for every other flavor.
  String _appGroupIdDeclaration(String baseGroupId) {
    if (!spec.hasFlavors) {
      return '''
  static const String _\$appGroupId = '$baseGroupId';
''';
    }

    final buffer = StringBuffer();
    buffer.writeln('  static String get _\$appGroupId => switch (appFlavor) {');

    for (final flavor in spec.declaredFlavors) {
      buffer.writeln("    '$flavor' => '${spec.iosGroupIdFor(flavor)}',");
    }

    buffer.write('''
    _ => '$baseGroupId',
  };
''');

    return buffer.toString();
  }

  /// The compiled translations for one keyed string, exposed on the helper
  /// class so callers can read the shipped text without going through
  /// `getData`.
  String _defaultsConstant(HWLocalizedString field) {
    final buffer = StringBuffer();
    buffer.write('''
  /// The translations compiled into the widget for `${field.key}`.
  ///
  /// `getData` merges anything stored by `saveData` over these, so a
  /// locale the app never pushed still resolves to shipped text.
  static const $_translationsClassName ${_defaultsFieldName(field)} =
      $_translationsClassName(
''');

    for (final locale in _supportedLocales) {
      final text = escapeDartStringLiteral(
        field.defaultTranslations[locale] ?? '',
      );
      buffer.writeln("        ${localeIdentifier(locale)}: '$text',");
    }

    buffer.write('''
      );
''');

    return buffer.toString();
  }

  /// The type `saveData` takes for [field]: a translations object for a
  /// localized string, the field's own Dart type otherwise.
  String _saveParameterType(HWDataType<dynamic> field) =>
      field is HWLocalizedString ? _translationsClassName : field.dartType;

  String _saveDataMethod() {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final hasTimedData = spec.timedDataFields.isNotEmpty;

    final parameters = <String>[
      for (final field in primitiveFields)
        if (field is HWImageData)
          '    ImageProvider? ${field.key},'
        else
          '    ${_saveParameterType(field)}? ${field.key},',
      for (final group in jsonGroups)
        '    ${_dartJsonClassName(group.key)}? ${group.key},',
      if (hasTimedData) '    Map<DateTime, $_timedDataClassName>? timedData,',
    ];

    final entries = <String>[
      for (final field in primitiveFields) _primitiveSave(field),
      for (final group in jsonGroups) _jsonGroupSave(group),
      if (hasTimedData) _timedDataSave(),
    ];

    final buffer = StringBuffer();
    buffer.writeln('  static Future<void> saveData({');

    for (final parameter in parameters) {
      buffer.writeln(parameter);
    }

    buffer.write('''
  }) {
    return Future.wait([
''');

    for (final entry in entries) {
      buffer.writeln(entry);
    }

    buffer.write('''
    ]);
  }
''');

    return buffer.toString();
  }

  /// The `saveData` entry writing one top-level field.
  String _primitiveSave(HWDataType<dynamic> field) {
    final key = field.key;
    final keyLiteral = _paramKey(key);
    if (field is HWImageData) {
      return '      if ($key != null) '
          'HomeWidget.saveImage($keyLiteral, $key$_appGroupIdArg),';
    }
    if (field is HWLocalizedString) {
      return '      if ($key != null) HomeWidget.saveWidgetData<String>('
          '$keyLiteral, jsonEncode($key.toMap())$_appGroupIdArg),';
    }
    if (field is HWDateTime) {
      // The wire format is the UTC ISO string the native `hwParseIsoDate`
      // helper reads back.
      return '      if ($key != null) HomeWidget.saveWidgetData<String>('
          '$keyLiteral, ${_dartIsoExpr(key)}$_appGroupIdArg),';
    }
    return '      if ($key != null) '
        'HomeWidget.saveWidgetData<${field.dartType}>('
        '$keyLiteral, $key$_appGroupIdArg),';
  }

  /// A `Future.wait` entry running [body] inside an immediately invoked async
  /// closure, opened by [header].
  String _asyncEntry(String header, List<String> body) {
    final buffer = StringBuffer();
    buffer.writeln(header);

    for (final line in body) {
      buffer.writeln(line);
    }

    buffer.write('      }(),');

    return buffer.toString();
  }

  /// The `saveData` entry writing one JSON group's blob, and the PNG of every
  /// image leaf hanging off it.
  String _jsonGroupSave(JsonDataGroup group) {
    final images =
        spec.jsonImageFields.where((i) => i.rootKey == group.key).toList();
    final valuesExpr =
        images.isEmpty ? '${group.key}.toJson()' : '_${group.key}Json';

    final body = <String>[
      if (images.isNotEmpty) ...[
        '        final $valuesExpr = ${group.key}.toJson();',
        for (final image in images)
          _jsonImageSave(
            indent: '        ',
            image: image,
            objectExpr: group.key,
            ownerNullable: false,
            mapExpr: valuesExpr,
            keyLiteral: _paramKey(image.storageKey),
          ),
      ],
      '        await HomeWidget.saveFile(${_paramKey(group.key)}, '
          'Uint8List.fromList(utf8.encode(jsonEncode($valuesExpr))), '
          "extension: 'json'$_appGroupIdArg);",
    ];

    return _asyncEntry('      if (${group.key} != null) () async {', body);
  }

  /// The `saveData` entry writing the whole timeline, its per-timestamp images
  /// and the platform schedule that renders it.
  String _timedDataSave() {
    final hasTimedImages = _allTimedImageKeys.isNotEmpty;

    final body = <String>[
      '        final _timedTimes = timedData.keys.toList()..sort();',
      // Read before anything is written: the file about to be overwritten is
      // the only record of which per-timestamp images exist.
      if (hasTimedImages)
        '        final _storedTimes = await _\$storedTimedKeys();',
      '        if (_timedTimes.isEmpty) {',
      '          await HomeWidget.saveWidgetData(${_paramKey('timedData')}, '
          'null$_appGroupIdArg);',
      if (hasTimedImages) '          await _\$deleteTimedImages(_storedTimes);',
      _guardedScheduleCall(
        indent: '          ',
        call: 'HomeWidget.cancelScheduledWidgetUpdates($_androidNameArg)',
        cancels: true,
      ),
      '          return;',
      '        }',
      if (!hasTimedImages) ...[
        '        final _timedJson = <String, dynamic>{',
        '          for (final _time in _timedTimes)',
        '            _time.toUtc().millisecondsSinceEpoch.toString(): '
            'timedData[_time]!.toJson(),',
        '        };',
      ] else ...[
        '        final _timedJson = <String, dynamic>{};',
        '        for (final _time in _timedTimes) {',
        '          final _millis = _time.toUtc().millisecondsSinceEpoch;',
        '          final _entry = timedData[_time]!;',
        '          final _values = _entry.toJson();',
        for (final image in spec.timedImageFields) _timedImageSave(image),
        for (final image in spec.timedJsonImageFields)
          _jsonImageSave(
            indent: '          ',
            image: image,
            objectExpr: '_entry.${image.rootKey}',
            ownerNullable: true,
            mapExpr: "(_values['${image.rootKey}']! "
                'as Map<String, dynamic>)',
            keyLiteral: _paramKey('timedData.${image.storageKey}.\$_millis'),
            deleteGuard: '_storedTimes.contains(_millis)',
          ),
        '          _timedJson[_millis.toString()] = _values;',
        '        }',
      ],
      '        await HomeWidget.saveFile(${_paramKey('timedData')}, '
          'Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), '
          "extension: 'json'$_appGroupIdArg);",
      if (hasTimedImages)
        '        await _\$deleteTimedImages(_storedTimes.where('
            '(_millis) => !_timedJson.containsKey(_millis.toString())));',
      _guardedScheduleCall(
        indent: '        ',
        call: 'HomeWidget.scheduleWidgetUpdates(_timedTimes, $_androidNameArg)',
      ),
    ];

    return _asyncEntry('      if (timedData != null) () async {', body);
  }

  /// Saves the image of one timed field, or clears the slot it held before.
  ///
  /// A timestamp that keeps its slot but loses its image would otherwise leave
  /// the PNG of the previous schedule behind, with nothing left pointing at it.
  String _timedImageSave(HWImageData image) {
    final local = _timedImageLocal(image.key);
    final keyLiteral = _paramKey('timedData.${image.key}.\$_millis');
    return '''
          final $local = _entry.${image.key};
          if ($local != null) {
            _values['${image.key}'] = await HomeWidget.saveImage($keyLiteral, $local$_appGroupIdArg);
          } else if (_storedTimes.contains(_millis)) {
            await HomeWidget.saveWidgetData<String>($keyLiteral, null$_appGroupIdArg);
          }''';
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
  String _jsonImageSave({
    required String indent,
    required JsonImageField image,
    required String objectExpr,
    required bool ownerNullable,
    required String mapExpr,
    required String keyLiteral,
    String? deleteGuard,
  }) {
    final path = image.path;
    final local = _jsonImageLocal(image.storageKey);

    final access = [
      objectExpr,
      for (final (index, segment) in path.indexed)
        '${index == 0 && !ownerNullable ? '.' : '?.'}$segment',
    ].join();

    var parentMap = mapExpr;
    for (final segment in path.take(path.length - 1)) {
      parentMap = "($parentMap['$segment']! as Map<String, dynamic>)";
    }

    final elseBranch = deleteGuard == null
        ? '$indent} else {'
        : '$indent} else if ($deleteGuard) {';

    return '''
${indent}final $local = $access;
${indent}if ($local != null) {
$indent  $parentMap['${path.last}'] = await HomeWidget.saveImage($keyLiteral, $local$_appGroupIdArg);
$elseBranch
$indent  await HomeWidget.saveWidgetData<String>($keyLiteral, null$_appGroupIdArg);
$indent}''';
  }

  String _deleteDataMethod() {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final hasTimedData = spec.timedDataFields.isNotEmpty;

    final parameters = <String>[
      for (final field in primitiveFields) '    bool ${field.key} = false,',
      for (final group in jsonGroups) '    bool ${group.key} = false,',
      if (hasTimedData) '    bool timedData = false,',
    ];

    final entries = <String>[
      // Localized fields need no special case: all their translations
      // live in one entry, so clearing that key clears all of them.
      for (final field in primitiveFields)
        '      if (${field.key}) '
            'HomeWidget.saveWidgetData(${_paramKey(field.key)}, '
            'null$_appGroupIdArg),',
      for (final group in jsonGroups) _jsonGroupDelete(group),
      if (hasTimedData) _timedDataDelete(),
    ];

    final buffer = StringBuffer();
    buffer.writeln('  static Future<void> deleteData({');

    for (final parameter in parameters) {
      buffer.writeln(parameter);
    }

    buffer.write('''
  }) {
    return Future.wait([
''');

    for (final entry in entries) {
      buffer.writeln(entry);
    }

    buffer.write('''
    ]);
  }
''');

    return buffer.toString();
  }

  /// The `deleteData` entry clearing one JSON group.
  ///
  /// The blob is only half the group: each image leaf owns a PNG of its own,
  /// which clearing the blob key does not reach.
  String _jsonGroupDelete(JsonDataGroup group) {
    final images =
        spec.jsonImageFields.where((i) => i.rootKey == group.key).toList();
    if (images.isEmpty) {
      return '      if (${group.key}) '
          'HomeWidget.saveWidgetData(${_paramKey(group.key)}, '
          'null$_appGroupIdArg),';
    }

    final body = <String>[
      '        await HomeWidget.saveWidgetData(${_paramKey(group.key)}, '
          'null$_appGroupIdArg);',
      for (final image in images)
        '        await HomeWidget.saveWidgetData<String>('
            '${_paramKey(image.storageKey)}, null$_appGroupIdArg);',
    ];

    return _asyncEntry('      if (${group.key}) () async {', body);
  }

  /// The `deleteData` entry taking the whole timeline, its images and its
  /// platform schedule away again.
  String _timedDataDelete() {
    final hasTimedImages = _allTimedImageKeys.isNotEmpty;

    final body = <String>[
      if (hasTimedImages)
        '        final _storedTimes = await _\$storedTimedKeys();',
      '        await HomeWidget.saveWidgetData(${_paramKey('timedData')}, '
          'null$_appGroupIdArg);',
      if (hasTimedImages) '        await _\$deleteTimedImages(_storedTimes);',
      _guardedScheduleCall(
        indent: '        ',
        call: 'HomeWidget.cancelScheduledWidgetUpdates($_androidNameArg)',
        cancels: true,
      ),
    ];

    return _asyncEntry('      if (timedData) () async {', body);
  }

  String _getDataMethod() {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final hasTimedData = spec.timedDataFields.isNotEmpty;
    final topLevelImages = primitiveFields.whereType<HWImageData>().toList();

    final recordFields = <String>[
      ...primitiveFields.map(
        (f) => f is HWLocalizedString
            ? '$_translationsClassName ${f.key}'
            : '${f.dartType}? ${f.key}',
      ),
      ...jsonGroups.map((g) => '${_dartJsonClassName(g.key)}? ${g.key}'),
      if (hasTimedData) 'Map<DateTime, $_timedDataClassName>? timedData',
    ].join(', ');

    final prelude = <String>[
      for (final group in jsonGroups) _jsonGroupRead(group),
      if (hasTimedData) _timedDataRead(),
    ];

    final values = <String>[
      for (final field in primitiveFields) _primitiveRead(field),
      for (final group in jsonGroups) '      ${group.key}: ${group.key},',
      if (hasTimedData) '      timedData: timedData,',
    ];

    final buffer = StringBuffer();

    for (final line in _getDataDoc(topLevelImages)) {
      buffer.writeln(line);
    }

    buffer.writeln('  static Future<({$recordFields})> getData() async {');

    for (final line in prelude) {
      buffer.writeln(line);
    }

    buffer.writeln('    return (');

    for (final line in values) {
      buffer.writeln(line);
    }

    buffer.write('''
    );
  }
''');

    return buffer.toString();
  }

  /// The doc comment on `getData`, naming everything that reads back
  /// differently from what was handed to `saveData`.
  List<String> _getDataDoc(List<HWImageData> topLevelImages) {
    final hasTimedData = spec.timedDataFields.isNotEmpty;
    final names = topLevelImages.map((f) => '[${f.key}]').join(', ');
    return <String>[
      if (_translationFields.isNotEmpty ||
          hasTimedData ||
          topLevelImages.isNotEmpty) ...[
        '  /// Reads every stored value back.',
        '  ///',
      ],
      if (_translationFields.isNotEmpty) ...[
        '  /// Localized fields come back fully populated: anything stored '
            'by [saveData]',
        '  /// is merged over the compiled defaults, so every locale always '
            'has text.',
        if (_localizedFields.isNotEmpty) ...[
          '  /// To read the raw stored blob instead — to tell an override '
              'apart from a',
          '  /// shipped default — use `HomeWidget.getWidgetData` on the '
              'preferences key.',
        ],
        if (hasTimedData || topLevelImages.isNotEmpty) '  ///',
      ],
      if (hasTimedData) ...[
        '  /// The keys of [timedData] are local-time [DateTime]s, so they '
            'compare equal to a',
        '  /// local [DateTime] for the same instant. Timestamps are stored '
            'as epoch',
        '  /// milliseconds: sub-millisecond precision of the saved keys is '
            'not preserved.',
        '  /// Keys are compared by instant, so a local [DateTime] and its '
            '`toUtc()` twin',
        '  /// denote the same entry and only one of them survives a save.',
      ],
      if (topLevelImages.isNotEmpty) ...[
        if (hasTimedData) '  ///',
        '  /// $names ${topLevelImages.length == 1 ? 'comes' : 'come'} back '
            'as the file path of the PNG',
        '  /// `saveData` wrote, not as an `ImageProvider`, and the file it '
            'points at may',
        '  /// since have been removed. Nested and timed images are handed '
            'back as an',
        '  /// `ImageProvider` instead.',
      ],
    ];
  }

  /// Reads one JSON group's blob back off disk, leaving it null where the file
  /// is gone or holds something else.
  String _jsonGroupRead(JsonDataGroup group) {
    final jsonClass = _dartJsonClassName(group.key);
    return '''
    final _${group.key}Path = await HomeWidget.getWidgetData<String>(${_paramKey(group.key)}$_appGroupIdArg);
    $jsonClass? ${group.key};
    if (_${group.key}Path != null) {
      try {
        final raw = await File(_${group.key}Path).readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) ${group.key} = $jsonClass.fromJson(decoded);
      } on Exception {
        ${group.key} = null;
      }
    }''';
  }

  /// Reads the timeline back, keyed by the local [DateTime] of each entry.
  String _timedDataRead() => '''
    final _timedDataPath = await HomeWidget.getWidgetData<String>(${_paramKey('timedData')}$_appGroupIdArg);
    Map<DateTime, $_timedDataClassName>? timedData;
    if (_timedDataPath != null) {
      try {
        final raw = await File(_timedDataPath).readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final entries = <DateTime, $_timedDataClassName>{};
          for (final entry in decoded.entries) {
            final millis = int.tryParse(entry.key);
            if (millis == null) continue;
            final value = entry.value;
            entries[DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal()] = $_timedDataClassName.fromJson(value is Map<String, dynamic> ? value : null);
          }
          timedData = entries;
        }
      } on Exception {
        timedData = null;
      }
    }''';

  /// The `getData` record field reading one top-level value back.
  String _primitiveRead(HWDataType<dynamic> field) {
    final key = field.key;
    if (field is HWLocalizedString) {
      return '      $key: _\$mergeTranslations(${_defaultsFieldName(field)}, '
          'await _\$readLocalized(${_paramKey(key)})),';
    }
    if (field is HWDateTime) {
      return '      $key: _readDateTime('
          'await HomeWidget.getWidgetData<String>('
          '${_paramKey(key)}$_appGroupIdArg)),';
    }
    final defaultValue = field.defaultValue;
    var defaultLiteral = '';
    if (defaultValue != null) {
      defaultLiteral = defaultValue is String
          ? ", defaultValue: '${escapeDartStringLiteral(defaultValue)}'"
          : ', defaultValue: $defaultValue';
    }
    return '      $key: '
        'await HomeWidget.getWidgetData<${field.dartType}>('
        '${_paramKey(key)}$defaultLiteral$_appGroupIdArg),';
  }

  /// Merges a stored translation blob over the compiled defaults.
  String _translationsMerger() {
    final buffer = StringBuffer();
    buffer.write('''
  static $_translationsClassName _\$mergeTranslations(
    $_translationsClassName defaults,
    Map<String, String>? stored,
  ) {
    if (stored == null) return defaults;
    return $_translationsClassName(
''');

    for (final locale in _supportedLocales) {
      final identifier = localeIdentifier(locale);
      final tag = escapeDartStringLiteral(locale);
      buffer.writeln(
        "      $identifier: stored['$tag'] ?? defaults.$identifier,",
      );
    }

    buffer.write('''
    );
  }
''');

    return buffer.toString();
  }

  /// Emits the helper re-rendering the widget's entry in the gallery.
  ///
  /// Emitted only for specs with an Android configuration: re-rendering a
  /// gallery preview is an Android feature, and WidgetKit renders its own.
  String _updatePreviewHelper() => '''
  /// Asks the launcher to re-render this widget's gallery preview.
  ///
  /// Android 15 and newer only; returns false elsewhere and when the system
  /// rate limit (about two updates per hour and widget) was hit. The plugin
  /// registers the preview automatically when the app starts, so this is only
  /// needed after data changes that should show in the gallery right away.
  static Future<bool> updatePreview() async {
    return await HomeWidget.updateWidgetPreview(
      $_androidNameArg,
    ) ?? false;
  }
''';

  /// Emits the helpers asking the launcher to place this widget.
  ///
  /// Emitted only for specs with an Android configuration: pinning is an
  /// Android feature, and a widget without one has no Android widget to pin.
  String _pinHelpers() => '''
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
      $_androidNameArg,
    );
  }
''';

  /// Emits the helpers reporting where this widget is currently placed.
  String _installHelpers() {
    final androidMatch = spec.data.android != null
        ? "androidClassName.endsWith('.$_receiverName')"
        : 'false';
    final iosName = _iosName;
    final iosMatch = iosName != null ? "info.iOSKind == '$iosName'" : 'false';
    return '''
  /// Every instance of this widget currently placed on a home screen.
  ///
  /// Android reports one entry per placed instance, iOS one entry per family
  /// the widget is placed in.
  static Future<List<HomeWidgetInfo>> getInstalledWidgets() async {
    final widgets = await HomeWidget.getInstalledWidgets();
    return widgets.where(_\$isThisWidget).toList();
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
  static bool _\$isThisWidget(HomeWidgetInfo info) {
    final androidClassName = info.androidClassName;
    if (androidClassName != null) {
      return $androidMatch;
    }
    return $iosMatch;
  }
''';
  }

  /// Emits the helpers telling the app that the widget was tapped.
  ///
  /// Emitted only for specs configuring a widget URL, which is what makes the
  /// platforms report a click at all.
  String _launchHelpers() {
    final urlFields = _widgetUrlFields;
    final filterDoc = _filterDoc;

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

    final buffer = StringBuffer();

    for (final entry in urlFields.entries) {
      buffer.write('''
  /// The URL a tap on the widget opens the app with${_widgetUrlPlatform(entry.key)}, as the app
  /// will receive it.
  ///
  /// The configured `widgetUrl` carrying the `homeWidget` query
  /// parameter, parsed — so its scheme is lower-cased, exactly like
  /// the URL handed to the app.
  static final Uri ${entry.key} = Uri.parse('${escapeDartStringLiteral(entry.value)}');

''');
    }

    buffer.write('''
  /// The URL the app was launched with by a tap on the widget, or null
  /// when it was started any other way.
  ///
$filterDoc
  static Future<Uri?> initiallyLaunchedFromWidget() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri == null || !_\$matchesWidgetUrl(uri)) {
      return null;
    }
    return uri;
  }

  /// The URL of every tap on the widget while the app is running.
  ///
  /// A tap that started the app in the first place is not replayed here
  /// — read [initiallyLaunchedFromWidget] for that one, or listen to
  /// [launchedFromWidget] for both.
  ///
$filterDoc
  static Stream<Uri> get widgetClicked =>
      HomeWidget.widgetClicked
          .where((uri) => uri != null && _\$matchesWidgetUrl(uri))
          .cast<Uri>();

  /// Every tap on the widget, launch included.
  ///
  /// Yields the launch URL first when the app was started by a tap on
  /// the widget, then every tap that follows while it runs. Taps landing
  /// while the launch URL is still being read are kept, not dropped.
  ///
$filterDoc
  static Stream<Uri> launchedFromWidget() async* {
    final clicks = StreamController<Uri>();
    final subscription = HomeWidget.widgetClicked.listen(
      (uri) {
        if (uri != null && _\$matchesWidgetUrl(uri)) clicks.add(uri);
      },
      onDone: clicks.close,
    );
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null && _\$matchesWidgetUrl(initial)) yield initial;
      yield* clicks.stream;
    } finally {
      await subscription.cancel();
      await clicks.close();
    }
  }

  /// Whether [uri] is the URL this platform's widget opens.
  ///
  /// Schemes are compared case-insensitively: the URL reaches the app parsed,
  /// which lower-cases the scheme it was written with.
  static bool _\$matchesWidgetUrl(Uri uri) {
    final url = _\$platformWidgetUrl;
    if (url == null) return false;
    return _\$lowerCaseScheme(uri) == _\$lowerCaseScheme(url);
  }

  /// The URL the widget opens on the platform the app is running on, or
  /// null where it opens none.
  static Uri? get _\$platformWidgetUrl {
''');

    if (androidField != null) {
      buffer.writeln('    if (Platform.isAndroid) return $androidField;');
    }
    if (iosField != null) {
      buffer.writeln('    if (Platform.isIOS) return $iosField;');
    }
    buffer.writeln('    return null;');

    buffer.write('''
  }

  static String _\$lowerCaseScheme(Uri uri) {
    final text = uri.toString();
    return uri.scheme.toLowerCase() + text.substring(uri.scheme.length);
  }
''');

    return buffer.toString();
  }

  /// The doc-comment paragraph every launch helper carries, naming what the
  /// emitted filter lets through.
  String get _filterDoc {
    final androidUrl = spec.androidWidgetUrl;
    final iosUrl = spec.iosWidgetUrl;
    final without = androidUrl == null
        ? 'Android'
        : iosUrl == null
            ? 'iOS'
            : null;
    final buffer = StringBuffer();
    buffer.write('''
  /// Only the URL this widget opens on the platform the app is running
  /// on is reported; a tap on any other widget is not.''');

    if (without != null) {
      buffer.write('''

  /// Nothing is ever reported on $without, where the widget opens no URL
  /// of its own.''');
    }

    return buffer.toString();
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
  /// [_allTimedImageKeys] holds the `<field>` part of every timed image, a JSON
  /// group's dotted leaf paths included.
  String _timedImageHelpers() {
    final keys = _allTimedImageKeys.map((key) => "'$key'").join(', ');
    final timedKey = _paramKey(r'timedData.$_key.$_millis');
    return '''
  static Future<List<int>> _\$storedTimedKeys() async {
    final path = await HomeWidget.getWidgetData<String>(${_paramKey('timedData')}$_appGroupIdArg);
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

  static Future<void> _\$deleteTimedImages(Iterable<int> times) async {
    await Future.wait([
      for (final _millis in times)
        for (final _key in const [$keys])
          HomeWidget.saveWidgetData<String>($timedKey, null$_appGroupIdArg),
    ]);
  }
''';
  }

  /// Reads the stored translation blob for a key back into a raw map, which
  /// `getData` then merges over the compiled defaults.
  ///
  /// Mirrors the leniency of the native readers — anything that is not a JSON
  /// object of strings reads back as null instead of throwing.
  String _localizedReader() => '''
  static Future<Map<String, String>?> _\$readLocalized(String key) async {
    final raw = await HomeWidget.getWidgetData<String>(key$_appGroupIdArg);
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final values = <String, String>{};
    decoded.forEach((locale, value) {
      if (locale is String && value is String) values[locale] = value;
    });
    return values.isEmpty ? null : values;
  }
''';

  /// A translation set for one string, with every supported locale required so
  /// that adding a locale becomes a compile error until it is translated.
  String _translationsClass() {
    final locales = _supportedLocales;

    final buffer = StringBuffer();
    buffer.write('''
class $_translationsClassName {
  const $_translationsClassName({
''');

    for (final locale in locales) {
      buffer.writeln('    required this.${localeIdentifier(locale)},');
    }

    buffer.write('''
  });

''');

    for (final locale in locales) {
      buffer.writeln('  final String ${localeIdentifier(locale)};');
    }

    buffer.write('''

  Map<String, String> toMap() => {
''');

    for (final locale in locales) {
      buffer.writeln("        '$locale': ${localeIdentifier(locale)},");
    }

    buffer.write('''
      };

''');

    buffer
      ..write(_resolveMethod())
      ..writeln('}');

    return buffer.toString();
  }

  /// `resolve(tag)` — the widget's own matching chain, for one explicit tag.
  ///
  /// Must stay in step with `hwResolveLocalized` in the Kotlin and Swift
  /// helpers, or a preview would disagree with what the widget renders.
  String _resolveMethod() {
    final baseIdentifier = _baseLocaleIdentifier;
    // Tags are case-insensitive per BCP-47, so both sides fold to lower case.
    // The native resolvers only ever see canonically cased tags, so folding
    // here cannot conflate two genuinely different tags.
    final buffer = StringBuffer();
    buffer.write('''
  /// The text this set resolves to for the BCP-47 locale [tag].
  ///
  /// Tries the exact tag (`pt-PT`), then the tag with its last subtag
  /// dropped, and so on down to the bare language (`zh-Hant-TW` →
  /// `zh-Hant` → `zh`), then any entry with the same language but a
  /// different region or script (`pt-BR`; the lexicographically
  /// smallest wins if several match), and finally the widget's default
  /// locale. Matching is case-insensitive, and `_` is treated as `-`.
  ///
  /// The widget natively runs these same steps against *every* entry
  /// of the OS preferred-language list in order; this answers for one
  /// explicit tag, which is what previews and tests need.
  String resolve(String tag) {
    final values = {
      for (final entry in toMap().entries)
        entry.key.toLowerCase(): entry.value,
    };
    final normalized = tag.replaceAll('_', '-').toLowerCase();
''');

    if (baseIdentifier == null) {
      buffer.write('''
    return values[normalized] ?? '';
  }
''');
      return buffer.toString();
    }

    // Progressive truncation: zh-Hant-TW -> zh-Hant -> zh.
    buffer.write('''
    var candidate = normalized;
    while (true) {
      final match = values[candidate];
      if (match != null) return match;
      final cut = candidate.lastIndexOf('-');
      if (cut <= 0) break;
      candidate = candidate.substring(0, cut);
    }
    final language = candidate;
    String? sibling;
    for (final key in values.keys) {
      if (key.split('-').first != language) continue;
      if (sibling == null || key.compareTo(sibling) < 0) sibling = key;
    }
    if (sibling != null) {
      final match = values[sibling];
      if (match != null) return match;
    }
    return $baseIdentifier;
  }
''');

    return buffer.toString();
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
  String _guardedScheduleCall({
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
    return '''
${indent}try {
$indent  await $call;
$indent} catch (error, stackTrace) {
$indent  $comment
$indent  FlutterError.reportError(
$indent    FlutterErrorDetails(
$indent      exception: error,
$indent      stack: stackTrace,
$indent      library: 'home_widget',
$indent      context: ErrorDescription('$description'),
$indent    ),
$indent  );
$indent}''';
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

  /// The wire form of a date: the UTC ISO 8601 string every storage path
  /// writes and the native `hwParseIsoDate` helper reads back.
  String _dartIsoExpr(String valueExpr) =>
      '$valueExpr.toUtc().toIso8601String()';

  String get _appGroupIdArg =>
      _usesAppGroupId ? r', appGroupId: _$appGroupId' : '';

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

  String _jsonNodeClass({
    required String className,
    required _JsonPathNode node,
  }) {
    final fields = <String>[
      for (final entry in node.children.entries)
        if (_isLeaf(entry.value))
          if (entry.value.leafType is HWImageData)
            '''
  /// The image stored at this leaf.
  ///
  /// `saveData` writes it to its own PNG and puts that path in the blob;
  /// `getData` hands it back as a `FileImage` of that PNG.
  final ImageProvider? ${entry.key};'''
          else
            '  final ${entry.value.leafType!.dartType}? ${entry.key};'
        else
          '  final ${_dartChildClassName(className, entry.key)}? ${entry.key};',
    ];

    final fromJson = <String>[
      for (final entry in node.children.entries)
        if (_isLeaf(entry.value))
          '      ${entry.key}: '
              '${_dartReadFunction(entry.value.leafType!)}'
              "(json['${entry.key}'])"
              '${_dartDefaultLiteral(entry.value.leafType!)},'
        else
          "      ${entry.key}: json['${entry.key}'] is Map<String, dynamic> ? ${_dartChildClassName(className, entry.key)}.fromJson(json['${entry.key}'] as Map<String, dynamic>) : null,",
    ];

    final toJson = <String>[
      for (final entry in node.children.entries)
        // An image leaf is deliberately absent: only `saveData` knows the path
        // its PNG was written to, and it puts it into this map afterwards.
        if (!(_isLeaf(entry.value) && entry.value.leafType is HWImageData))
          if (_isLeaf(entry.value))
            "      if (${entry.key} != null) '${entry.key}': "
                '${entry.value.leafType is HWDateTime ? _dartIsoExpr('${entry.key}!') : entry.key},'
          else
            "      if (${entry.key} != null) '${entry.key}': ${entry.key}!.toJson(),",
    ];

    final buffer = StringBuffer();
    buffer.writeln('class $className {');

    for (final line in fields) {
      buffer.writeln(line);
    }

    buffer.write('''

  const $className({
''');

    for (final key in node.children.keys) {
      buffer.writeln('    this.$key,');
    }

    buffer.write('''
  });

  factory $className.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return $className(
''');

    for (final line in fromJson) {
      buffer.writeln(line);
    }

    buffer.write('''
    );
  }

  Map<String, dynamic> toJson() {
    return {
''');

    for (final line in toJson) {
      buffer.writeln(line);
    }

    buffer.write('''
    };
  }
}
''');

    for (final entry in node.children.entries) {
      if (_isLeaf(entry.value)) continue;
      buffer
        ..writeln()
        ..write(
          _jsonNodeClass(
            className: _dartChildClassName(className, entry.key),
            node: entry.value,
          ),
        );
    }

    return buffer.toString();
  }

  /// Whether [node] carries a value of its own rather than a nested object.
  bool _isLeaf(_JsonPathNode node) =>
      node.leafType != null && node.children.isEmpty;

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

  String _timedDataClass(List<HWTimedData<dynamic>> timedFields) {
    final className = _timedDataClassName;
    final members = _timedMembers(timedFields);

    final fields = <String>[
      for (final member in members)
        if (member.isImage)
          '''
  /// The image shown from this entry's timestamp on.
  ///
  /// `saveData` writes it to its own PNG and stores that path in the entry;
  /// `getData` hands it back as a `FileImage` of that PNG.
  final ${member.type}? ${member.key};'''
        else
          '  final ${member.type}? ${member.key};',
    ];

    final fromJson = <String>[
      for (final member in members) _timedMemberRead(member),
    ];

    final toJson = <String>[
      // Images are deliberately absent: only `saveData` knows the path an
      // entry's PNG was written to, and it adds it to this map afterwards.
      for (final member in members)
        if (!member.isImage) _timedMemberWrite(member),
    ];

    final buffer = StringBuffer();
    buffer.writeln('class $className {');

    for (final line in fields) {
      buffer.writeln(line);
    }

    buffer.write('''

  const $className({
''');

    for (final member in members) {
      buffer.writeln('    this.${member.key},');
    }

    buffer.write('''
  });

  factory $className.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return $className(
''');

    for (final line in fromJson) {
      buffer.writeln(line);
    }

    buffer.write('''
    );
  }

  Map<String, dynamic> toJson() {
    return {
''');

    for (final line in toJson) {
      buffer.writeln(line);
    }

    buffer.write('''
    };
  }
}
''');

    return buffer.toString();
  }

  /// Reads one member of a timed entry back out of its JSON object.
  String _timedMemberRead(_TimedMember member) {
    final key = member.key;
    if (member.jsonRoot) {
      return "      $key: json['$key'] is Map<String, dynamic> ? ${member.type}.fromJson(json['$key'] as Map<String, dynamic>) : null,";
    }
    if (member.isImage) {
      return "      $key: _readFileImage(json['$key']),";
    }
    final leafType = member.leafType!;
    if (leafType is HWLocalizedString) {
      // Same merge as `getData` runs on an untimed field, so an entry that
      // carries only some locales still reads back complete.
      return '      $key: $_helperClassName._\$mergeTranslations('
          '$_helperClassName.${_defaultsFieldName(leafType)}, '
          "_readTranslations(json['$key'])),";
    }
    return '      $key: ${_dartReadFunction(leafType)}'
        "(json['$key'])${_dartDefaultLiteral(leafType)},";
  }

  /// Writes one member of a timed entry into its JSON object.
  String _timedMemberWrite(_TimedMember member) {
    final key = member.key;
    if (member.jsonRoot) {
      return "      if ($key != null) '$key': $key!.toJson(),";
    }
    if (member.leafType is HWLocalizedString) {
      // Every locale travels in the entry; the native readers merge it over
      // the compiled translations again on the other side.
      return "      if ($key != null) '$key': $key!.toMap(),";
    }
    if (member.leafType is HWDateTime) {
      return "      if ($key != null) '$key': ${_dartIsoExpr('$key!')},";
    }
    return "      if ($key != null) '$key': $key,";
  }

  /// Emits only the `_read*` helpers in [usedReaders] so generated files never
  /// contain unused private functions (which trip `unused_element`).
  String _jsonReaders(Set<String> usedReaders) {
    final buffer = StringBuffer();

    if (usedReaders.contains('_readString')) {
      buffer.write('''
String? _readString(Object? value) => value is String ? value : null;
''');
    }

    if (usedReaders.contains('_readInt')) {
      buffer.write('''
int? _readInt(Object? value) => value is num ? value.toInt() : null;
''');
    }

    if (usedReaders.contains('_readDouble')) {
      buffer.write('''
double? _readDouble(Object? value) => value is num ? value.toDouble() : null;
''');
    }

    if (usedReaders.contains('_readBool')) {
      buffer.write('''
bool? _readBool(Object? value) => value is bool ? value : null;
''');
    }

    // Anything that is not a readable ISO 8601 string comes back as null,
    // the same way the native `hwParseIsoDate` helper answers.
    if (usedReaders.contains('_readDateTime')) {
      buffer.write('''
DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
''');
    }

    // The stored value is the absolute path of the PNG `saveData` wrote; a
    // path whose file is gone reads back as null, like a missing image.
    if (usedReaders.contains('_readFileImage')) {
      buffer.write('''
ImageProvider? _readFileImage(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final file = File(value);
  return file.existsSync() ? FileImage(file) : null;
}
''');
    }

    // Lenient in the same way as the native decoders: anything that is not
    // a JSON object of strings reads back as null and leaves the compiled
    // translations in place.
    if (usedReaders.contains('_readTranslations')) {
      buffer.write('''
Map<String, String>? _readTranslations(Object? value) {
  if (value is! Map) return null;
  final values = <String, String>{};
  value.forEach((locale, text) {
    if (locale is String && text is String) values[locale] = text;
  });
  return values.isEmpty ? null : values;
}
''');
    }

    return buffer.toString();
  }

  String _dartReadFunction(HWDataType<dynamic> field) {
    if (field is HWString) return '_readString';
    if (field is HWInt) return '_readInt';
    if (field is HWDouble) return '_readDouble';
    if (field is HWBool) return '_readBool';
    // The stored value is an ISO 8601 string; the Dart API hands back a date.
    if (field is HWDateTime) return '_readDateTime';
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
