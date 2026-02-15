import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseSchemaSource', () {
    test('parses minimal widget spec', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';
        
        @HomeWidget(name: 'Test')
        class TestWidget {}
      ''';

      final spec = await parseSchemaSource(source);
      expect(spec, isNotNull);
      expect(spec!.name, 'Test');
      expect(spec.className, 'TestWidget');
      expect(spec.android, isNull);
      expect(spec.ios, isNull);
      expect(spec.data.name, 'Test');
    });

    test('parses full widget spec', () async {
      const source = '''
        @HomeWidget(
          name: 'Full Test',
          dartOutput: 'lib/full_test.dart',
          android: const HomeWidgetAndroidConfiguration(packageName: 'com.full'),
          iOS: const HomeWidgetIOSConfiguration(groupId: 'group.full'),
        )
        class FullWidget {}
      ''';

      final spec = await parseSchemaSource(source);
      expect(spec, isNotNull);
      expect(spec!.name, 'Full Test');
      expect(spec.className, 'FullWidget');
      expect(spec.dartOutput, 'lib/full_test.dart');
      expect(spec.android?.packageName, 'com.full');
      expect(spec.ios?.groupId, 'group.full');
    });

    test('returns null if no @HomeWidget annotation', () async {
      const source = '''
        class NormalClass {}
      ''';

      final spec = await parseSchemaSource(source);
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

      final spec = await parseSchemaSource(source);
      expect(spec, isNotNull);
      expect(spec!.name, 'Basic Creation');
      expect(spec.className, 'BasicCreation');
      expect(spec.android, isNotNull);
      expect(spec.ios, isNotNull);
    });
  });
}
