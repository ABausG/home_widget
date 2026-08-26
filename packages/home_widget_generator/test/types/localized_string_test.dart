import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

Future<HWWidget> parseCode(String code) async {
  final file = File(
    p.join(
      Directory.current.path,
      'test',
      'temp_spike_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

$code
''');
  try {
    final collection = AnalysisContextCollection(
      includedPaths: [file.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final context = collection.contextFor(file.path);
    final result = await context.currentSession.getResolvedUnit(file.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('Failed to resolve');
    }
    final element = result.unit.declaredFragment!.element.classes.first;
    final annotation = element.metadata.annotations.firstWhere(
      (m) => m.element?.enclosingElement?.name == 'HomeWidget',
    );
    return WidgetTreeParser(annotation).parse();
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

void main() {
  group('HWLocalizedString', () {
    const values = {'en': 'Hello', 'de': 'Hallo', 'pt-BR': 'Ola'};

    HWLocalizedString localized({
      String key = 'greeting',
      bool isConstant = false,
      String? defaultLocale = 'en',
      Map<String, String> defaultTranslations = values,
      String? resourcePrefix = 'home_widget_greeting',
    }) =>
        HWLocalizedString.resolved(
          key,
          defaultTranslations: defaultTranslations,
          isConstant: isConstant,
          defaultLocale: defaultLocale,
          resourcePrefix: resourcePrefix,
        );

    test('dedupes in a Set despite Dart maps not being structurally equal', () {
      final a = localized();
      final b = localized();
      expect(a, equals(b));
      expect({a, b}, hasLength(1));
    });

    test('differing translations are not equal', () {
      expect(
        localized(),
        isNot(equals(localized(defaultTranslations: const {'en': 'Hi'}))),
      );
    });

    test('baseValue follows the stamped default locale', () {
      expect(localized().baseValue, 'Hello');
      expect(localized(defaultLocale: 'de').baseValue, 'Hallo');
    });

    test('falls back to the first entry when no default locale is stamped', () {
      expect(localized(defaultLocale: null).baseLocaleTag, 'en');
    });

    test('constant form reads the platform string resource', () {
      final constant = localized(key: '', isConstant: true);
      final name = constant.resourceName;
      expect(name, matches(r'^home_widget_greeting_t_[0-9a-f]{8}$'));
      expect(
        constant.kotlinAccess('widgetData'),
        'context.getString(R.string.$name)',
      );
      expect(
        constant.swiftAccess('entry.data'),
        'NSLocalizedString("$name", comment: "")',
      );
    });

    test('the resource name follows the content, not the ordering', () {
      final constant = localized(key: '', isConstant: true);
      final reordered = localized(
        key: '',
        isConstant: true,
        defaultTranslations: const {
          'pt-BR': 'Ola',
          'de': 'Hallo',
          'en': 'Hello',
        },
      );
      expect(reordered.resourceName, constant.resourceName);

      final edited = localized(
        key: '',
        isConstant: true,
        defaultTranslations: const {
          'en': 'Hello',
          'de': 'Hallo!',
          'pt-BR': 'Ola',
        },
      );
      expect(edited.resourceName, isNot(constant.resourceName));
    });

    test('the resource name is namespaced by the widget', () {
      final other = localized(
        key: '',
        isConstant: true,
        resourcePrefix: 'home_widget_other',
      );
      expect(other.resourceName, startsWith('home_widget_other_t_'));
      // An unstamped instance still lands under the generated namespace.
      expect(
        localized(key: '', isConstant: true, resourcePrefix: null).resourceName,
        startsWith('home_widget_t_'),
      );
    });

    test('constant form does not append a null fallback', () {
      final constant = localized(key: '', isConstant: true);
      expect(
        constant.androidToString(outerValue: 'x', innerValue: 'x'),
        'x',
      );
      expect(constant.iosToString(outerValue: 'x', innerValue: 'x'), 'x');
    });

    test('keyed form reads through preferences first', () {
      final keyed = localized();
      // One key holds every translation, and the preferred-language list is
      // threaded in so the helper can walk it.
      expect(
        keyed.androidReadValue(store: 'prefs', key: 'p.greeting'),
        startsWith('hwReadLocalized(prefs, "p.greeting", locales, mapOf('),
      );
      expect(
        keyed.iosReadValue(store: 'defaults', key: 'p.greeting'),
        startsWith('hwReadLocalized(defaults, "p.greeting", ['),
      );
      expect(
        keyed.iosReadValue(store: 'defaults', key: 'p.greeting'),
        contains('baseLocale: "en"'),
      );
      // The field stays nullable in the data class, so the elvis is wanted.
      expect(
        keyed.androidToString(outerValue: 'd.greeting', innerValue: 'x'),
        'd.greeting ?: ""',
      );
    });

    test('the public keyed constructor ships translations unstamped', () {
      const keyed = HWLocalizedString('greeting', defaultTranslations: values);
      expect(keyed.key, 'greeting');
      expect(keyed.isConstant, isFalse);
      // Annotation-space cannot know either of these.
      expect(keyed.defaultLocale, isNull);
      expect(keyed.resourcePrefix, isNull);
      // With no locale stamped on, the first entry anchors the fallback chain.
      expect(keyed.baseLocaleTag, 'en');
      expect(keyed.baseValue, 'Hello');
    });

    test('the constant constructor carries an empty key', () {
      const constant = HWLocalizedString.constant(defaultTranslations: values);
      expect(constant.key, '');
      expect(constant.isConstant, isTrue);
      expect(constant.defaultLocale, isNull);
      expect(constant.defaultTranslations, values);
    });

    test('withDefaultLocale re-anchors the base value and keeps the rest', () {
      final constant = localized(key: '', isConstant: true);
      final german = constant.withDefaultLocale('de');
      expect(german.defaultLocale, 'de');
      expect(german.baseLocaleTag, 'de');
      expect(german.baseValue, 'Hallo');
      expect(german.isConstant, isTrue);
      expect(german.key, '');
      expect(german.resourcePrefix, 'home_widget_greeting');
      // Only the anchor moved, so the shipped resource is unchanged.
      expect(german.resourceName, constant.resourceName);
    });

    test('withDefaultLocale ignores a locale it has no translation for', () {
      expect(localized().withDefaultLocale('fr').baseLocaleTag, 'en');
    });

    test('keyed form keeps the null-coalescing fallback on iOS', () {
      expect(
        localized().iosToString(outerValue: 'd.greeting', innerValue: 'x'),
        'd.greeting ?? ""',
      );
    });

    test('codegen defaults fall back to the base-locale text', () {
      expect(localized().codegenKotlinDefaultLiteral(), '"Hello"');
      expect(localized().codegenSwiftDefaultLiteral(), '"Hello"');
      expect(
        localized(defaultLocale: 'de').codegenKotlinDefaultLiteral(),
        '"Hallo"',
      );
      expect(
        localized(defaultLocale: 'de').codegenSwiftDefaultLiteral(),
        '"Hallo"',
      );
    });

    test('codegen defaults escape per target language', () {
      final tricky = localized(defaultTranslations: const {'en': r'a"b$c'});
      expect(tricky.codegenKotlinDefaultLiteral(), r'"a\"b\$c"');
      expect(tricky.codegenSwiftDefaultLiteral(), r'"a\"b$c"');
    });

    test('an empty translation map degrades to empty literals', () {
      final empty = localized(defaultTranslations: const {});
      expect(empty.baseLocaleTag, '');
      expect(empty.baseValue, '');
      expect(empty.kotlinMapLiteral, 'emptyMap()');
      expect(empty.swiftMapLiteral, '[:]');
      expect(empty.codegenKotlinDefaultLiteral(), '""');
      expect(empty.codegenSwiftDefaultLiteral(), '""');
    });

    test('map literals list every translation', () {
      expect(
        localized().kotlinMapLiteral,
        'mapOf("en" to "Hello", "de" to "Hallo", "pt-BR" to "Ola")',
      );
      expect(
        localized().swiftMapLiteral,
        '["en": "Hello", "de": "Hallo", "pt-BR": "Ola"]',
      );
    });

    test('equality distinguishes the stamped parser context', () {
      expect(localized(), isNot(equals(localized(defaultLocale: 'de'))));
      expect(localized(), isNot(equals(localized(key: 'other'))));
      expect(
        localized(),
        isNot(equals(localized(resourcePrefix: 'home_widget_other'))),
      );
      expect(localized(), isNot(equals(localized(isConstant: true))));
      expect(localized() == Object(), isFalse);
    });

    test('hashCode follows translation content, not ordering', () {
      expect(localized().hashCode, localized().hashCode);
      expect(
        localized().hashCode,
        localized(
          defaultTranslations: const {
            'pt-BR': 'Ola',
            'de': 'Hallo',
            'en': 'Hello',
          },
        ).hashCode,
      );
      expect(
        localized().hashCode,
        isNot(localized(defaultTranslations: const {'en': 'Hi'}).hashCode),
      );
    });

    test('escapes characters that would break the generated literal', () {
      final tricky = localized(
        defaultTranslations: const {'en': 'a"b\\c\nd\$e'},
        defaultLocale: 'en',
      );
      expect(tricky.kotlinMapLiteral, contains(r'\"'));
      expect(tricky.kotlinMapLiteral, contains(r'\n'));
      expect(tricky.kotlinMapLiteral, contains(r'\$'));
      expect(tricky.kotlinMapLiteral.split('\n'), hasLength(1));
      expect(tricky.swiftMapLiteral.split('\n'), hasLength(1));
    });
  });

  test('HWString.localized decodes through the redirecting factory', () async {
    final widget = await parseCode('''
@HomeWidget(
  name: 'Greeting',
  widget: HWText(HWString.localized('greeting',
      defaultTranslations: {'en': 'Hello', 'de': 'Hallo'})),
)
class Greeting {}
''');

    final text = widget as HWText;
    final data = text.dataType;
    expect(data, isA<HWLocalizedString>());
    final localized = data! as HWLocalizedString;
    expect(localized.key, 'greeting');
    expect(localized.isConstant, isFalse);
    expect(localized.defaultTranslations, {'en': 'Hello', 'de': 'Hallo'});
  });

  test('HWText.localized decodes to a constant localized string', () async {
    final widget = await parseCode('''
@HomeWidget(
  name: 'Greeting',
  widget: HWText.localized({'en': 'Hello', 'de': 'Hallo'}),
)
class Greeting {}
''');

    final text = widget as HWText;
    final data = text.dataType;
    expect(data, isA<HWLocalizedString>());
    final localized = data! as HWLocalizedString;
    expect(localized.isConstant, isTrue);
    expect(localized.defaultTranslations, {'en': 'Hello', 'de': 'Hallo'});
  });
}
