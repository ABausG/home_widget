import 'dart:convert';
import 'dart:io';

import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _handler = InteractionHandler(
  libraryUri: 'package:app/counter_interaction.dart',
  name: 'onCounterInteraction',
);

const _increment = HWButton(
  'increment',
  data: [HWPayload('step', HWInt.fixed(1))],
  child: HWText(HWString.fixed('+')),
);

const _reset = HWButton(
  'reset',
  child: HWText(HWString.fixed('Reset')),
);

const _set = HWButton(
  'set',
  data: [HWInt('count'), HWPayload('done', HWBool.fixed(true))],
  child: HWText(HWString.fixed('Set')),
);

const _buttons = HWColumn(children: [_increment, _reset]);

const _forecast = HWLink(
  'forecast',
  url: 'myapp://forecast',
  data: [HWString('city'), HWPayload('days', HWInt.fixed(7))],
  child: HWText(HWString.fixed('Forecast')),
);

String _generate({
  String name = 'Counter',
  HWWidget? tree = _buttons,
  List<HWDataType<dynamic>> dataFields = const [HWInt('count')],
  InteractionHandler? handler = _handler,
  String? widgetUrl,
  bool android = true,
  bool iOS = true,
  Map<String, HomeWidgetFlavor>? flavors,
}) =>
    DartHelperGenerator(
      WidgetSpec(
        data: HomeWidget(
          name: name,
          widgetUrl: widgetUrl,
          android: android ? const HomeWidgetAndroidConfiguration() : null,
          iOS: iOS
              ? const HomeWidgetIOSConfiguration(groupId: 'group.counter')
              : null,
          flavors: flavors,
        ),
        className: 'Counter',
        widgetTree: tree,
        dataFields: dataFields,
        interactionHandler: handler,
      ),
    ).generate();

