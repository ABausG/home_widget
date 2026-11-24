import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The errors the analyzer reports for [source], a library in `test/`.
Future<List<String>> _errorsOf(String source) async {
  final file = File(
    p.join(
      Directory.current.path,
      'test',
      'temp_public_api_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  )..writeAsStringSync(source);
  addTearDown(file.deleteSync);
  final collection = AnalysisContextCollection(
    includedPaths: [file.path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  addTearDown(collection.dispose);
  final result = await collection
      .contextFor(file.path)
      .currentSession
      .getResolvedUnit(file.path) as ResolvedUnitResult;
  return [
    for (final diagnostic in result.diagnostics)
      if (diagnostic.severity == Severity.error) diagnostic.message,
  ];
}

void main() {
  test('the schema API names a payload but not how it is generated', () async {
    final errors = await _errorsOf('''
import 'package:home_widget_generator/home_widget_generator.dart';

const link = HWLink(
  'forecast',
  url: 'myapp://forecast',
  data: [HWPayload('days', HWInt.fixed(7))],
  child: HWText(HWString.fixed('Forecast')),
);

const button = HWButton('add', child: HWText(HWString.fixed('+')));

Object? url = link.payloadUrl;
Object? tap = button.payloadUrl;
HWPayloadUrl? payloadUrl;
HWPayloadEntry? entry;
HWPayloadType? type;
''');

    expect(
      errors,
      unorderedEquals([
        allOf(contains("'payloadUrl'"), contains("'HWLink'")),
        allOf(contains("'payloadUrl'"), contains("'HWButton'")),
        contains("'HWPayloadUrl'"),
        contains("'HWPayloadEntry'"),
        contains("'HWPayloadType'"),
      ]),
    );
  });

  test('the CLI API carries the payload of a link', () async {
    final errors = await _errorsOf('''
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';

const link = HWLink(
  'forecast',
  url: 'myapp://forecast',
  child: HWText(HWString.fixed('Forecast')),
);

const button = HWButton('add', child: HWText(HWString.fixed('+')));

HWPayloadUrl url = link.payloadUrl;
HWPayloadUrl tap = button.payloadUrl;
HWPayloadEntry? entry;
HWPayloadType? type;
''');

    expect(errors, isEmpty);
  });
}
