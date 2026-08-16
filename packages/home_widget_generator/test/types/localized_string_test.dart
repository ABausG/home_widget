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
      Map<String, String> defaultValues = values,
    }) =>
        HWLocalizedString.resolved(
          key,
          defaultValues: defaultValues,
          isConstant: isConstant,
          defaultLocale: defaultLocale,
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
        isNot(equals(localized(defaultValues: const {'en': 'Hi'}))),
      );
    });

    test('baseValue follows the stamped default locale', () {
      expect(localized().baseValue, 'Hello');
      expect(localized(defaultLocale: 'de').baseValue, 'Hallo');
    });

    test('falls back to the first entry when no default locale is stamped', () {
      expect(localized(defaultLocale: null).baseLocaleTag, 'en');
    });

    test('constant form inlines the resolver into the access expression', () {
      final constant = localized(key: '', isConstant: true);
      expect(
        constant.kotlinAccess('widgetData'),
        'hwLocalize(hwLocale, mapOf("en" to "Hello", "de" to "Hallo", '
        '"pt-BR" to "Ola"), "en")',
      );
      expect(
        constant.swiftAccess('entry.data'),
        'hwLocalize(["en": "Hello", "de": "Hallo", "pt-BR": "Ola"], '
        'baseLocale: "en")',
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
      expect(
        keyed.androidReadValue(store: 'prefs', key: 'p.greeting'),
        startsWith('hwReadLocalized(prefs, "p.greeting", locale, mapOf('),
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

    test('escapes characters that would break the generated literal', () {
      final tricky = localized(
        defaultValues: const {'en': 'a"b\\c\nd\$e'},
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
      defaultValues: {'en': 'Hello', 'de': 'Hallo'})),
)
class Greeting {}
''');

    final text = widget as HWText;
    final data = text.dataType;
    expect(data, isA<HWLocalizedString>());
    final localized = data! as HWLocalizedString;
    expect(localized.key, 'greeting');
    expect(localized.isConstant, isFalse);
    expect(localized.defaultValues, {'en': 'Hello', 'de': 'Hallo'});
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
    expect(localized.defaultValues, {'en': 'Hello', 'de': 'Hallo'});
  });
}
