import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('WidgetTreeParser', () {
    setUp(() async {
      // Setup
    });

    tearDown(() {
      // Teardown
    });

    // Helper to resolve code
    Future<HWWidget> parseCode(String code) async {
      // We need to write a pubspec or something?
      // Actually, simplest is to write file to `test/src/parser/temp.dart` (inside project)
      // so it picks up the project's package config!
      // But we need to be careful with concurrency.

      final file = File(p.join(Directory.current.path, 'test',
          'temp_${DateTime.now().millisecondsSinceEpoch}.dart'));
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
        final annotation = element.metadata2.annotations.firstWhere(
            (m) => m.element2?.enclosingElement2?.name3 == 'HomeWidget');

        return WidgetTreeParser(annotation).parse();
      } finally {
        if (await file.exists()) await file.delete();
      }
    }

    test('parses HWColumn with children', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText.fixed('Hello'),
      HWText.fixed('World'),
    ],
    mainAxisAlignment: HWMainAxisAlignment.center,
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWColumn>());
      final column = widget as HWColumn;
      expect(column.children.length, 2);
      expect(column.children[0], isA<HWText>());
      expect((column.children[0] as HWText).toSwift(0, dataExpr: ''),
          contains('Hello'));
      expect(column.mainAxisAlignment, HWMainAxisAlignment.center);
    });

    test('parses HWText with data', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText(HWString('title')),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWText>());
      final text = widget as HWText;
      // dataType is not directly exposed as public field in HWText?
      // We can check generated code.
      expect(text.toSwift(0, dataExpr: 'data'), contains('data.title'));
    });
  });
}