void main() {
  group('InteractionHandler', () {
    InteractionHandler handler({
      String libraryUri = 'package:app/handlers.dart',
      String name = 'onTap',
      String? className = 'Handlers',
    }) =>
        InteractionHandler(
          libraryUri: libraryUri,
          name: name,
          className: className,
        );

    test('references a top-level function by its name', () {
      expect(_handler.reference, 'onCounterInteraction');
    });

    test('references a static function through its class', () {
      expect(handler().reference, 'Handlers.onTap');
    });

    test('equals a handler naming the same function', () {
      final first = handler();

      expect(first, equals(first));
      expect(first, equals(handler()));
      expect(first.hashCode, handler().hashCode);
    });

    test('differs from a handler naming another function', () {
      final first = handler();

      expect(first, isNot(equals(handler(libraryUri: 'package:app/b.dart'))));
      expect(first, isNot(equals(handler(name: 'onOther'))));
      expect(first, isNot(equals(handler(className: null))));
      expect(first, isNot(equals('Handlers.onTap')));
    });

    test('is part of what makes two specs equal', () {
      final data = HomeWidget(name: 'Counter');
      const fields = <HWDataType<dynamic>>[];
      WidgetSpec spec(InteractionHandler? handler) => WidgetSpec(
            data: data,
            className: 'Counter',
            dataFields: fields,
            widgetTree: _buttons,
            interactionHandler: handler,
          );

      expect(spec(_handler), equals(spec(_handler)));
      expect(spec(_handler).hashCode, spec(_handler).hashCode);
      expect(spec(_handler), isNot(equals(spec(null))));
      expect(spec(_handler), isNot(equals(spec(handler()))));
    });
  });

  group('interaction targets', () {
    WidgetSpec spec({
      HWWidget? tree = _buttons,
      InteractionHandler? handler = _handler,
    }) =>
        WidgetSpec(
          data: HomeWidget(name: 'Counter'),
          className: 'Counter',
          widgetTree: tree,
          interactionHandler: handler,
        );

    test('need a button and a handler to count as interactions', () {
      expect(spec().hasInteractions, isTrue);
      expect(spec(handler: null).hasInteractions, isFalse);
      expect(
        spec(tree: const HWText(HWString.fixed('Count'))).hasInteractions,
        isFalse,
      );
    });

    test('name one class per button id, in document order', () {
      final targets = spec(
        tree: const HWColumn(children: [_increment, _reset, _increment]),
      ).interactionTargets;

      expect(
        targets.map((target) => target.className),
        ['CounterIncrementInteraction', 'CounterResetInteraction'],
      );
      expect(
        targets.first.description,
        'A tap on the `increment` button of the Counter widget.',
      );
      expect(targets.first.url.payload.single.name, 'step');
      expect(targets.last.url.payload, isEmpty);
    });

    test('share the class and the key named after the widget', () {
      expect(spec().interactionClassName, 'CounterInteraction');
      expect(spec().interactionKey, 'CounterHomeWidget');
      expect(spec().androidEmitContext.interactionKey, 'CounterHomeWidget');
      expect(spec(handler: null).androidEmitContext.interactionKey, isNull);
    });
  });

  group('imports', () {
    test('carry what registering and logging need', () {
      final output = _generate();

      expect(output, contains("import 'package:flutter/foundation.dart';"));
      expect(output, contains("import 'package:flutter/services.dart';"));
      expect(
        output,
        contains(
          "import 'package:home_widget/home_widget.dart';\n"
          "import 'package:app/counter_interaction.dart' as _\$interaction;\n",
        ),
      );
    });

    test('leave out dart:typed_data for a widget storing files', () {
      const fields = <HWDataType<dynamic>>[HWJson('user', HWString('name'))];
      const tree = HWColumn.builder(
        'todos',
        item: HWButton(
          'toggle',
          child: HWText(HWItemData(HWString('title'))),
        ),
      );

      final interactive = _generate(tree: tree, dataFields: fields);
      final plain = _generate(tree: tree, dataFields: fields, handler: null);

      expect(interactive, contains('UserJsonData? user,'));
      expect(interactive, contains('List<CounterTodosItem>? todos,'));
      expect(interactive, contains("import 'dart:io';"));
      expect(interactive, isNot(contains("import 'dart:typed_data';")));
      expect(plain, contains("import 'dart:typed_data';"));
    });

    test('are left out without interactions', () {
      final output = _generate(handler: null);

      expect(output, isNot(contains('package:flutter/foundation.dart')));
      expect(output, isNot(contains('package:flutter/services.dart')));
      expect(output, isNot(contains('_\$interaction')));
    });
  });

  group('interaction helpers', () {
    test('register the entry point under the key of the widget', () {
      final output = _generate();

      expect(
        output,
        contains(
          "  static const String _\$interactionKey = 'CounterHomeWidget';\n"
          '\n'
          '  static bool _\$interactivityRegistered = false;\n',
        ),
      );
      expect(
        output,
        contains(
          '  static Future<bool?> registerInteractivity() async {\n'
          '    try {\n'
          '      final registered = await '
          'HomeWidget.registerInteractivityCallback(\n'
          '        _\$counterInteractionEntryPoint,\n'
          '        key: _\$interactionKey,\n'
          '        appGroupId: _\$appGroupId,\n'
          '      );\n'
          '      _\$interactivityRegistered = true;\n'
          '      return registered;\n',
        ),
      );
    });

    test('log and return false below iOS 17, rethrowing anything else', () {
      final output = _generate();

      expect(
        output,
        contains(
          '    } on PlatformException catch (error) {\n'
          "      if (error.code != '-5') rethrow;\n"
          '      _\$interactivityRegistered = true;\n'
          "      debugPrint('The buttons of the Counter widget need iOS 17 or "
          "newer: a tap on them does nothing on this device.');\n"
          '      return false;\n'
          '    }\n',
        ),
      );
    });

    test('register once per isolate, in the background', () {
      final output = _generate();

      expect(
        output,
        contains(
          '  static void _\$ensureInteractivity() {\n'
          '    if (_\$interactivityRegistered || '
          '_\$implicitRegistration != null) return;\n'
          '    _\$implicitRegistration = registerInteractivity().then<void>(\n',
        ),
      );
      expect(
        output,
        contains(
          "        debugPrint('The buttons of the Counter widget will not "
          'work: registering them with home_widget failed: \$error\');\n',
        ),
      );
    });

    test('document what saveData and updateWidget do for them', () {
      expect(
        _generate(),
        contains('/// `saveData` and `updateWidget` do this themselves'),
      );
      expect(
        _generate(dataFields: const []),
        contains('/// `updateWidget` does this itself'),
      );
    });

    test('skip registering inside the isolate a tap runs in', () {
      expect(
        _generate(),
        contains(
          'Future<void> _\$counterInteractionEntryPoint(Uri? uri) async {\n'
          '  CounterHomeWidget._\$interactivityRegistered = true;\n',
        ),
      );
    });

    test('escape the name of the widget in the log', () {
      final output = _generate(name: "Tom's \$Counter");

      expect(
        output,
        contains(
          "debugPrint('The buttons of the Tom\\'s \\\$Counter widget need "
          'iOS 17 or newer',
        ),
      );
    });

    test('run before saveData writes anything', () {
      final output = _generate();

      expect(
        output,
        contains(
          '  }) {\n'
          '    _\$ensureInteractivity();\n'
          '    return Future.wait([\n'
          '      if (count != null) HomeWidget.saveWidgetData<int>(',
        ),
      );
    });

    test('run before saveData writes the pictures it read', () {
      final output = _generate(
        tree: const HWColumn(
          children: [_increment, HWImage(HWImageData('avatar'))],
        ),
        dataFields: const [HWInt('count'), HWImageData('avatar')],
      );

      expect(
        output,
        contains(
          '  }) async {\n'
          '    _\$ensureInteractivity();\n'
          '    final _rootImage_avatar = await _\$readImage(avatar);\n',
        ),
      );
    });

    test('run before updateWidget reloads the widget', () {
      final output = _generate();

      expect(
        output,
        contains(
          '  static Future<bool?> updateWidget() {\n'
          '    _\$ensureInteractivity();\n'
          '    return HomeWidget.updateWidget(\n'
          "      androidName: 'CounterHomeWidgetReceiver',\n"
          "      iOSName: 'CounterHomeWidget',\n"
          '    );\n'
          '  }\n',
        ),
      );
    });

    void expectNothingInteractive(String output) {
      expect(
        output,
        contains(
          '  static Future<bool?> updateWidget() {\n'
          '    return HomeWidget.updateWidget(\n',
        ),
      );
      expect(
        output,
        contains(
          '    return Future.wait([\n'
          '      if (count != null) HomeWidget.saveWidgetData<int>(',
        ),
      );
      expect(output, isNot(contains('_\$interactionKey')));
      expect(output, isNot(contains('_\$interactivityRegistered')));
      expect(output, isNot(contains('registerInteractivity')));
      expect(output, isNot(contains('_\$ensureInteractivity')));
      expect(output, isNot(contains('CounterInteraction')));
      expect(output, isNot(contains('InteractionEntryPoint')));
      expect(output, isNot(contains("@pragma('vm:entry-point')")));
      expect(output, isNot(contains('_\$matchesPayloadUrl')));
      expect(output, isNot(contains('PlatformException')));
    }

    test('are left out of a widget without buttons or a handler', () {
      expectNothingInteractive(
        _generate(
          tree: const HWText(HWString.fixed('Count')),
          handler: null,
        ),
      );
    });

    test('are left out of a widget with a handler and no button', () {
      expectNothingInteractive(
        _generate(tree: const HWText(HWString.fixed('Count'))),
      );
    });

    test('are left out of a widget with buttons and no handler', () {
      expectNothingInteractive(_generate(handler: null));
    });
  });

  group('App Group', () {
    test('is declared once for a widget storing data', () {
      final output = _generate();

      expect(
        "static const String _\$appGroupId = 'group.counter';"
            .allMatches(output),
        hasLength(1),
      );
    });

    test('is declared once for a widget storing nothing', () {
      final output = _generate(dataFields: const []);

      expect(
        "static const String _\$appGroupId = 'group.counter';"
            .allMatches(output),
        hasLength(1),
      );
      expect(output, contains('        appGroupId: _\$appGroupId,\n'));
      expect(output, isNot(contains('_\$paramPrefix')));
      expect(output, isNot(contains('Future<void> saveData(')));
    });

    test('is not declared for a widget storing nothing without buttons', () {
      final output = _generate(dataFields: const [], handler: null);

      expect(output, isNot(contains('_\$appGroupId')));
    });

    test('is left out without an iOS configuration', () {
      final output = _generate(iOS: false);

      expect(
        output,
        contains(
          '        _\$counterInteractionEntryPoint,\n'
          '        key: _\$interactionKey,\n'
          '      );\n',
        ),
      );
      expect(output, isNot(contains('appGroupId:')));
      expect(output, isNot(contains('_\$appGroupId')));
      expect(output, isNot(contains('iOSName:')));
    });
  });

  group('flavors', () {
    const flavors = {
      'dev': HomeWidgetFlavor(
        iOS: HomeWidgetIOSFlavor(groupId: 'group.counter.dev'),
      ),
      'prod': HomeWidgetFlavor(),
    };

    test('guard registering and updating', () {
      final output = _generate(flavors: flavors);

      expect(
        output,
        contains(
          '  static Future<bool?> registerInteractivity() async {\n'
          '    if (!_\$inDeclaredFlavor) return false;\n'
          '    try {\n',
        ),
      );
      expect(
        output,
        contains(
          '  static Future<bool?> updateWidget() {\n'
          '    if (!_\$inDeclaredFlavor) return Future.value(false);\n'
          '    _\$ensureInteractivity();\n',
        ),
      );
      expect(
        output,
        contains(
          '    if (!_\$inDeclaredFlavor) return Future.value();\n'
          '    _\$ensureInteractivity();\n'
          '    return Future.wait([\n',
        ),
      );
    });

    test('resolve the App Group registered with per flavor', () {
      for (final dataFields in const [
        <HWDataType<dynamic>>[HWInt('count')],
        <HWDataType<dynamic>>[],
      ]) {
        final output = _generate(flavors: flavors, dataFields: dataFields);

        expect(
          output,
          contains(
            '  static String get _\$appGroupId => switch (appFlavor) {\n'
            "    'dev' => 'group.counter.dev',\n"
            "    'prod' => 'group.counter',\n",
          ),
        );
        expect('_\$appGroupId =>'.allMatches(output), hasLength(1));
        expect(output, isNot(contains('static const String _\$appGroupId')));
        expect(output, contains('        appGroupId: _\$appGroupId,\n'));
      }
    });
  });

  group('interaction model', () {
    test('is a sealed class decoding every button in order', () {
      final output = _generate(
        tree: const HWColumn(children: [_increment, _reset, _set]),
      );

      expect(
        output,
        contains(
          '/// A tap on a button of the Counter widget.\n'
          '///\n'
          '/// The fields of an interaction hold the values the widget was '
          'rendered with\n'
          '/// when it was tapped, which may be older than what the app has '
          'stored since.\n'
          'sealed class CounterInteraction {\n'
          '  const CounterInteraction();\n',
        ),
      );
      expect(
        output,
        contains(
          '  static CounterInteraction? fromUri(Uri uri) => '
          'CounterIncrementInteraction._\$fromUri(uri) ?? '
          'CounterResetInteraction._\$fromUri(uri) ?? '
          'CounterSetInteraction._\$fromUri(uri);',
        ),
      );
      expect(output, contains('  Uri toUri();'));
    });

    test('declares one class per button id with its payload', () {
      final output = _generate(
        tree: const HWColumn(children: [_increment, _reset, _set]),
      );

      expect(
        output,
        contains(
          '/// A tap on the `increment` button of the Counter widget.\n'
          'final class CounterIncrementInteraction extends CounterInteraction '
          '{\n'
          '  const CounterIncrementInteraction({this.step = 1});\n'
          '\n'
          '  final int step;\n',
        ),
      );
      expect(
        output,
        contains(
          '/// A tap on the `reset` button of the Counter widget.\n'
          'final class CounterResetInteraction extends CounterInteraction {\n'
          '  const CounterResetInteraction();\n',
        ),
      );
      expect(
        output,
        contains(
          'final class CounterSetInteraction extends CounterInteraction {\n'
          '  const CounterSetInteraction({this.count, this.done = true});\n'
          '\n'
          '  final int? count;\n'
          '  final bool done;\n',
        ),
      );
      expect(
        output,
        contains(
          '  static final Uri _\$url = '
          "Uri.parse('homewidget://interaction/reset?homeWidget');",
        ),
      );
    });

    test('declares a button of both branches of a condition once', () {
      final output = _generate(
        tree: const HWBoolConditional(
          data: HWBool('running'),
          whenTrue: HWRow(children: [_increment, _reset]),
          whenFalse: HWColumn(children: [_increment]),
        ),
        dataFields: const [HWBool('running')],
      );

      expect(
        'final class CounterIncrementInteraction'.allMatches(output),
        hasLength(1),
      );
      expect(
        output,
        contains(
          '=> CounterIncrementInteraction._\$fromUri(uri) ?? '
          'CounterResetInteraction._\$fromUri(uri);',
        ),
      );
    });

    test('carries an item field of a builder', () {
      final output = _generate(
        tree: const HWColumn.builder(
          'todos',
          item: HWButton(
            'toggle',
            data: [HWItemData(HWString('id'))],
            child: HWText(HWItemData(HWString('title'))),
          ),
        ),
        dataFields: const [],
      );

      expect(
        output,
        contains(
          'final class CounterToggleInteraction extends CounterInteraction {\n'
          '  const CounterToggleInteraction({this.id});\n'
          '\n'
          '  final String? id;\n',
        ),
      );
      expect(
        output,
        contains("return CounterToggleInteraction(id: query['id']);"),
      );
    });

    test('carries the readers its payloads need, once', () {
      final output = _generate(
        tree: const HWColumn(children: [_increment, _reset]),
      );

      expect('bool _\$matchesPayloadUrl('.allMatches(output), hasLength(1));
      expect('Uri _\$payloadUri('.allMatches(output), hasLength(1));
      expect('int? _\$payloadInt('.allMatches(output), hasLength(1));
      expect(output, isNot(contains('_\$payloadBool')));
    });

    test('shares the payload helpers with the launches of the widget', () {
      final output = _generate(
        widgetUrl: 'myapp://counter',
        tree: const HWColumn(children: [_forecast, _set]),
        dataFields: const [HWInt('count'), HWString('city')],
      );

      expect(output, contains('sealed class CounterLaunch {'));
      expect(output, contains('final class CounterWidgetTap'));
      expect(output, contains('final class CounterForecastLink'));
      expect(output, contains('sealed class CounterInteraction {'));
      expect(output, contains('final class CounterSetInteraction'));
      expect('bool _\$matchesPayloadUrl('.allMatches(output), hasLength(1));
      expect('Uri _\$payloadUri('.allMatches(output), hasLength(1));
      expect('int? _\$payloadInt('.allMatches(output), hasLength(1));
      expect('bool? _\$payloadBool('.allMatches(output), hasLength(1));
      expect(output, isNot(contains('_\$payloadDouble')));
    });
  });

  group('entry point', () {
    test('hands the decoded interaction to the function and waits for it', () {
      final output = _generate();

      expect(
        output,
        contains(
          "@pragma('vm:entry-point')\n"
          'Future<void> _\$counterInteractionEntryPoint(Uri? uri) async {\n'
          '  CounterHomeWidget._\$interactivityRegistered = true;\n'
          '  final interaction = uri == null ? null : '
          'CounterInteraction.fromUri(uri);\n'
          '  if (interaction != null) await '
          '_\$interaction.onCounterInteraction(interaction);\n'
          '}\n',
        ),
      );
      expect("@pragma('vm:entry-point')".allMatches(output), hasLength(1));
    });

    test('calls a static function through its class', () {
      final output = _generate(
        handler: const InteractionHandler(
          libraryUri: 'package:app/handlers.dart',
          name: 'onTap',
          className: 'Handlers',
        ),
      );

      expect(
        output,
        contains("import 'package:app/handlers.dart' as _\$interaction;"),
      );
      expect(
        output,
        contains(
          '  if (interaction != null) await '
          '_\$interaction.Handlers.onTap(interaction);\n',
        ),
      );
    });
  });

  group('the generated helper, run', () {
    test('saves although registering throws a MissingPluginException',
        () async {
      final output = await _runHelper(
        "MissingPluginException('No implementation found')",
      );

      expect(output, [
        'LOG The buttons of the Counter widget will not work: registering '
            'them with home_widget failed: MissingPluginException(No '
            'implementation found)',
        'saved 4',
        'registrations 3',
        'explicit MissingPluginException(No implementation found)',
        'registrations 4',
      ]);
    });

    test('saves although registering fails without an App Group', () async {
      final output = await _runHelper("PlatformException(code: '-7')");

      expect(output, [
        'LOG The buttons of the Counter widget will not work: registering '
            'them with home_widget failed: PlatformException(-7)',
        'saved 4',
        'registrations 3',
        'explicit PlatformException(-7)',
        'registrations 4',
      ]);
    });

    test('registers once below iOS 17 and reports false', () async {
      final output = await _runHelper("PlatformException(code: '-5')");

      expect(output, [
        'LOG The buttons of the Counter widget need iOS 17 or newer: a tap '
            'on them does nothing on this device.',
        'saved 4',
        'registrations 1',
        'LOG The buttons of the Counter widget need iOS 17 or newer: a tap '
            'on them does nothing on this device.',
        'explicit false',
        'registrations 2',
      ]);
    });

    test('registers once when the plugin accepts it', () async {
      final output = await _runHelper('null');

      expect(output, [
        'saved 4',
        'registrations 1',
        'explicit true',
        'registrations 2',
      ]);
    });
  });
}

