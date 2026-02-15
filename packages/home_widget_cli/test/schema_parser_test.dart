import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
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
      expect(spec!.data.name, 'Test');
      expect(spec.className, 'TestWidget');
      expect(spec.data.android, isNull);
      expect(spec.data.iOS, isNull);
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
      expect(spec!.data.name, 'Full Test');
      expect(spec.className, 'FullWidget');
      expect(spec.data.dartOutput, 'lib/full_test.dart');
      expect(spec.data.android?.packageName, 'com.full');
      expect(spec.data.iOS?.groupId, 'group.full');
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
      expect(spec!.data.name, 'Basic Creation');
      expect(spec.className, 'BasicCreation');
      expect(spec.data.android, isNotNull);
      expect(spec.data.iOS, isNotNull);
    });
    test('parses data map', () async {
      const source = '''
        @HomeWidget(
          name: 'Data Widget',
          data: {
            'str': HWString(),
            'int': HWInt(),
            'dbl': HWDouble(),
            'bln': HWBool(),
          },
        )
        class DataWidget {}
      ''';

      final spec = await parseSchemaSource(source);
      expect(spec, isNotNull);
      expect(spec!.dataFields, hasLength(4));

      final strField = spec.dataFields.firstWhere((f) => f.key == 'str');
      expect(strField.type, HWDataFieldType.string);

      final intField = spec.dataFields.firstWhere((f) => f.key == 'int');
      expect(intField.type, HWDataFieldType.int_);

      final dblField = spec.dataFields.firstWhere((f) => f.key == 'dbl');
      expect(dblField.type, HWDataFieldType.double_);

      final blnField = spec.dataFields.firstWhere((f) => f.key == 'bln');
      expect(blnField.type, HWDataFieldType.bool_);
    });
    test('parses v2 fields (description, sizing, families)', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'V2Widget',
          description: 'A v2 widget',
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.id',
            supportedFamilies: [
              HWWidgetFamily.systemSmall,
              HWWidgetFamily.systemMedium,
            ],
          ),
          android: HomeWidgetAndroidConfiguration(
            packageName: 'com.example',
            minWidth: 100,
            minHeight: 50,
            minResizeWidth: 80,
            minResizeHeight: 40,
            maxResizeWidth: 200,
            maxResizeHeight: 100,
            targetCellWidth: 2,
            targetCellHeight: 1,
            resizeMode: HWAndroidResizeMode.horizontal,
            widgetCategory: HWAndroidWidgetCategory.keyguard,
            updatePeriodMillis: 3600000,
          ),
        )
        class V2Widget extends StatelessWidget {}
      ''';

      final spec = await parseSchemaSource(source);
      expect(spec, isNotNull);
      expect(spec!.data.name, 'V2Widget');
      expect(spec.data.description, 'A v2 widget');

      // Android
      final android = spec.data.android!;
      expect(android.packageName, 'com.example');
      expect(android.minWidth, 100);
      expect(android.minHeight, 50);
      expect(android.minResizeWidth, 80);
      expect(android.minResizeHeight, 40);
      expect(android.maxResizeWidth, 200);
      expect(android.maxResizeHeight, 100);
      expect(android.targetCellWidth, 2);
      expect(android.targetCellHeight, 1);
      expect(android.resizeMode, HWAndroidResizeMode.horizontal);
      expect(android.widgetCategory, HWAndroidWidgetCategory.keyguard);
      expect(android.updatePeriodMillis, 3600000);

      // iOS
      final ios = spec.data.iOS!;
      expect(ios.groupId, 'group.id');
      expect(ios.supportedFamilies, hasLength(2));
      expect(ios.supportedFamilies, contains(HWWidgetFamily.systemSmall));
      expect(ios.supportedFamilies, contains(HWWidgetFamily.systemMedium));
    });
  });
}
