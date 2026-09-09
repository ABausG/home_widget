import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/test_flutter_project.dart';

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

    test('parses applyContentPadding flag correctly', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';
        
        @HomeWidget(
          name: 'Padding Test',
          android: const HomeWidgetAndroidConfiguration(applyContentPadding: false),
          iOS: const HomeWidgetIOSConfiguration(groupId: 'group.padding', applyContentPadding: false),
        )
        class PaddingWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.android?.applyContentPadding, false);
      expect(spec.data.iOS?.applyContentPadding, false);
    });

    test('parses fillWidgetContent flag correctly', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';
        
        @HomeWidget(
          name: 'Fill Content Test',
          android: const HomeWidgetAndroidConfiguration(fillWidgetContent: false),
        )
        class FillContentWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.android?.fillWidgetContent, false);
    });

    test('parses openAppOnTap flag correctly', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Open App Test',
          android: const HomeWidgetAndroidConfiguration(openAppOnTap: false),
        )
        class OpenAppWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.android?.openAppOnTap, false);
    });

    test('defaults openAppOnTap to true', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Open App Default',
          android: const HomeWidgetAndroidConfiguration(),
        )
        class OpenAppDefaultWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.android?.openAppOnTap, true);
    });

    test('parses the top-level widgetUrl', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Url Test',
          widgetUrl: 'myapp://widget',
          android: const HomeWidgetAndroidConfiguration(),
          iOS: const HomeWidgetIOSConfiguration(groupId: 'group.url'),
        )
        class UrlWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.widgetUrl, 'myapp://widget');
      expect(spec.effectiveAndroidWidgetUrl, 'myapp://widget');
      expect(spec.effectiveIosWidgetUrl, 'myapp://widget');
    });

    test('parses the per-platform widgetUrl overrides', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Url Override Test',
          widgetUrl: 'myapp://shared',
          android: const HomeWidgetAndroidConfiguration(
            widgetUrl: 'myapp://android',
          ),
          iOS: const HomeWidgetIOSConfiguration(
            groupId: 'group.url',
            widgetUrl: 'myapp://ios',
          ),
        )
        class UrlOverrideWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.data.widgetUrl, 'myapp://shared');
      expect(spec.data.android?.widgetUrl, 'myapp://android');
      expect(spec.data.iOS?.widgetUrl, 'myapp://ios');
      expect(spec.effectiveAndroidWidgetUrl, 'myapp://android');
      expect(spec.effectiveIosWidgetUrl, 'myapp://ios');
    });

    test('collects data fields from widget tree (HWText HWString)', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Tree Data',
          widget: HWText(HWString('label')),
        )
        class TreeWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.dataFields.length, 1);
      expect(spec.dataFields.first.key, 'label');
    });

    test('collects timed data fields from widget tree', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Timed Data',
          widget: HWColumn(
            children: [
              HWText(HWTimedData(HWString('label'))),
              HWText(HWString('title')),
            ],
          ),
        )
        class TimedWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(
        spec!.timedDataFields,
        const [HWTimedData(HWString('label'))],
      );
      expect(spec.timedDataFields.single.key, 'label');
      expect(spec.primitiveDataFields, const [HWString('title')]);
    });

    test('collects image data fields from widget tree', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Image Data',
          widget: HWColumn(
            children: [
              HWImage(HWImageData('img')),
              HWImage.asset('assets/logo.png'),
            ],
          ),
        )
        class ImageDataWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.dataFields.length, 2);
      expect(spec.dataFields.every((f) => f is HWImageData), isTrue);
      expect(
        spec.dataFields.map((f) => f.key).toSet(),
        {'img', 'assetsLogoPng'},
      );
      expect(spec.runtimeImageFields.map((f) => f.key).toList(), ['img']);
      expect(
        spec.assetImageFields.map((f) => f.assetPath).toList(),
        ['assets/logo.png'],
      );
      // Only the runtime image stays in the native read loop.
      expect(spec.primitiveDataFields.length, 1);
    });

    test('collects a timed image as a time-based field', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Timed Image',
          widget: HWImage(HWTimedData(HWImageData('slide'))),
        )
        class TimedImageWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(
        spec!.timedDataFields,
        const [HWTimedData(HWImageData('slide'))],
      );
      expect(spec.timedImageFields, const [HWImageData('slide')]);
      // A timed field never becomes a `saveData` parameter of its own.
      expect(spec.primitiveDataFields, isEmpty);
    });

    test('collects an image leaf of a JSON group', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Json Image',
          widget: HWImage(HWJson('contact', HWImageData('avatar'))),
        )
        class JsonImageWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(
        spec!.jsonDataGroups.single.children.single.type,
        const HWImageData('avatar'),
      );
      expect(spec.jsonImageFields.single.storageKey, 'contact.avatar');
      // The image is part of the group, not a data field of its own.
      expect(spec.primitiveDataFields, isEmpty);
      expect(spec.imageDataFields, isEmpty);
    });

    test('keeps the locale context of a timed localized field', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Timed Localized',
          localization: HomeWidgetLocalization(
            defaultLocale: 'de',
            supportedLocales: ['en', 'de'],
          ),
          widget: HWColumn(
            children: [
              HWText(
                HWTimedData(
                  HWString.localized(
                    'greeting',
                    defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
                  ),
                ),
              ),
              HWText(
                HWTimedData(
                  HWJson(
                    'weather',
                    HWString.localized(
                      'summary',
                      defaultTranslations: {'en': 'Sunny', 'de': 'Sonnig'},
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        class TimedLocalizedWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);

      final root = spec!.timedLocalizedStrings.single;
      expect(root.key, 'greeting');
      expect(root.defaultTranslations, {'en': 'Hello', 'de': 'Hallo'});
      // The widget's default locale and resource namespace are stamped on by
      // the parser; without them the fallback would land on whichever entry
      // happens to come first.
      expect(root.baseLocaleTag, 'de');
      expect(root.baseValue, 'Hallo');
      expect(
        root.resourceName,
        startsWith('home_widget_timed_localized_widget_t_'),
      );

      final leaf = spec.timedJsonLocalizedStrings.single;
      expect(leaf.defaultTranslations, {'en': 'Sunny', 'de': 'Sonnig'});
      expect(leaf.baseLocaleTag, 'de');
      expect(leaf.baseValue, 'Sonnig');
    });

    test('parses the format of an HWText.number', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Steps',
          widget: HWText.number(
            HWInt('steps'),
            format: HWNumberFormat.decimal(
              maximumFractionDigits: 0,
              useGrouping: false,
            ),
          ),
        )
        class StepsWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.dataFields, const [HWInt('steps')]);

      final text = spec.widgetTree! as HWText;
      expect(
        text.numberFormat,
        const HWNumberFormat.decimal(
          maximumFractionDigits: 0,
          useGrouping: false,
        ),
      );
      expect(text.dateFormat, isNull);
    });

    test('collects the field a data-bound currency reads', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Cart',
          widget: HWText.number(
            HWDouble('total'),
            format: HWNumberFormat.currency(
              currency: HWCurrency.data(HWJson('cart', HWString('currency'))),
              decimalDigits: 2,
            ),
          ),
        )
        class CartWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);

      // The code is only ever named inside the format, so the parser has to
      // pick it up from there or the data class would never carry it.
      expect(spec!.primitiveDataFields, const [HWDouble('total')]);
      expect(
        spec.jsonDataGroups.single.children.single.type,
        const HWString('currency'),
      );

      final text = spec.widgetTree! as HWText;
      expect(
        text.numberFormat,
        const HWNumberFormat.currency(
          currency: HWCurrency.data(HWJson('cart', HWString('currency'))),
          decimalDigits: 2,
        ),
      );
    });

    test('collects a date and the field its time zone reads', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Agenda',
          widget: HWText.dateTime(
            HWDateTime('startsAt'),
            format: HWDateFormat.yMMMd,
            timeZone: HWTimeZone.data(HWString('zone')),
          ),
        )
        class AgendaWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(
        spec!.primitiveDataFields,
        unorderedEquals(const [HWDateTime('startsAt'), HWString('zone')]),
      );

      final text = spec.widgetTree! as HWText;
      expect(text.dateFormat, HWDateFormat.yMMMd);
      expect(text.timeZone, const HWTimeZone.data(HWString('zone')));
    });

    test('parses supportedFamilies on iOS configuration', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Families',
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.f',
            supportedFamilies: [
              HWWidgetFamily.systemSmall,
              HWWidgetFamily.systemMedium,
            ],
          ),
        )
        class FamWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(
        spec!.data.iOS?.supportedFamilies,
        [HWWidgetFamily.systemSmall, HWWidgetFamily.systemMedium],
      );
    });

    test('parses Android resizeMode and widgetCategory enums', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Android Enums',
          android: const HomeWidgetAndroidConfiguration(
            resizeMode: HWAndroidResizeMode.horizontalAndVertical,
            widgetCategory: HWAndroidWidgetCategory.searchbox,
          ),
        )
        class AndroidEnumWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(
        spec!.data.android?.resizeMode,
        HWAndroidResizeMode.horizontalAndVertical,
      );
      expect(
        spec.data.android?.widgetCategory,
        HWAndroidWidgetCategory.searchbox,
      );
    });

    test('a widget without flavors parses none', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(name: 'No Flavors')
        class NoFlavorWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec!.data.flavors, isNull);
      expect(spec.declaredFlavors, isEmpty);
    });

    test('parses a flavors map with nested iOS overrides', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Flavored',
          android: HomeWidgetAndroidConfiguration(),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.base'),
          flavors: {
            'dev': HomeWidgetFlavor(
              iOS: HomeWidgetIOSFlavor(groupId: 'group.dev'),
            ),
            'stg': HomeWidgetFlavor(),
          },
        )
        class FlavoredWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      expect(spec!.declaredFlavors, ['dev', 'stg']);
      expect(spec.flavor('dev')?.iOS?.groupId, 'group.dev');
      expect(spec.iosGroupIdFor('dev'), 'group.dev');

      // An empty entry declares the flavor and keeps every base value.
      expect(spec.flavor('stg'), const HomeWidgetFlavor());
      expect(spec.iosGroupIdFor('stg'), 'group.base');
    });

    test('parses a flavor that overrides nothing', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Half Flavored',
          android: HomeWidgetAndroidConfiguration(),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.base'),
          flavors: {'dev': HomeWidgetFlavor()},
        )
        class HalfFlavoredWidget {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec!.flavor('dev')?.iOS, isNull);
      expect(spec.iosGroupIdFor('dev'), 'group.base');
    });
  });
}
