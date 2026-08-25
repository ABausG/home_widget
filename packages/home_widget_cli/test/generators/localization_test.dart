import 'dart:convert';
import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/util/naming.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

const _localization = HomeWidgetLocalization(
  defaultLocale: 'en',
  supportedLocales: ['en', 'de', 'pt-BR'],
);

HWLocalizedString _localized({
  String key = 'greeting',
  bool isConstant = false,
  Map<String, String> values = const {
    'en': 'Hello',
    'de': 'Hallo',
    'pt-BR': 'Ola',
  },
}) =>
    // ignore: invalid_use_of_internal_member
    HWLocalizedString.resolved(
      isConstant ? '' : key,
      defaultTranslations: values,
      isConstant: isConstant,
      defaultLocale: 'en',
      // Stamped by the parser in real generation; every spec here is for the
      // `Greeting` widget.
      resourcePrefix: 'home_widget_greeting',
    );

WidgetSpec _spec({
  required HWWidget widget,
  HomeWidgetLocalization? localization = _localization,
  String? description,
  String name = 'Greeting',
  HomeWidgetAndroidConfiguration? android =
      const HomeWidgetAndroidConfiguration(packageName: 'com.example'),
}) {
  final tree = widget;
  return WidgetSpec(
    data: HomeWidget(
      name: name,
      description: description,
      widget: tree,
      android: android,
      iOS: const HomeWidgetIOSConfiguration(groupId: 'group.example'),
      localization: localization,
    ),
    className: 'Greeting',
    dataFields: tree.dataDependencies.toList(),
    widgetTree: tree,
  );
}

