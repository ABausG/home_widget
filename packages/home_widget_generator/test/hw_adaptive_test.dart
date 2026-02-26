import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Parses HWAdaptive and generates correct platform code', () async {
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

    final file = File(p.join(Directory.current.path, 'test',
        '.tmp_adaptive_test_${DateTime.now().millisecondsSinceEpoch}.dart'));
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

      final widget = WidgetTreeParser(annotation).parse();
      expect(widget, isA<HWAdaptive>());
      final adaptive = widget as HWAdaptive;

      expect(adaptive.ios, isA<HWColumn>());
      expect((adaptive.ios as HWColumn).children.first, isA<HWText>());
      expect(((adaptive.ios as HWColumn).children.first as HWText).fixedContent,
          'iOS Text');

      expect(adaptive.android, isA<HWColumn>());
      expect((adaptive.android as HWColumn).children.first, isA<HWText>());
      expect(
          ((adaptive.android as HWColumn).children.first as HWText)
              .fixedContent,
          'Android Text');

      // Test Swift generation (should use iOS child)
      final swiftCode = adaptive.toSwift(0, dataExpr: 'data');
      expect(swiftCode, contains('VStack'));
      expect(swiftCode, contains('Text("iOS Text")'));
      expect(swiftCode, isNot(contains('Android Text')));

      // Test Kotlin generation (should use Android child)
      final kotlinCode = adaptive.toKotlin(0, dataExpr: 'data');
      expect(kotlinCode, contains('Column'));
      expect(kotlinCode, contains('Text(text = "Android Text"'));
      expect(kotlinCode, isNot(contains('iOS Text')));
    } finally {
      if (await file.exists()) await file.delete();
    }
  });

  test('HWAdaptive collects data dependencies from both platforms', () async {
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

    final file = File(p.join(Directory.current.path, 'test',
        '.tmp_adaptive_data_test_${DateTime.now().millisecondsSinceEpoch}.dart'));
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

  test('HWAdaptive requires both parameters', () async {
    final code = '''
@HomeWidget(
  name: 'InvalidAdaptiveWidget',
  widget: HWAdaptive(
    ios: HWColumn(children: []),
    // android is missing
  ),
)
class InvalidAdaptiveWidget {}
''';

    final file = File(p.join(Directory.current.path, 'test',
        '.tmp_invalid_adaptive_test_${DateTime.now().millisecondsSinceEpoch}.dart'));
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

      expect(() => WidgetTreeParser(annotation).parse(),
          throwsA(isA<GeneratorError>()));
    } finally {
      if (await file.exists()) await file.delete();
    }
  });
}
