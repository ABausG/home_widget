import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/test_flutter_project.dart';
import 'scenarios/android_scenarios.dart';
import 'scenarios/shared_scenarios.dart';

/// Parses the schema of every build scenario, so one that no longer compiles
/// fails here rather than only in the slow integration builds.
void main() {
  late TestFlutterProject project;

  setUpAll(() async {
    project = await TestFlutterProject.create();
  });

  for (final scenario in [...androidBuildScenarios, ...sharedBuildScenarios]) {
    test('the schema of "${scenario.description}" parses', () async {
      final file = File(
        p.join(project.root.path, 'lib', '${scenario.className}.dart'),
      )..writeAsStringSync(scenario.widgetSource);
      addTearDown(file.deleteSync);
      final collection = AnalysisContextCollection(
        includedPaths: [file.path],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );

      final specs = await parseSchemaFile(file.path, collection: collection);

      expect(specs.map((spec) => spec.className), [scenario.className]);
    });
  }
}
