import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
import 'package:home_widget_generator/src/generator_error.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('HWAdaptive', () {
    const simpleAdaptive = HWAdaptive(
      ios: HWText.fixed('ios only'),
      android: HWText.fixed('android only'),
    );

    group('model', () {
      test('dataDependencies union of ios and android', () {
        const adaptive = HWAdaptive(
          ios: HWText(HWString('iosK')),
          android: HWText(HWString('androidK')),
        );
        expect(
          adaptive.dataDependencies.map((d) => d.key).toSet(),
          {'iosK', 'androidK'},
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('toSwift uses only ios subtree', () {
        final swift = simpleAdaptive.toSwift(0, dataExpr: 'd');
        expect(swift, contains('Text("ios only")'));
        expect(swift, isNot(contains('android only')));
      });

      test('toSwift includes styling from ios when present', () {
        const withStyle = HWAdaptive(
          ios: HWText.fixed('a', style: HWRoleTextStyle.headline()),
          android: HWText.fixed('b'),
        );
        expect(
          withStyle.toSwift(0, dataExpr: 'd'),
          contains('.font(.headline)'),
        );
        expect(
          const HWAdaptive(
            ios: HWText.fixed('a'),
            android: HWText.fixed('b'),
          ).toSwift(0, dataExpr: 'd'),
          isNot(contains('.font(')),
        );
      });

      test(
        'swiftViewModifiers propagate from ios when themed color needs colorScheme',
        () {
          const adaptive = HWAdaptive(
            ios: HWText.fixed(
              'x',
              style: HWTextStyle(
                color: HWThemedColor(
                  light: HWFixedColor(0xFF000000),
                  dark: HWFixedColor(0xFFFFFFFF),
                ),
              ),
            ),
            android: HWText.fixed('y'),
          );
          expect(
            adaptive.swiftViewModifiers,
            contains('@Environment(\\.colorScheme) var colorScheme'),
          );
        },
      );
    });

    group('Android (Glance)', () {
      test('toKotlin uses only android subtree', () {
        final kt = simpleAdaptive.toKotlin(0, dataExpr: 'd');
        expect(kt, contains('Text(text = "android only"'));
        expect(kt, isNot(contains('ios only')));
      });

      test('kotlinImports from android child', () {
        const adaptive = HWAdaptive(
          ios: HWText.fixed('a'),
          android: HWText.fixed('b', style: HWTextStyle(italic: true)),
        );
        expect(
          adaptive.kotlinImports,
          contains('import androidx.glance.text.Text'),
        );
      });
    });

    group('parser integration', () {
      test('parses and generates correct platform code', () async {
        final code = '''
@HomeWidget(
  name: 'AdaptiveWidget',
  widget: HWAdaptive(
    ios: HWColumn(children: [HWText.fixed('iOS Text')]),
    android: HWColumn(children: [HWText.fixed('Android Text')]),
  ),
)
class AdaptiveWidget {}
''';

        final file = File(
          p.join(
            Directory.current.path,
            'test',
            '.tmp_adaptive_test_${DateTime.now().millisecondsSinceEpoch}.dart',
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
          final result =
              await context.currentSession.getResolvedUnit(file.path);

          if (result is! ResolvedUnitResult) {
            throw StateError('Failed to resolve');
          }

          final element = result.unit.declaredFragment!.element.classes.first;
          final annotation = element.metadata.annotations.firstWhere(
            (m) => m.element?.enclosingElement?.name == 'HomeWidget',
          );

          final widget = WidgetTreeParser(annotation).parse();
          expect(widget, isA<HWAdaptive>());
          final adaptive = widget as HWAdaptive;

          expect(adaptive.ios, isA<HWColumn>());
          expect(
            ((adaptive.ios as HWColumn).children.first as HWText).fixedContent,
            'iOS Text',
          );
          expect(adaptive.android, isA<HWColumn>());
          expect(
            ((adaptive.android as HWColumn).children.first as HWText)
                .fixedContent,
            'Android Text',
          );

          final swiftCode = adaptive.toSwift(0, dataExpr: 'data');
          expect(swiftCode, contains('VStack'));
          expect(swiftCode, contains('Text("iOS Text")'));
          expect(swiftCode, isNot(contains('Android Text')));

          final kotlinCode = adaptive.toKotlin(0, dataExpr: 'data');
          expect(kotlinCode, contains('Column'));
          expect(kotlinCode, contains('Text(text = "Android Text"'));
          expect(kotlinCode, isNot(contains('iOS Text')));
        } finally {
          if (await file.exists()) await file.delete();
        }
      });

      test('collects data dependencies from both platforms', () async {
        final code = '''
@HomeWidget(
  name: 'AdaptiveDataWidget',
  widget: HWAdaptive(
    ios: HWColumn(children: [HWText(HWString('iosData'))]),
    android: HWColumn(children: [HWText(HWString('androidData'))]),
  ),
)
class AdaptiveDataWidget {}
''';

        final file = File(
          p.join(
            Directory.current.path,
            'test',
            '.tmp_adaptive_data_test_${DateTime.now().millisecondsSinceEpoch}.dart',
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
          final result =
              await context.currentSession.getResolvedUnit(file.path);

          if (result is! ResolvedUnitResult) {
            throw StateError('Failed to resolve');
          }

          final element = result.unit.declaredFragment!.element.classes.first;
          final annotation = element.metadata.annotations.firstWhere(
            (m) => m.element?.enclosingElement?.name == 'HomeWidget',
          );

          final widget = WidgetTreeParser(annotation).parse();
          expect(widget, isA<HWAdaptive>());
          final adaptive = widget as HWAdaptive;

          final dependencies = adaptive.dataDependencies;
          expect(dependencies.length, 2);
          expect(dependencies.any((d) => d.key == 'iosData'), isTrue);
          expect(dependencies.any((d) => d.key == 'androidData'), isTrue);
        } finally {
          if (await file.exists()) await file.delete();
        }
      });

      test('requires both parameters', () async {
        final code = '''
@HomeWidget(
  name: 'InvalidAdaptiveWidget',
  widget: HWAdaptive(
    ios: HWColumn(children: []),
  ),
)
class InvalidAdaptiveWidget {}
''';

        final file = File(
          p.join(
            Directory.current.path,
            'test',
            '.tmp_invalid_adaptive_test_${DateTime.now().millisecondsSinceEpoch}.dart',
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
          final result =
              await context.currentSession.getResolvedUnit(file.path);

          if (result is! ResolvedUnitResult) {
            throw StateError('Failed to resolve');
          }

          final element = result.unit.declaredFragment!.element.classes.first;
          final annotation = element.metadata.annotations.firstWhere(
            (m) => m.element?.enclosingElement?.name == 'HomeWidget',
          );

          expect(
            () => WidgetTreeParser(annotation).parse(),
            throwsA(isA<GeneratorError>()),
          );
        } finally {
          if (await file.exists()) await file.delete();
        }
      });
    });
  });
}
