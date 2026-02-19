import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/test_flutter_project.dart';

void main() {
  group('parseSchemaFile', () {
    late TestFlutterProject project;
    late AnalysisContextCollection collection;

    setUpAll(() async {
      project = await TestFlutterProject.create();
      collection = AnalysisContextCollection(
        includedPaths: [project.root.path],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );
    });

    Future<WidgetSpec?> parseSourceInTempFile(String source) async {
      final fileName = 'widget_${source.hashCode}.dart';
      final file = File(p.join(project.root.path, 'lib', fileName));
      await file.writeAsString(source);

      final specs = await parseSchemaFile(file.path, collection: collection);
      if (specs.isEmpty) return null;
      return specs.first;
    }

    test('parses minimal widget spec', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';
        
        @HomeWidget(name: 'Test')
        class TestWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.name, 'Test');
      expect(spec.className, 'TestWidget');
      expect(spec.data.android, isNull);
      expect(spec.data.iOS, isNull);
    });

    test('parses full widget spec', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';
        
        @HomeWidget(
          name: 'Full Test',
          dartOutput: 'lib/full_test.dart',
          android: const HomeWidgetAndroidConfiguration(packageName: 'com.full'),
          iOS: const HomeWidgetIOSConfiguration(groupId: 'group.full'),
        )
        class FullWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.name, 'Full Test');
      expect(spec.className, 'FullWidget');
      expect(spec.data.dartOutput, 'lib/full_test.dart');
      expect(spec.data.android?.packageName, 'com.full');
      expect(spec.data.iOS?.groupId, 'group.full');
    });

    test('returns null (empty list) if no @HomeWidget annotation', () async {
      const source = '''
        class NormalClass {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNull);
    });

    test('parses Basic Creation scenario', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Basic Creation',
          android: HomeWidgetAndroidConfiguration(),
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.example',
          ),
        )
        class BasicCreation {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.name, 'Basic Creation');
    });

    test('parses v2 fields (description)', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'V2Widget',
          description: 'A v2 widget',
        )
        class V2Widget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.name, 'V2Widget');
      expect(spec.data.description, 'A v2 widget');
    });
  });
}
