import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_value_decoder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Every constant this file decodes, in one source file.
const _schemas = '''
import 'package:home_widget_generator/home_widget_generator.dart';

void onCounter(Object interaction) {}

@HomeWidget(
  name: 'Counter',
  onInteraction: onCounter,
  widget: HWColumn(
    children: [
      HWButton(
        'rate',
        data: [HWString('city'), HWPayload('stars', HWInt.fixed(3))],
        child: HWText(HWString.fixed('Rate')),
      ),
      HWButton('increment', child: HWText(HWString('label'))),
    ],
  ),
)
class Counter {}

@HomeWidget(
  name: 'ListButtons',
  widget: HWColumn.builder(
    'todos',
    item: HWButton(
      'toggle',
      data: [HWItemData(HWString('id'))],
      child: HWText(HWItemData(HWString('title'))),
    ),
  ),
)
class ListButtons {}

@HomeWidget(
  name: 'NotData',
  widget: HWButton('broken', data: ['city'], child: HWText(HWString('a'))),
)
class NotData {}
''';

void main() {
  late Map<String, ElementAnnotation> annotations;
  late File file;

  setUpAll(() async {
    file = File(
      p.join(
        Directory.current.path,
        'test',
        'temp_button_${DateTime.now().microsecondsSinceEpoch}.dart',
      ),
    );
    await file.writeAsString(_schemas);

    final collection = AnalysisContextCollection(
      includedPaths: [file.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final context = collection.contextFor(file.path);
    final result = await context.currentSession.getResolvedUnit(file.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('Failed to resolve');
    }

    final library = result.unit.declaredFragment!.element;
    annotations = {
      for (final element in library.classes)
        element.name!: element.metadata.annotations.firstWhere(
          (m) => m.element?.enclosingElement?.name == 'HomeWidget',
        ),
    };
  });

  tearDownAll(() async {
    if (await file.exists()) await file.delete();
  });

  HWWidget widgetOf(String name) => WidgetValueDecoder(
        annotations[name]!.computeConstantValue()!.getField('widget'),
      ).decode();

  group('HWButton', () {
    test('decodes id, data and child', () {
      final column = widgetOf('Counter') as HWColumn;
      final rate = column.children.first as HWButton;
      final increment = column.children.last as HWButton;

      expect(rate.id, 'rate');
      expect(rate.data, const [
        HWString('city'),
        HWPayload('stars', HWInt.fixed(3)),
      ]);
      expect(rate.child, isA<HWText>());

      expect(increment.id, 'increment');
      expect(increment.data, isEmpty);
      expect(
        column.dataDependencies,
        {const HWString('city'), const HWString('label')},
      );
    });

    test('decodes inside the item of a builder', () {
      final builder = widgetOf('ListButtons') as HWColumn;
      final button = builder.item as HWButton;

      expect(button.data, const [HWItemData(HWString('id'))]);
      expect(
        builder.itemReads.map((read) => read.key),
        containsAll(['id', 'title']),
      );
    });

    test('names itself in the error of an entry that is no data type', () {
      expect(
        () => widgetOf('NotData'),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains("Entry 0 of the data of HWButton('broken')"),
          ),
        ),
      );
    });

    test('leaves the annotation readable next to onInteraction', () {
      final value = annotations['Counter']!.computeConstantValue()!;

      expect(value.getField('name')?.toStringValue(), 'Counter');
      expect(
        value.getField('onInteraction')?.toFunctionValue()?.name,
        'onCounter',
      );
    });
  });
}
