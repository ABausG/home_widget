import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_value_decoder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Every constant this file decodes, in one source file.
const _schemas = '''
import 'package:home_widget_generator/home_widget_generator.dart';

const payload = [
  HWString('city'),
  HWPayload('days', HWInt.fixed(7)),
  HWPayload('user', HWJson('profile', HWString('id'))),
  HWPayload('todo', HWItemData(HWString('uuid'))),
  HWTimedData(HWBool('done')),
];
const nestedPayload = [HWPayload('a', HWPayload('b', HWString('city')))];
const wrappedPayload = [HWTimedData(HWPayload('b', HWString('city')))];
const unreadable = [HWJson('group', HWTimedData(HWString('city')))];
const unknown = [HWJson('group', HWJson('inner', HWPayload('b', HWInt('n'))))];
const renderedPayload = HWPayload('days', HWInt.fixed(7));
const notData = [HWString('city'), 'city'];

@HomeWidget(
  name: 'Linked',
  widget: HWColumn(
    children: [
      HWLink(
        'forecast',
        url: 'myapp://forecast',
        data: [HWString('city'), HWPayload('days', HWInt.fixed(7))],
        child: HWText(HWString.fixed('Forecast')),
      ),
      HWLink(
        'history',
        url: 'myapp://history',
        child: HWText(HWString('label')),
      ),
    ],
  ),
)
class Linked {}

@HomeWidget(
  name: 'RenderedPayload',
  widget: HWText(HWPayload('days', HWString('city'))),
)
class RenderedPayload {}

@HomeWidget(
  name: 'ListLinks',
  widget: HWColumn.builder(
    'todos',
    item: HWLink(
      'open',
      url: 'myapp://todo',
      data: [HWItemData(HWString('id'))],
      child: HWText(HWItemData(HWString('title'))),
    ),
  ),
)
class ListLinks {}
''';

void main() {
  late Map<String, DartObject> constants;
  late Map<String, ElementAnnotation> annotations;
  late File file;

  setUpAll(() async {
    file = File(
      p.join(
        Directory.current.path,
        'test',
        'temp_link_${DateTime.now().microsecondsSinceEpoch}.dart',
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
    constants = {
      for (final variable in library.topLevelVariables)
        variable.name!: variable.computeConstantValue()!,
    };
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

  List<HWDataType<dynamic>> payloadOf(String name) =>
      WidgetValueDecoder.decodePayload(constants[name], owner: 'HWLink("x")');

  HWWidget widgetOf(String name) => WidgetValueDecoder(
        annotations[name]!.computeConstantValue()!.getField('widget'),
      ).decode();

  Matcher throwsGeneratorError(Matcher message) => throwsA(
        isA<GeneratorError>().having((e) => e.message, 'message', message),
      );

  group('decodePayload', () {
    test('decodes stored values and named entries in order', () {
      expect(payloadOf('payload'), const [
        HWString('city'),
        HWPayload('days', HWInt.fixed(7)),
        HWPayload('user', HWJson('profile', HWString('id'))),
        HWPayload('todo', HWItemData(HWString('uuid'))),
        HWTimedData(HWBool('done')),
      ]);
    });

    test('is empty without a list', () {
      expect(
        WidgetValueDecoder.decodePayload(null, owner: 'widgetUrlData'),
        isEmpty,
      );
    });

    test('rejects an HWPayload inside another HWPayload', () {
      expect(
        () => payloadOf('nestedPayload'),
        throwsGeneratorError(
          allOf(
            contains('HWPayload("b", ...)'),
            contains('only names an entry of a data list'),
          ),
        ),
      );
    });

    test('rejects an HWPayload inside another wrapper', () {
      expect(
        () => payloadOf('wrappedPayload'),
        throwsGeneratorError(contains('put HWItemData, HWTimedData or HWJson')),
      );
      expect(
        () => payloadOf('unknown'),
        throwsGeneratorError(contains('HWPayload("b", ...)')),
      );
    });

    test('passes on the error of an entry that cannot be decoded', () {
      expect(
        () => payloadOf('unreadable'),
        throwsGeneratorError(contains('HWTimedData must be a root-level')),
      );
    });

    test('names the entry that is no data type', () {
      expect(
        () => payloadOf('notData'),
        throwsGeneratorError(
          contains(
            'Entry 1 of the data of HWLink("x") could not be read as a data '
            'type: String.',
          ),
        ),
      );
    });
  });

  group('HWPayload outside a payload', () {
    test('is rejected as a data type of its own', () {
      expect(
        () => WidgetValueDecoder.decodeDataType(constants['renderedPayload']),
        throwsGeneratorError(contains('It cannot be rendered')),
      );
    });

    test('is rejected where a widget renders it', () {
      expect(
        () => widgetOf('RenderedPayload'),
        throwsGeneratorError(contains('HWPayload("days", ...)')),
      );
    });
  });

  group('HWLink', () {
    test('decodes id, url, data and child', () {
      final column = widgetOf('Linked') as HWColumn;
      final forecast = column.children.first as HWLink;
      final history = column.children.last as HWLink;

      expect(forecast.id, 'forecast');
      expect(forecast.url, 'myapp://forecast');
      expect(forecast.data, const [
        HWString('city'),
        HWPayload('days', HWInt.fixed(7)),
      ]);
      expect(forecast.child, isA<HWText>());

      expect(history.id, 'history');
      expect(history.data, isEmpty);
      expect(
        column.dataDependencies,
        {const HWString('city'), const HWString('label')},
      );
    });

    test('decodes inside the item of a builder', () {
      final builder = widgetOf('ListLinks') as HWColumn;
      final link = builder.item as HWLink;

      expect(link.data, const [HWItemData(HWString('id'))]);
      expect(
        builder.itemReads.map((read) => read.key),
        containsAll(['id', 'title']),
      );
    });
  });
}
