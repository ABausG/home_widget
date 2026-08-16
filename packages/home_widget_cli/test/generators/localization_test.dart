import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/naming.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
    HWLocalizedString.resolved(
      isConstant ? '' : key,
      defaultValues: values,
      isConstant: isConstant,
      defaultLocale: 'en',
    );

WidgetSpec _spec({
  required HWWidget widget,
  HomeWidgetLocalization? localization = _localization,
  String? description,
  String name = 'Greeting',
}) {
  final tree = widget;
  return WidgetSpec(
    data: HomeWidget(
      name: name,
      description: description,
      widget: tree,
      android: const HomeWidgetAndroidConfiguration(packageName: 'com.example'),
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
      expect(localeIdentifier('zh-Hant'), 'zhHANT');
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
    test('inlines constant translations and resolves the locale', () async {
      final root = await _project();
      final spec = _spec(
        widget: HWText(_localized(isConstant: true)),
      );

      await AndroidGenerator(spec: spec, projectRoot: root).generate();

      final kotlin = File(
        p.join(
          root.path,
          'android/app/src/main/kotlin/com/example/GreetingHomeWidget.kt',
        ),
      ).readAsStringSync();

      expect(kotlin, contains('val hwLocale = hwCurrentLocale(context)'));
      expect(kotlin, contains('private fun hwLocalize('));
      expect(kotlin, contains('"de" to "Hallo"'));
      // Constants are inlined, so no data class and no preferences read.
      expect(kotlin, isNot(contains('fromPreferences')));
      expect(kotlin, isNot(contains('hwReadLocalized')));
    });

    test('threads the locale into the data class for keyed strings', () async {
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
          'locale: String)',
        ),
      );
      expect(kotlin, contains('fromPreferences(prefs, hwLocale)'));
      expect(kotlin, contains('private fun hwReadLocalized('));
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
          _strings(root, 'fr'), isNot(contains('home_widget_greeting_label')));
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
          _strings(root, 'fr'), isNot(contains('home_widget_greeting_label')));
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
  });

  group('iOS generation', () {
    Future<String> generateSwift(WidgetSpec spec) async {
      final root = await _project();
      await IosGenerator(spec: spec, projectRoot: root).generate();
      return File(
        p.join(root.path, 'ios', 'GreetingHomeWidget', 'Widget.swift'),
      ).readAsStringSync();
    }

    test('inlines constant translations', () async {
      final swift = await generateSwift(
        _spec(widget: HWText(_localized(isConstant: true))),
      );
      expect(swift, contains('func hwLocalize('));
      expect(swift, contains('"de": "Hallo"'));
      expect(swift, contains('baseLocale: "en"'));
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

    test('computes gallery strings once translations exist', () async {
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
        contains('.configurationDisplayName(hwLocalize(['),
      );
      // Description was not translated, so it stays a literal.
      expect(swift, contains('.description("Shows a greeting")'));
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
  });

  group('Dart helper generation', () {
    String generate(WidgetSpec spec) => DartHelperGenerator(spec).generate();

    test('emits a localizations class with every locale required', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(dart, contains('class GreetingHomeWidgetLocalizations'));
      expect(dart, contains('required this.en'));
      expect(dart, contains('required this.de'));
      expect(dart, contains('required this.ptBR'));
      expect(dart, contains("'pt-BR': ptBR"));
    });

    test('saves and deletes each locale variant', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(dart, contains('GreetingHomeWidgetLocalizations? greeting'));
      expect(dart, contains('greeting.toMap().entries.map'));
      expect(dart, contains("'en', 'de', 'pt-BR'"));
    });

    test('reads localized fields back as a raw map', () {
      final dart = generate(_spec(widget: HWText(_localized())));

      expect(dart, contains('Map<String, String>? greeting'));
      expect(dart, contains(r'_$readLocalized'));
    });

    test('constant strings never reach the Dart API', () {
      final dart = generate(
        _spec(widget: HWText(_localized(isConstant: true))),
      );
      expect(dart, isNot(contains('Localizations')));
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