/// Runs the helper of an iOS widget `Counter` storing `count` in a subprocess,
/// against a stub of `package:home_widget` whose registration throws
/// [registerError], a Dart expression, unless it is `null`.
///
/// Saves twice and updates once, letting each implicit registration settle,
/// then registers explicitly, and prints one line per step.
Future<List<String>> _runHelper(String registerError) async {
  final generated = _generate(android: false).replaceAll(
    RegExp(r"^import '.*'.*;$", multiLine: true),
    '',
  );
  final dir = await Directory.systemTemp.createTemp('hw_interaction_run_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File(p.join(dir.path, 'main.dart'));
  await file.writeAsString('''
import 'dart:async';

$generated

class PlatformException implements Exception {
  PlatformException({required this.code});

  final String code;

  @override
  String toString() => 'PlatformException(\$code)';
}

class MissingPluginException implements Exception {
  MissingPluginException(this.message);

  final String message;

  @override
  String toString() => 'MissingPluginException(\$message)';
}

void debugPrint(String? message) => print('LOG \$message');

class HomeWidgetInfo {
  String? androidClassName;
  String? iOSKind;
}

class HomeWidget {
  static int registrations = 0;
  static final saved = <String, Object?>{};

  static Future<bool?> registerInteractivityCallback(
    Function callback, {
    String? key,
    String? appGroupId,
  }) async {
    registrations++;
    final Object? error = $registerError;
    if (error != null) throw error;
    return true;
  }

  static Future<bool?> saveWidgetData<T>(String id, T? data, {String? appGroupId}) async {
    saved[id] = data;
    return true;
  }

  static Future<T?> getWidgetData<T>(String id, {T? defaultValue, String? appGroupId}) async =>
      (saved[id] as T?) ?? defaultValue;

  static Future<bool?> updateWidget({String? name, String? androidName, String? iOSName, String? qualifiedAndroidName}) async => true;

  static Future<List<HomeWidgetInfo>> getInstalledWidgets() async => [];
}

class _\$interaction {
  static Future<void> onCounterInteraction(Object interaction) async {}
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

Future<void> main() async {
  await CounterHomeWidget.saveData(count: 3);
  await settle();
  await CounterHomeWidget.saveData(count: 4);
  await settle();
  await CounterHomeWidget.updateWidget();
  await settle();
  print('saved \${(await CounterHomeWidget.getData()).count}');
  print('registrations \${HomeWidget.registrations}');
  try {
    print('explicit \${await CounterHomeWidget.registerInteractivity()}');
  } catch (error) {
    print('explicit \$error');
  }
  print('registrations \${HomeWidget.registrations}');
}
''');

  final result = await Process.run(Platform.resolvedExecutable, [file.path]);
  if (result.exitCode != 0) {
    fail('generated code did not run:\n${result.stdout}\n${result.stderr}');
  }
  return const LineSplitter().convert((result.stdout as String).trim());
}
