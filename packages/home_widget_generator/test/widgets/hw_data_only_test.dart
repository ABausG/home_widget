import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('HWDataOnly', () {
    const dataOnly = HWDataOnly([
      HWString('a'),
      HWInt('b'),
    ]);

    group('model', () {
      test('exposes data dependencies', () {
        expect(
          dataOnly.dataDependencies,
          containsAll([const HWString('a'), const HWInt('b')]),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('emits no view code', () {
        expect(dataOnly.toSwift(0, dataExpr: 'd'), isEmpty);
      });
    });

    group('Android (Glance)', () {
      test('emits no composable code', () {
        expect(dataOnly.toKotlin(0, dataExpr: 'd'), isEmpty);
      });

      test('no kotlin imports', () {
        expect(dataOnly.kotlinImports, isEmpty);
      });
    });

    group('parser integration', () {
      test('parses HWDataOnly with all supported data types', () async {
        final code = '''
@HomeWidget(
  name: 'TestData',
  widget: HWDataOnly([
    HWString('stringKey'),
    HWInt('intKey'),
    HWDouble('doubleKey'),
    HWBool('boolKey'),
  ]),
)
class TestData {}
''';

        final file = File(
          p.join(
            Directory.current.path,
            'test',
            '.tmp_data_only_test_${DateTime.now().millisecondsSinceEpoch}.dart',
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
          expect(widget, isA<HWDataOnly>());
          final parsed = widget as HWDataOnly;
          expect(parsed.data.length, 4);
          expect(parsed.data[0], isA<HWString>());
          expect((parsed.data[0] as HWString).key, 'stringKey');
          expect(parsed.data[1], isA<HWInt>());
          expect((parsed.data[1] as HWInt).key, 'intKey');
          expect(parsed.data[2], isA<HWDouble>());
          expect((parsed.data[2] as HWDouble).key, 'doubleKey');
          expect(parsed.data[3], isA<HWBool>());
          expect((parsed.data[3] as HWBool).key, 'boolKey');
        } finally {
          if (await file.exists()) await file.delete();
        }
      });
    });
  });
}