Future<Directory> _project() async {
  final dir = await Directory.systemTemp.createTemp('hw_l10n_');
  await Directory(
    p.join(dir.path, 'android', 'app', 'src', 'main'),
  ).create(recursive: true);
  await Directory(p.join(dir.path, 'ios')).create(recursive: true);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Runs the generated translations class in a subprocess, so the resolution
/// and merge tests assert behavior rather than source text.
///
/// Only the translations class and the merge helper are lifted out — neither
/// touches `package:home_widget`, so the extract runs with no package config.
/// The merge helper is turned into a top-level function on the way, since its
/// class is the half that does need the plugin.
Future<String> _runGenerated(String dart, String body) async {
  final translations =
      dart.substring(dart.indexOf('class GreetingHomeWidgetTranslations'));
  const mergeSignature =
      r'  static GreetingHomeWidgetTranslations _$mergeTranslations(';
  final mergeStart = dart.indexOf(mergeSignature);
  expect(mergeStart, isNonNegative, reason: 'no merge helper was emitted');
  const mergeClose = '\n  }\n';
  final mergeEnd = dart.indexOf(mergeClose, mergeStart) + mergeClose.length;
  final merge = dart
      .substring(mergeStart, mergeEnd)
      .replaceFirst('  static ', '')
      .replaceAll(r'_$mergeTranslations', 'mergeTranslations');

  final dir = await Directory.systemTemp.createTemp('hw_l10n_run_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final file = File(p.join(dir.path, 'main.dart'));
  await file.writeAsString('$translations\n$merge\nvoid main() {\n$body\n}\n');

  final result = await Process.run(Platform.resolvedExecutable, [file.path]);
  if (result.exitCode != 0) {
    fail('generated code did not run:\n${result.stdout}\n${result.stderr}');
  }
  return (result.stdout as String).trim();
}

String _strings(Directory root, [String? qualifier]) {
  final dirName = qualifier == null ? 'values' : 'values-$qualifier';
  final file = File(
    p.join(
      root.path,
      'android',
      'app',
      'src',
      'main',
      'res',
      dirName,
      'strings.xml',
    ),
  );
  return file.existsSync() ? file.readAsStringSync() : '';
}

void main() {
  group('locale tag conversion', () {
    test('produces Dart identifiers', () {
      expect(localeIdentifier('en'), 'en');
      expect(localeIdentifier('pt-BR'), 'ptBR');
      expect(localeIdentifier('zh-Hant'), 'zhHant');
      expect(localeIdentifier('zh-Hant-TW'), 'zhHantTW');
      expect(localeIdentifier('es-419'), 'es419');
    });

    test('escapes Dart reserved words', () {
      // Icelandic is `is`, which is not a legal parameter name.
      expect(localeIdentifier('is'), 'is_');
      expect(localeIdentifier('in'), 'in_');
      expect(localeIdentifier('de'), 'de');
    });

    test('produces Android resource qualifiers, which are not BCP-47', () {
      expect(androidLocaleQualifier('de'), 'de');
      expect(androidLocaleQualifier('pt-BR'), 'pt-rBR');
      expect(androidLocaleQualifier('zh-Hant'), 'b+zh+Hant');
      expect(androidLocaleQualifier('zh-Hant-TW'), 'b+zh+Hant+TW');
    });

    test('routes a UN M.49 region through the BCP-47 form', () {
      // `values-es-r419` is not a qualifier Android understands: the legacy
      // form takes an ISO 3166-1 alpha-2 region and nothing else.
      expect(androidLocaleQualifier('es-419'), 'b+es+419');
      expect(androidLocaleQualifier('es_419'), 'b+es+419');
      expect(androidLocaleQualifier('sr-Latn-419'), 'b+sr+Latn+419');
    });

    test('accepts language[-Script][-REGION] tags', () {
      expect(isWellFormedLocaleTag('de'), isTrue);
      expect(isWellFormedLocaleTag('fil'), isTrue);
      expect(isWellFormedLocaleTag('pt-BR'), isTrue);
      expect(isWellFormedLocaleTag('pt_BR'), isTrue);
      expect(isWellFormedLocaleTag('zh-Hant'), isTrue);
      expect(isWellFormedLocaleTag('zh-Hant-TW'), isTrue);
      expect(isWellFormedLocaleTag('es-419'), isTrue);
    });

    test('rejects malformed tags and shapes with no implemented mapping', () {
      expect(isWellFormedLocaleTag('d'), isFalse);
      expect(isWellFormedLocaleTag('German'), isFalse);
      expect(isWellFormedLocaleTag(''), isFalse);
      expect(isWellFormedLocaleTag('de-'), isFalse);
      // Syntactically valid BCP-47, but the generator emits nothing for
      // variants or extensions.
      expect(isWellFormedLocaleTag('de-CH-1901'), isFalse);
      expect(isWellFormedLocaleTag('zh-Hant-TW-u-ca-chinese'), isFalse);
      // A plausible typo stays valid — shape checking is not spell checking.
      expect(isWellFormedLocaleTag('ed'), isTrue);
    });

    test('escapes Android string resource text', () {
      expect(androidStringResourceText("l'application"), r"l\'application");
      expect(androidStringNeedsFormattedFalse('100% done'), isTrue);
      expect(androidStringNeedsFormattedFalse('done'), isFalse);
    });
  });

  group('Android generation', () {
    test('reads constant translations from string resources', () async {
      final root = await _project();
      final constant = _localized(isConstant: true);
      final spec = _spec(widget: HWText(constant));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      expect(
        kotlin,
        contains('context.getString(R.string.${constant.resourceName})'),
      );
      // Nothing is matched at render time any more, so no resolver ships.
      expect(kotlin, isNot(contains('hwCurrentLocales')));
      expect(kotlin, isNot(contains('hwLocalize')));
      expect(kotlin, isNot(contains('"de" to "Hallo"')));
      // Constants are not data, so no data class and no preferences read.
      expect(kotlin, isNot(contains('fromPreferences')));
      expect(kotlin, isNot(contains('hwReadLocalized')));
    });

    test('writes a constant into values and every translated locale', () async {
      final root = await _project();
      final constant = _localized(isConstant: true);
      final spec = _spec(widget: HWText(constant));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final name = constant.resourceName;
      expect(name, startsWith('home_widget_greeting_t_'));
      expect(_strings(root), contains('<string name="$name">Hello</string>'));
      expect(_strings(root, 'de'), contains('name="$name">Hallo'));
      expect(_strings(root, 'pt-rBR'), contains('name="$name">Ola'));
    });

    test('prunes the entries of an edited constant', () async {
      final root = await _project();
      final valuesDir = Directory(
        p.join(root.path, 'android/app/src/main/res/values'),
      );
      await valuesDir.create(recursive: true);
      await File(p.join(valuesDir.path, 'strings.xml')).writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Meine App</string>
</resources>
''');

      final before = _localized(isConstant: true);
      await AndroidGenerator(
        spec: _spec(widget: HWText(before)),
        projectRoot: root,
      ).generate();

      final after = _localized(
        isConstant: true,
        values: const {'en': 'Hi', 'de': 'Hallo', 'pt-BR': 'Ola'},
      );
      await AndroidGenerator(
        spec: _spec(widget: HWText(after)),
        projectRoot: root,
      ).generate();

      expect(after.resourceName, isNot(before.resourceName));
      expect(_strings(root), contains(after.resourceName));
      expect(_strings(root), isNot(contains(before.resourceName)));
      expect(_strings(root, 'de'), contains(after.resourceName));
      expect(_strings(root, 'de'), isNot(contains(before.resourceName)));
      // Anything outside our prefix is left alone.
      expect(_strings(root), contains('app_name'));
    });

    test('wires a locale-change refresh only for localized widgets', () async {
      String receiverSource(Directory root) => File(
            p.join(
              root.path,
              'android/app/src/main/kotlin/com/example/'
              'GreetingHomeWidgetReceiver.kt',
            ),
          ).readAsStringSync();

      Future<String> manifestAfter(Directory root, WidgetSpec spec) async {
        final manifest = File(
          p.join(root.path, 'android/app/src/main/AndroidManifest.xml'),
        );
        await manifest.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
    </application>
</manifest>
''');
        await AndroidGenerator(spec: spec, projectRoot: root).generate();
        return manifest.readAsStringSync();
      }

      // A keyed string is resolved at render time...
      final keyedRoot = await _project();
      final keyedManifest =
          await manifestAfter(keyedRoot, _spec(widget: HWText(_localized())));
      expect(
        receiverSource(keyedRoot),
        contains('Intent.ACTION_LOCALE_CHANGED'),
      );
      expect(keyedManifest, contains('android.intent.action.LOCALE_CHANGED'));

      // ...and so is a constant, which reads through `R.string`.
      final constantRoot = await _project();
      final constantManifest = await manifestAfter(
        constantRoot,
        _spec(widget: HWText(_localized(isConstant: true))),
      );
      expect(
        receiverSource(constantRoot),
        contains('Intent.ACTION_LOCALE_CHANGED'),
      );
      expect(
        constantManifest,
        contains('android.intent.action.LOCALE_CHANGED'),
      );

      // A widget with no localized content renders nothing that goes stale.
      final plainRoot = await _project();
      final plainManifest = await manifestAfter(
        plainRoot,
        _spec(widget: HWText.fixed('Hello'), localization: null),
      );
      expect(receiverSource(plainRoot), isNot(contains('onReceive')));
      expect(plainManifest, isNot(contains('LOCALE_CHANGED')));

      // Gallery translations do not count: the launcher resolves the name and
      // description itself, without the widget being re-rendered.
      final galleryRoot = await _project();
      final galleryManifest = await manifestAfter(
        galleryRoot,
        _spec(
          widget: HWText.fixed('Hello'),
          localization: const HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
            name: {'de': 'Begrüßung'},
          ),
        ),
      );
      expect(receiverSource(galleryRoot), isNot(contains('onReceive')));
      expect(galleryManifest, isNot(contains('LOCALE_CHANGED')));
    });

    test('threads the locales into the data class for keyed strings', () async {
      final root = await _project();
      final spec = _spec(widget: HWText(_localized()));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      expect(
        kotlin,
        contains(
          'fun fromPreferences(prefs: android.content.SharedPreferences, '
          'locales: List<String>)',
        ),
      );
      expect(kotlin, contains('fromPreferences(prefs, hwLocales)'));
      expect(kotlin, contains('private fun hwReadLocalized('));
    });

    test('reads one key holding every translation', () async {
      final root = await _project();
      final spec = _spec(widget: HWText(_localized()));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      expect(
        kotlin,
        contains(
          'hwReadLocalized(prefs, "\${PREFERENCES_PREFIX}.greeting", locales,',
        ),
      );
      expect(kotlin, contains('prefs.getString(key, null)'));
      // No per-locale key is ever constructed.
      expect(kotlin, isNot(contains(r'"$key.$tag"')));
      expect(kotlin, isNot(contains('.greeting.en')));
    });

    test('falls back to the compiled map when the blob is unusable', () async {
      final root = await _project();
      final spec = _spec(widget: HWText(_localized()));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      // Malformed JSON must not reach the widget as an exception.
      expect(kotlin, contains('org.json.JSONObject(raw)'));
      expect(kotlin, contains('} catch (_: Exception) {'));
      expect(
        kotlin,
        contains('return hwLocalize(locales, values, baseLocale)'),
      );
      // Non-string members of the object are skipped rather than coerced.
      expect(kotlin, contains('if (value is String) parsed[name] = value'));
    });

    test('resolution walks every preferred locale, not just the first',
        () async {
      final root = await _project();
      final spec = _spec(widget: HWText(_localized()));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      // The whole LocaleList is collected...
      expect(kotlin, contains('for (index in 0 until configured.size())'));
      expect(
        kotlin,
        contains('private fun hwCurrentLocales(context: android.content.Context'
            '): List<String>'),
      );
      // ...and each entry is tried, exact tag then language, before the
      // widget's default locale applies.
      expect(kotlin, contains('for (locale in locales) {'));
      expect(kotlin, contains("val language = tag.substringBefore('-')"));
      expect(kotlin, contains('values[language]?.let { return it }'));
      expect(kotlin, contains('return values[baseLocale]'));
    });

    test('falls onto a region sibling before the default locale', () async {
      final root = await _project();
      final spec = _spec(widget: HWText(_localized()));

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      // pt-PT has neither an exact nor a bare-language entry, so it has to
      // reach pt-BR the way Android's own resource matching would.
      expect(kotlin, contains('for (key in values.keys) {'));
      expect(
        kotlin,
        contains("if (key.substringBefore('-') != language) continue"),
      );
      // Deterministic when several regions match.
      expect(kotlin, contains('if (current == null || key < current)'));
      // The sibling tier runs inside the per-locale loop, i.e. before the
      // default-locale fallback.
      expect(
        kotlin.indexOf('for (key in values.keys) {'),
        lessThan(kotlin.indexOf('return values[baseLocale]')),
      );
    });

    test('writes gallery strings per locale', () async {
      final root = await _project();
      final spec = _spec(
        widget: const HWText.fixed('body'),
        description: 'Shows a greeting',
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de', 'pt-BR'],
          name: {'de': 'Begruessung', 'pt-BR': 'Saudacao'},
          description: {'de': 'Zeigt etwas', 'pt-BR': 'Mostra algo'},
        ),
      );

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      expect(
        _strings(root),
        contains('<string name="home_widget_greeting_label">Greeting</string>'),
      );
      expect(
        _strings(root, 'de'),
        contains('name="home_widget_greeting_label">Begruessung'),
      );
      expect(
        _strings(root, 'pt-rBR'),
        contains('name="home_widget_greeting_description">Mostra algo'),
      );
    });

    test('leaves an omitted gallery string untranslated', () async {
      final root = await _project();
      final spec = _spec(
        widget: const HWText.fixed('body'),
        name: 'MyAppName',
        description: 'Shows your recent activity',
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
          description: {'de': 'Zeigt Aktivitaet'},
        ),
      );

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      expect(_strings(root), contains('home_widget_greeting_label'));
      // The label has no translated variant; the description does.
      expect(_strings(root, 'de'), isNot(contains('_label')));
      expect(_strings(root, 'de'), contains('_description'));
    });

    test('rewrites its own entries but not the user\'s', () async {
      final root = await _project();
      final spec = _spec(
        widget: const HWText.fixed('body'),
        description: 'First',
        localization: null,
      );
      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final updated = _spec(
        widget: const HWText.fixed('body'),
        description: 'Second',
        localization: null,
      );
      await AndroidGenerator(spec: updated, projectRoot: root).generate();

      final content = _strings(root);
      expect(content, contains('>Second<'));
      expect(content, isNot(contains('>First<')));
      expect('Second'.allMatches(content).length, 1);
    });

    test('prunes locales dropped from the annotation', () async {
      final root = await _project();

      const withFrench = HomeWidgetLocalization(
        defaultLocale: 'en',
        supportedLocales: ['en', 'de', 'fr'],
        name: {'de': 'Begruessung', 'fr': 'Salutation'},
      );
      await AndroidGenerator(
        spec: _spec(
          widget: const HWText.fixed('body'),
          localization: withFrench,
        ),
        projectRoot: root,
      ).generate();
      expect(_strings(root, 'fr'), contains('home_widget_greeting_label'));

      // French dropped from the annotation.
      const withoutFrench = HomeWidgetLocalization(
        defaultLocale: 'en',
        supportedLocales: ['en', 'de'],
        name: {'de': 'Begruessung'},
      );
      await AndroidGenerator(
        spec: _spec(
          widget: const HWText.fixed('body'),
          localization: withoutFrench,
        ),
        projectRoot: root,
      ).generate();

      expect(
        _strings(root, 'fr'),
        isNot(contains('home_widget_greeting_label')),
      );
      expect(_strings(root, 'de'), contains('home_widget_greeting_label'));
    });

    test('pruning leaves other resources and non-locale dirs alone', () async {
      final root = await _project();
      final resDir = p.join(root.path, 'android/app/src/main/res');

      for (final dir in ['values-fr', 'values-night']) {
        await Directory(p.join(resDir, dir)).create(recursive: true);
        await File(p.join(resDir, dir, 'strings.xml')).writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="home_widget_greeting_label">stale</string>
    <string name="app_name">Meine App</string>
</resources>
''');
      }

      await AndroidGenerator(
        spec: _spec(
          widget: const HWText.fixed('body'),
          localization: const HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
            name: {'de': 'Begruessung'},
          ),
        ),
        projectRoot: root,
      ).generate();

      // Our entry is pruned from the stale locale...
      expect(
        _strings(root, 'fr'),
        isNot(contains('home_widget_greeting_label')),
      );
      // ...but the user's own string in that file survives.
      expect(_strings(root, 'fr'), contains('app_name'));
      // ...and a non-locale qualifier is never swept.
      expect(_strings(root, 'night'), contains('home_widget_greeting_label'));
    });

    test('removes the legacy unprefixed description entry', () async {
      final root = await _project();
      final valuesDir = Directory(
        p.join(root.path, 'android/app/src/main/res/values'),
      );
      await valuesDir.create(recursive: true);
      await File(p.join(valuesDir.path, 'strings.xml')).writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="greeting_home_widget_description">stale</string>
    <string name="greeting_home_widget_description_custom">mine</string>
</resources>
''');

      final spec = _spec(
        widget: const HWText.fixed('body'),
        description: 'Fresh',
        localization: null,
      );
      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final content = _strings(root);
      expect(content, isNot(contains('"greeting_home_widget_description"')));
      // A similarly named entry that is not an exact match survives.
      expect(content, contains('greeting_home_widget_description_custom'));
    });

    test('writes a UN M.49 locale to its BCP-47 resource directory', () async {
      final root = await _project();
      final constant = _localized(
        isConstant: true,
        values: const {'en': 'Hello', 'es-419': 'Hola'},
      );
      final spec = _spec(
        widget: HWText(constant),
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'es-419'],
        ),
      );

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      expect(
        _strings(root, 'b+es+419'),
        contains('name="${constant.resourceName}">Hola'),
      );
      // `values-es-r419` is not a qualifier Android resolves, so it must never
      // be written.
      expect(
        Directory(
          p.join(root.path, 'android/app/src/main/res/values-es-r419'),
        ).existsSync(),
        isFalse,
      );
    });
  });

  group('Android R import', () {
    late _MockLogger mockLogger;

    setUp(() {
      final saved = logger;
      mockLogger = _MockLogger();
      logger = mockLogger;
      when(() => mockLogger.detail(any())).thenReturn(null);
      when(() => mockLogger.info(any())).thenReturn(null);
      when(() => mockLogger.warn(any())).thenReturn(null);
      addTearDown(() => logger = saved);
    });

    Future<void> writeGradle(Directory root, String content) async {
      final file = File(p.join(root.path, 'android', 'app', 'build.gradle'));
      await file.create(recursive: true);
      await file.writeAsString(content);
    }

    Future<String> generateKotlin(
      Directory root,
      WidgetSpec spec, {
      String packageDir = 'com/example',
    }) async {
      await AndroidGenerator(spec: spec, projectRoot: root).generate();
      return File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/$packageDir/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();
    }

    // `ensureAndroidManifestReceiver` warns about the absent manifest in these
    // fixtures, so the assertion has to name the warning under test.
    void verifyNoNamespaceWarning() => verifyNever(
          () => mockLogger.warn(
            any(that: contains('could not detect the Android namespace')),
          ),
        );

    test('imports R from the namespace, not from the widget package', () async {
      final root = await _project();
      await writeGradle(root, """
android {
    namespace 'com.the.namespace'
}
""");

      final kotlin = await generateKotlin(
        root,
        _spec(widget: HWText(_localized(isConstant: true))),
      );

      expect(kotlin, contains('import com.the.namespace.R'));
      verifyNoNamespaceWarning();
    });

    test('imports the namespace R even when applicationId differs', () async {
      final root = await _project();
      await writeGradle(root, """
android {
    namespace 'com.the.namespace'

    defaultConfig {
        applicationId 'com.other.app'
    }
}
""");

      // No packageName configured: the file lands next to the applicationId,
      // which is not where `R` is generated.
      final kotlin = await generateKotlin(
        root,
        _spec(
          widget: HWText(_localized(isConstant: true)),
          android: null,
        ),
        packageDir: 'com/other/app',
      );

      expect(kotlin, contains('import com.the.namespace.R'));
    });

    test('emits no import when the widget already lives in the namespace',
        () async {
      final root = await _project();
      await writeGradle(root, '''
android {
    namespace = "com.example"
}
''');

      final kotlin = await generateKotlin(
        root,
        _spec(widget: HWText(_localized(isConstant: true))),
      );

      expect(kotlin, contains('R.string.'));
      expect(kotlin, isNot(contains('import com.example.R')));
      verifyNoNamespaceWarning();
    });

    test('warns when the namespace cannot be detected', () async {
      final root = await _project();

      await generateKotlin(
        root,
        _spec(widget: HWText(_localized(isConstant: true))),
      );

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('could not detect the Android namespace'),
              contains('GreetingHomeWidget.kt'),
              contains('R.string'),
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('iOS generation', () {
    Future<String> generateSwift(WidgetSpec spec) async {
      final root = await _project();
      await IosGenerator(spec: spec, projectRoot: root).generate();
      return File(
        p.join(root.path, 'ios', 'GreetingHomeWidget', 'Widget.swift'),
      ).readAsStringSync();
    }

    Future<Map<String, dynamic>> generateCatalog(WidgetSpec spec) async {
      final root = await _project();
      await IosGenerator(spec: spec, projectRoot: root).generate();
      final file = File(
        p.join(
          root.path,
          'ios',
          'GreetingHomeWidget',
          'Localizable.xcstrings',
        ),
      );
      if (!file.existsSync()) return const {};
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }

    test('reads constant translations from the string catalog', () async {
      final constant = _localized(isConstant: true);
      final swift = await generateSwift(_spec(widget: HWText(constant)));

      expect(
        swift,
        contains('NSLocalizedString("${constant.resourceName}", comment: "")'),
      );
      // Nothing is matched at render time any more, so no resolver ships.
      expect(swift, isNot(contains('hwLocalize')));
      expect(swift, isNot(contains('hwCurrentLocales')));
      expect(swift, isNot(contains('"de": "Hallo"')));
    });

    test('writes the catalog with one entry per locale', () async {
      final constant = _localized(isConstant: true);
      final catalog = await generateCatalog(_spec(widget: HWText(constant)));

      expect(catalog['sourceLanguage'], 'en');
      expect(catalog['version'], '1.0');

      final strings = catalog['strings'] as Map<String, dynamic>;
      final entry = strings[constant.resourceName] as Map<String, dynamic>;
      expect(entry['extractionState'], 'manual');

      final localizations = entry['localizations'] as Map<String, dynamic>;
      expect(localizations.keys, containsAll(['en', 'de', 'pt-BR']));
      expect(
        ((localizations['de'] as Map)['stringUnit'] as Map)['value'],
        'Hallo',
      );
      // The base locale is carried too, so a device set to it still resolves.
      expect(
        ((localizations['en'] as Map)['stringUnit'] as Map)['value'],
        'Hello',
      );
      expect(
        ((localizations['de'] as Map)['stringUnit'] as Map)['state'],
        'translated',
      );
    });

    test('writes no catalog for a widget with nothing to translate', () async {
      final catalog = await generateCatalog(
        _spec(widget: const HWText.fixed('body'), localization: null),
      );
      expect(catalog, isEmpty);
    });

    test('carries translated gallery strings in the catalog', () async {
      final spec = _spec(
        widget: const HWText.fixed('body'),
        description: 'Shows a greeting',
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
          name: {'de': 'Begruessung'},
        ),
      );
      final catalog = await generateCatalog(spec);
      final strings = catalog['strings'] as Map<String, dynamic>;

      expect(strings.keys, contains('home_widget_greeting_label'));
      // The description was never translated, so it stays out of the catalog.
      expect(strings.keys, isNot(contains('home_widget_greeting_description')));

      final localizations = (strings['home_widget_greeting_label']
          as Map<String, dynamic>)['localizations'] as Map<String, dynamic>;
      expect(
        ((localizations['de'] as Map)['stringUnit'] as Map)['value'],
        'Begruessung',
      );
      expect(
        ((localizations['en'] as Map)['stringUnit'] as Map)['value'],
        'Greeting',
      );
    });

    test('keeps a plain literal when the gallery is not translated', () async {
      final swift = await generateSwift(
        _spec(
          widget: const HWText.fixed('body'),
          description: 'Shows a greeting',
          localization: null,
        ),
      );
      // A literal keeps SwiftUI's LocalizedStringKey overload.
      expect(swift, contains('.configurationDisplayName("Greeting")'));
      expect(swift, contains('.description("Shows a greeting")'));
    });

    test('looks gallery strings up once translations exist', () async {
      final swift = await generateSwift(
        _spec(
          widget: const HWText.fixed('body'),
          description: 'Shows a greeting',
          localization: const HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
            name: {'de': 'Begruessung'},
          ),
        ),
      );
      expect(
        swift,
        contains('.configurationDisplayName(NSLocalizedString('
            '"home_widget_greeting_label", comment: ""))'),
      );
      // Description was not translated, so it stays a literal.
      expect(swift, contains('.description("Shows a greeting")'));
      // A gallery string alone does not pull in the render-time resolver.
      expect(swift, isNot(contains('func hwLocalize(')));
    });

    test('re-resolves keyed localized strings at render time', () async {
      final swift = await generateSwift(_spec(widget: HWText(_localized())));

      expect(
        swift,
        contains('let prefs = UserDefaults(suiteName: "group.example")'),
      );
      expect(
        swift,
        contains('let data = GreetingData.fromUserDefaults(prefs)'),
      );
      // Display uses the re-resolved value, not the timeline snapshot.
      expect(swift, contains('Text(data.greeting ?? "")'));
      expect(swift, isNot(contains('Text(entry.data.greeting')));
    });

    test('reads one key holding every translation', () async {
      final swift = await generateSwift(_spec(widget: HWText(_localized())));

      expect(
        swift,
        contains('hwReadLocalized(defaults, "\\(paramPrefix).greeting",'),
      );
      expect(swift, contains('defaults?.string(forKey: key)'));
      // No per-locale key is ever constructed.
      expect(swift, isNot(contains(r'"\(key).\(tag)"')));
    });

    test('falls back to the compiled map when the blob is unusable', () async {
      final swift = await generateSwift(_spec(widget: HWText(_localized())));

      expect(swift, contains('try? JSONSerialization.jsonObject(with: data)'));
      expect(swift, contains('let json = object as? [String: Any] else'));
      // Non-string members of the object are skipped rather than coerced.
      expect(swift, contains('if let text = value as? String'));
      expect(
        swift,
        contains(
          'return hwResolveLocalized(locales, values, baseLocale: baseLocale) '
          '?? ""',
        ),
      );
    });

    test('resolution walks every preferred locale, not just the first',
        () async {
      final swift = await generateSwift(_spec(widget: HWText(_localized())));

      expect(swift, contains('func hwCurrentLocales() -> [String]'));
      expect(swift, contains('let preferred = Locale.preferredLanguages.map'));
      expect(swift, isNot(contains('Locale.preferredLanguages.first')));
      expect(swift, contains('for tag in locales {'));
      expect(
        swift,
        contains('if let match = values[language] { return match }'),
      );
      expect(swift, contains('return values[baseLocale]'));
    });

    test('falls onto a region sibling before the default locale', () async {
      final swift = await generateSwift(_spec(widget: HWText(_localized())));

      // pt-PT has neither an exact nor a bare-language entry, so it has to
      // reach pt-BR rather than dropping to the widget's default locale.
      expect(swift, contains('let siblings = values.keys.filter {'));
      expect(
        swift,
        contains(
          r'$0.split(separator: "-").first.map(String.init) == language',
        ),
      );
      // Deterministic when several regions match.
      expect(
        swift,
        contains(
          'if let sibling = siblings.min(), let match = values[sibling]',
        ),
      );
      // The sibling tier runs inside the per-locale loop, i.e. before the
      // default-locale fallback.
      expect(
        swift.indexOf('let siblings = values.keys.filter {'),
        lessThan(swift.indexOf('return values[baseLocale]')),
      );
    });
  });

  group('Dart helper generation', () {
    String generate(WidgetSpec spec) => DartHelperGenerator(spec).generate();

    test('emits a translations class with every locale required', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(dart, contains('class GreetingHomeWidgetTranslations'));
      expect(dart, contains('required this.en'));
      expect(dart, contains('required this.de'));
      expect(dart, contains('required this.ptBR'));
      expect(dart, contains("'pt-BR': ptBR"));
      // The old name must be gone, not merely shadowed.
      expect(dart, isNot(contains('HomeWidgetLocalizations')));
    });

    test('saves every translation as one JSON blob under a single key', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(dart, contains("import 'dart:convert';"));
      expect(dart, contains('GreetingHomeWidgetTranslations? greeting'));
      expect(
        dart,
        contains(
          "if (greeting != null) HomeWidget.saveWidgetData<String>("
          "'\${_\$paramPrefix}.greeting', jsonEncode(greeting.toMap())",
        ),
      );
      // The old layout wrote one entry per locale.
      expect(dart, isNot(contains('toMap().entries.map')));
      expect(dart, isNot(contains(r"greeting.${entry.key}")));
    });

    test('deletes the single key rather than looping locales', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(
        dart,
        contains("if (greeting) HomeWidget.saveWidgetData('\${_\$paramPrefix}"
            ".greeting', null,"),
      );
      expect(dart, isNot(contains(r"greeting.$locale")));
    });

    test('reads localized fields back as the typed class, never null', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      // The record field is the generated class and is non-nullable: the
      // compiled defaults make every locale total.
      expect(
        dart,
        contains('Future<({GreetingHomeWidgetTranslations greeting})>'),
      );
      expect(dart, isNot(contains('Map<String, String>? greeting')));
      expect(dart, contains(r'_$readLocalized'));
      expect(dart, contains('decoded = jsonDecode(raw);'));
      // Malformed or non-object storage reads back as null, never throws.
      expect(dart, contains('} on FormatException {'));
      expect(dart, contains('if (decoded is! Map) return null;'));
      expect(
        dart,
        contains('if (locale is String && value is String) '
            'values[locale] = value;'),
      );
      // The raw escape hatch is documented on getData.
      expect(dart, contains('`HomeWidget.getWidgetData`'));
    });

    test('exposes the compiled translations as a const, one per key', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(
        dart,
        contains(
          'static const GreetingHomeWidgetTranslations greetingDefaults =',
        ),
      );
      expect(dart, contains("en: 'Hello',"));
      expect(dart, contains("de: 'Hallo',"));
      expect(dart, contains("ptBR: 'Ola',"));
    });

    test('escapes translations that would break the const literal', () {
      final dart = generate(
        _spec(
          widget: HWText(
            _localized(
              values: const {
                'en': "it's\na \\ backslash",
                'de': r'a $dollar',
                'pt-BR': 'Ola',
              },
            ),
          ),
        ),
      );

      expect(dart, contains(r"en: 'it\'s\na \\ backslash',"));
      expect(dart, contains(r"de: 'a \$dollar',"));
      // The newline stayed escaped: the value occupies exactly one source line.
      final valueLines =
          dart.split('\n').where((l) => l.contains('backslash')).toList();
      expect(valueLines, hasLength(1));
      expect(valueLines.single, endsWith("',"));
    });

    test('getData merges stored values over the compiled defaults', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(
        dart,
        contains(
          r'greeting: _$mergeTranslations(greetingDefaults, '
          r"await _$readLocalized('${_$paramPrefix}.greeting')),",
        ),
      );
      // One shared helper rather than the merge inlined per field.
      expect(
        dart,
        contains(
          r'static GreetingHomeWidgetTranslations _$mergeTranslations(',
        ),
      );
      expect(dart, contains('if (stored == null) return defaults;'));
      // Stored wins; an absent locale keeps its compiled default.
      expect(dart, contains("en: stored['en'] ?? defaults.en,"));
      expect(dart, contains("de: stored['de'] ?? defaults.de,"));
      expect(dart, contains("ptBR: stored['pt-BR'] ?? defaults.ptBR,"));
      expect(
        r'greeting: _$mergeTranslations('.allMatches(dart).length,
        1,
      );
    });

    test('resolve mirrors the native chain, default locale last', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(dart, contains('String resolve(String tag) {'));
      // Region/script sibling, lexicographically smallest on ties — the same
      // rule the Kotlin and Swift helpers apply.
      expect(
        dart,
        contains('if (sibling == null || key.compareTo(sibling) < 0) '
            'sibling = key;'),
      );
      // The default locale is the last resort, after the sibling tier.
      final resolveBody = dart.substring(dart.indexOf('String resolve('));
      expect(
        resolveBody.indexOf('sibling'),
        lessThan(resolveBody.indexOf('return en;')),
      );
    });

    test('the emitted resolve and merge behave as documented', () async {
      final dart = generate(_spec(widget: HWText(_localized())));

      final output = await _runGenerated(dart, '''
const defaults = GreetingHomeWidgetTranslations(
  en: 'Hello', de: 'Hallo', ptBR: 'Ola',
);
print(defaults.resolve('de'));                 // exact tag
print(defaults.resolve('de-AT'));              // bare language
print(defaults.resolve('pt-PT'));              // region sibling
print(defaults.resolve('pt_BR'));              // '_' normalized to '-'
print(defaults.resolve('fr'));                 // default locale
print(defaults.resolve(''));                   // default locale
print(mergeTranslations(defaults, null).de);   // nothing stored
final merged = mergeTranslations(defaults, {'de': 'Servus'});
print(merged.de);                              // stored override wins
print(merged.en);                              // absent locale keeps default
print(merged.ptBR);
''');

      expect(output.split('\n'), [
        'Hallo',
        'Hallo',
        'Ola',
        'Ola',
        'Hello',
        'Hello',
        'Hallo',
        'Servus',
        'Hello',
        'Ola',
      ]);
    });

    test('the sibling tier breaks ties on the smallest key', () async {
      final dart = generate(
        _spec(
          widget: HWText(
            _localized(
              values: const {
                'en': 'Hello',
                'pt-MZ': 'Ola MZ',
                'pt-BR': 'Ola BR',
              },
            ),
          ),
          localization: const HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'pt-MZ', 'pt-BR'],
          ),
        ),
      );

      final output = await _runGenerated(dart, '''
const defaults = GreetingHomeWidgetTranslations(
  en: 'Hello', ptMZ: 'Ola MZ', ptBR: 'Ola BR',
);
print(defaults.resolve('pt-PT'));   // two siblings; smallest key wins
print(defaults.resolve('pt'));      // no bare entry, same tie-break
print(defaults.resolve('pt-MZ'));   // exact still beats the sibling scan
''');

      expect(output.split('\n'), ['Ola BR', 'Ola BR', 'Ola MZ']);
    });

    test('constant strings never reach the Dart API', () {
      final dart = generate(
        _spec(widget: HWText(_localized(isConstant: true))),
      );
      expect(dart, isNot(contains('Translations')));
      expect(dart, isNot(contains('saveData')));
    });
  });

  group('validation', () {
    void validate(WidgetSpec spec) => validateWidgetData(spec);

    test('requires a localization block', () {
      expect(
        () => validate(
          _spec(widget: HWText(_localized()), localization: null),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('has no localization'),
          ),
        ),
      );
    });

    test('rejects a locale outside supportedLocales', () {
      expect(
        () => validate(
          _spec(
            widget: HWText(
              _localized(values: const {'en': 'Hello', 'fr': 'Bonjour'}),
            ),
          ),
        ),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('rejects an incomplete map but allows omission', () {
      expect(
        () => validate(
          _spec(
            widget: HWText(_localized(values: const {'en': 'Hello'})),
          ),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('missing translations for de, pt-BR'),
          ),
        ),
      );

      // Omitting the gallery maps entirely is fine.
      expect(
        () => validate(
          _spec(widget: const HWText.fixed('body'), description: 'plain'),
        ),
        returnsNormally,
      );
    });

    test('rejects the default locale in a gallery map', () {
      expect(
        () => validate(
          _spec(
            widget: const HWText.fixed('body'),
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en', 'de'],
              name: {'en': 'Greeting', 'de': 'Begruessung'},
            ),
          ),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('second source of truth'),
          ),
        ),
      );
    });

    test('rejects placeholders, which a per-locale map cannot express', () {
      expect(
        () => validate(
          _spec(
            widget: HWText(
              _localized(
                values: const {
                  'en': '{count} items',
                  'de': '{count} Dinge',
                  'pt-BR': '{count} itens',
                },
              ),
            ),
          ),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('placeholder'),
          ),
        ),
      );
    });

    test('rejects a localized string nested in HWJson', () {
      final json = HWJson('profile', _localized());
      expect(
        () => validate(_spec(widget: HWText(json))),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('cannot be nested inside HWJson'),
          ),
        ),
      );
    });

    test('rejects a malformed locale in supportedLocales', () {
      expect(
        () => validate(
          _spec(
            widget: const HWText.fixed('body'),
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en', 'de-CH-1901'],
              name: {'de-CH-1901': 'Grüezi'},
            ),
          ),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('is not a supported locale tag'),
          ),
        ),
      );
    });

    test('rejects a defaultLocale outside supportedLocales', () {
      expect(
        () => validate(
          _spec(
            widget: HWText(_localized()),
            localization: const HomeWidgetLocalization(
              defaultLocale: 'fr',
              supportedLocales: ['en', 'de', 'pt-BR'],
            ),
          ),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('is not in supportedLocales'),
          ),
        ),
      );
    });
  });
}
