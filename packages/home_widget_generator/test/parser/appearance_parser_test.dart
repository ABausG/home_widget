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

/// Every constant this file decodes, in one source file, so that
/// `package:flutter` is resolved once.
const _schemas = '''
import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

const storedColor = HWColor('accent', defaultValue: 0xFF6750A4, previewValue: 0xFF000000);
const fixedColor = HWColor.fixed(0xFF112233);
const roleColor = HWDefaultColor(HWColorRole.contentSecondary);
const jsonColor = HWJson('brand', HWColor('fill'));
const timedColor = HWTimedData(HWColor('phase'));
const itemColor = HWItemData(HWColor('tint'), previewValues: [0xFF000000, 1]);
const itemColorWrong = HWItemData(HWColor('tint'), previewValues: ['red']);
const notAColor = HWString('label');
const notData = HWEdgeInsets.all(4);

const appearance = HWAppearanceData(
  light: HWImageData('logoLight'),
  dark: HWImageData.asset('assets/logo.png'),
  iosAccented: HWImageData('mono'),
  iosVibrant: HWImageData('lock'),
);
const appearanceColors = HWAppearanceData(
  light: HWJson('brand', HWColor('light')),
  dark: HWTimedData(HWColor('dark')),
  iosAccented: HWItemData(HWColor('accented')),
  iosVibrant: HWColor.fixed(0xFFFFFFFF),
);
const appearanceStrings = HWAppearanceData(
  light: HWString.fixed('a'),
  dark: HWString.localizedFixed({'en': 'b'}),
);
const mixedKinds = HWAppearanceData(light: HWString('a'), dark: HWInt('b'));
const mixedFonts = HWAppearanceData(
  light: HWIconData.fixed(Icons.wb_sunny),
  dark: HWIconData.fixed(IconData(0xE000, fontFamily: 'OtherIcons')),
);
const nested = HWAppearanceData(
  light: HWAppearanceData(light: HWString('a'), dark: HWString('b')),
  dark: HWString('c'),
);
const inTimed = HWTimedData(HWAppearanceData(light: HWInt('a'), dark: HWInt('b')));
const inItem = HWItemData(HWAppearanceData(light: HWInt('a'), dark: HWInt('b')));
const inJson = HWJson('g', HWAppearanceData(light: HWInt('a'), dark: HWInt('b')));
const appearanceOfColorsAndText = HWAppearanceData(
  light: HWColor('a'),
  dark: HWString('b'),
);

@HomeWidget(
  name: 'Colors',
  android: HomeWidgetAndroidConfiguration(backgroundColor: HWColor('bg')),
  widget: HWColumn(
    children: [
      HWColoredBox(
        color: HWAppearanceData(light: HWColor('l'), dark: HWColor.fixed(0xFF000000)),
        child: HWText(HWString.fixed('box')),
      ),
      HWDecoratedBox(
        decoration: HWBoxDecoration(
          color: HWJson('brand', HWColor('fill')),
          border: HWBoxBorder(thickness: 1, color: HWTimedData(HWColor('stroke'))),
        ),
        child: HWText(
          HWString.fixed('text'),
          style: HWRoleTextStyle.title(color: HWColor('title')),
        ),
      ),
      HWIcon(HWIconData.fixed(Icons.wb_sunny), color: HWColor('tint')),
      HWImage(
        HWAppearanceData(light: HWImageData('a'), dark: HWImageData('b')),
        iosAccentedRendering: HWAccentedRendering.desaturated,
      ),
      HWIcon(
        HWAppearanceData(
          light: HWIconData('mood', icons: [Icons.wb_sunny, Icons.cloud]),
          dark: HWIconData.fixed(Icons.nightlight_round),
        ),
      ),
      HWBoolConditional(
        data: HWAppearanceData(light: HWBool('a'), dark: HWBool.fixed(true)),
        whenTrue: HWText(HWString.fixed('t')),
        whenFalse: HWText(HWString.fixed('f')),
      ),
      HWAppearanceAdaptive(
        light: HWText(HWString('light')),
        dark: HWText(HWString('dark')),
        iosVibrant: HWText(HWString('vibrant')),
      ),
    ],
  ),
)
class ColorSlots {}

@HomeWidget(
  name: 'TextColor',
  widget: HWText(HWString.fixed('x'), style: HWTextStyle(color: HWInt('nope'))),
)
class TextColor {}

@HomeWidget(
  name: 'IconColor',
  widget: HWIcon(
    HWIconData.fixed(Icons.wb_sunny),
    color: HWAppearanceData(light: HWInt('a'), dark: HWInt('b')),
  ),
)
class IconColor {}

@HomeWidget(
  name: 'SurrogateSide',
  widget: HWIcon(
    HWAppearanceData(
      light: HWIconData.fixed(Icons.wb_sunny),
      dark: HWIconData.fixed(IconData(0xD800, fontFamily: 'MaterialIcons')),
    ),
  ),
)
class SurrogateSide {}

@HomeWidget(name: 'ColorAsText', widget: HWText(HWColor('accent')))
class ColorAsText {}

@HomeWidget(
  name: 'AppearanceAsText',
  widget: HWText(HWAppearanceData(light: HWColor('a'), dark: HWColor('b'))),
)
class AppearanceAsText {}

@HomeWidget(
  name: 'AppearanceCurrency',
  widget: HWText.number(
    HWInt('n'),
    format: HWNumberFormat.currency(
      currency: HWCurrency.data(
        HWAppearanceData(light: HWString('a'), dark: HWString('b')),
      ),
    ),
  ),
)
class AppearanceCurrency {}

@HomeWidget(
  name: 'AppearanceZone',
  widget: HWText.dateTime(
    HWDateTime('at'),
    timeZone: HWTimeZone.data(
      HWAppearanceData(light: HWString('a'), dark: HWString('b')),
    ),
  ),
)
class AppearanceZone {}

@HomeWidget(
  name: 'AppearanceLink',
  widget: HWLink(
    'go',
    url: 'myapp://go',
    data: [HWAppearanceData(light: HWString('a'), dark: HWString('b'))],
    child: HWText(HWString.fixed('go')),
  ),
)
class AppearanceLink {}

@HomeWidget(
  name: 'AppearancePayload',
  widget: HWLink(
    'go',
    url: 'myapp://go',
    data: [
      HWPayload('x', HWAppearanceData(light: HWString('a'), dark: HWString('b'))),
    ],
    child: HWText(HWString.fixed('go')),
  ),
)
class AppearancePayload {}
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
        'temp_appearance_${DateTime.now().microsecondsSinceEpoch}.dart',
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

  HWDataType<dynamic>? decoded(String name) =>
      WidgetValueDecoder.decodeDataType(
        constants[name],
        defaultLocale: 'en',
        resourcePrefix: 'home_widget_test_widget',
      );

  DartObject annotationOf(String name) =>
      annotations[name]!.computeConstantValue()!;

  HWWidget widgetOf(String name) => WidgetValueDecoder(
        annotationOf(name).getField('widget'),
        defaultLocale: 'en',
        resourcePrefix: 'home_widget_test_widget',
        fontResourcePrefix: 'hw_font_test_widget',
      ).decode();

  Matcher throwsGeneratorError(Object message) => throwsA(
        isA<GeneratorError>().having((e) => e.message, 'message', message),
      );

  group('HWColor', () {
    test('decodes its stored, constant and role forms', () {
      expect(
        decoded('storedColor'),
        const HWColor(
          'accent',
          defaultValue: 0xFF6750A4,
          previewValue: 0xFF000000,
        ),
      );
      expect(decoded('fixedColor'), const HWFixedColor(0xFF112233));
      expect(
        decoded('roleColor'),
        const HWDefaultColor(HWColorRole.contentSecondary),
      );
    });

    test('decodes inside every wrapper', () {
      expect(decoded('jsonColor'), const HWJson('brand', HWColor('fill')));
      expect(decoded('timedColor'), const HWTimedData(HWColor('phase')));
      expect(
        decoded('itemColor'),
        const HWItemData(HWColor('tint'), previewValues: [0xFF000000, 1]),
      );
      expect(
        () => decoded('itemColorWrong'),
        throwsGeneratorError(contains('an ARGB int such as 0xFF6750A4')),
      );
    });

    test('a color slot takes every color value, typed as one', () {
      expect(
        WidgetValueDecoder.decodeColor(constants['jsonColor'], slot: 's'),
        isA<HWJson<int>>(),
      );
      expect(
        WidgetValueDecoder.decodeColor(constants['timedColor'], slot: 's'),
        isA<HWTimedData<int>>(),
      );
      expect(
        WidgetValueDecoder.decodeColor(constants['itemColor'], slot: 's'),
        isA<HWItemData<int>>().having(
          (item) => item.previewValues,
          'previewValues',
          [0xFF000000, 1],
        ),
      );
      final appearance = WidgetValueDecoder.decodeColor(
        constants['appearanceColors'],
        slot: 's',
      );
      expect(appearance, isA<HWAppearanceData<int>>());
      expect(
        (appearance! as HWAppearanceData<int>).sides,
        [
          isA<HWJson<int>>(),
          isA<HWTimedData<int>>(),
          isA<HWItemData<int>>(),
          const HWFixedColor(0xFFFFFFFF),
        ],
      );
      expect(WidgetValueDecoder.decodeColor(null, slot: 's'), isNull);
    });

    test('a color slot names itself and what it got', () {
      expect(
        () => WidgetValueDecoder.decodeColor(
          constants['notAColor'],
          slot: 'HWColoredBox.color',
        ),
        throwsGeneratorError(
          allOf(
            contains('HWColoredBox.color takes a color'),
            endsWith('got HWString.'),
          ),
        ),
      );
      expect(
        () => WidgetValueDecoder.decodeColor(
          constants['notData'],
          slot: 'HWIcon.color',
        ),
        throwsGeneratorError(endsWith('got HWEdgeInsets.')),
      );
      expect(
        () => widgetOf('TextColor'),
        throwsGeneratorError(
          allOf(
            contains('HWTextStyle.color takes a color'),
            endsWith('HWInt.'),
          ),
        ),
      );
      expect(
        () => widgetOf('IconColor'),
        throwsGeneratorError(
          allOf(
            contains('HWIcon.color takes a color'),
            contains('an HWAppearanceData of HWInt values'),
          ),
        ),
      );
    });

    test('is not display text', () {
      for (final name in ['ColorAsText', 'AppearanceAsText']) {
        expect(
          () => widgetOf(name),
          throwsGeneratorError(contains('cannot render a color as text')),
        );
      }
    });

    test('reaches every color slot of a tree', () {
      final tree = widgetOf('ColorSlots') as HWColumn;
      final [box, decorated, icon, image, appearanceIcon, flag, adaptive] =
          tree.children;
      expect(
        (box as HWColoredBox).color,
        const HWAppearanceData<int>(
          light: HWColor('l'),
          dark: HWFixedColor(0xFF000000),
        ),
      );
      final decoration = (decorated as HWDecoratedBox).decoration;
      expect(decoration.color, const HWJson<int>('brand', HWColor('fill')));
      expect(
        decoration.border!.color,
        const HWTimedData<int>(HWColor('stroke')),
      );
      expect(
        ((decorated.child as HWText).style!).effectiveColor,
        const HWColor('title'),
      );
      expect((icon as HWIcon).color, const HWColor('tint'));
      expect(
        (image as HWImage).iosAccentedRendering,
        HWAccentedRendering.desaturated,
      );
      expect(image.data, isA<HWAppearanceData<dynamic>>());
      expect(
        (appearanceIcon as HWIcon).ownIconCodePoints.values.single,
        hasLength(3),
      );
      expect(
        (flag as HWBoolConditional).data,
        isA<HWAppearanceData<dynamic>>(),
      );
      expect(adaptive, isA<HWAppearanceAdaptive>());
      final slots = adaptive as HWAppearanceAdaptive;
      expect(slots.iosAccented, isNull);
      expect(slots.iosVibrant, isA<HWText>());
      expect(
        tree.dataDependencies,
        containsAll([
          const HWColor('l'),
          const HWColor('title'),
          const HWColor('tint'),
          const HWString('vibrant'),
        ]),
      );

      final android = annotationOf('ColorSlots').getField('android')!;
      expect(
        WidgetValueDecoder.decodeColor(
          android.getField('backgroundColor'),
          slot: 'backgroundColor',
        ),
        const HWColor('bg'),
      );
    });
  });

  group('HWAppearanceData', () {
    test('decodes every side', () {
      expect(
        decoded('appearance'),
        const HWAppearanceData<dynamic>(
          light: HWImageData('logoLight'),
          dark: HWImageData.asset('assets/logo.png'),
          iosAccented: HWImageData('mono'),
          iosVibrant: HWImageData('lock'),
        ),
      );
      final strings = decoded('appearanceStrings')! as HWAppearanceData;
      expect(strings.light, const HWString.fixed('a'));
      expect(strings.dark, isA<HWLocalizedString>());
      expect(strings.iosAccented, isNull);
    });

    test('rejects sides of different kinds', () {
      expect(
        () => decoded('mixedKinds'),
        throwsGeneratorError(contains('(HWString, HWInt)')),
      );
      expect(
        () => decoded('appearanceOfColorsAndText'),
        throwsGeneratorError(contains('(HWColor, HWString)')),
      );
    });

    test('validates the glyph of a constant icon side', () {
      expect(
        () => widgetOf('SurrogateSide'),
        throwsGeneratorError(contains('surrogate')),
      );
    });

    test('rejects icons out of more than one font', () {
      expect(
        () => decoded('mixedFonts'),
        throwsGeneratorError(contains('come from more than one font')),
      );
    });

    test('is always the outermost wrapper', () {
      expect(
        () => decoded('nested'),
        throwsGeneratorError(contains('cannot be the light side of another')),
      );
      for (final (name, wrapper) in [
        ('inTimed', 'HWTimedData'),
        ('inItem', 'HWItemData'),
        ('inJson', 'HWJson'),
      ]) {
        expect(
          () => decoded(name),
          throwsGeneratorError(
            contains(
              'Write HWAppearanceData(light: $wrapper(...), '
              'dark: $wrapper(...)) instead.',
            ),
          ),
        );
      }
    });

    test('is no format setting', () {
      expect(
        () => widgetOf('AppearanceCurrency'),
        throwsGeneratorError(contains('HWCurrency.data cannot be')),
      );
      expect(
        () => widgetOf('AppearanceZone'),
        throwsGeneratorError(contains('HWTimeZone.data cannot be')),
      );
    });

    test('is no payload entry', () {
      for (final name in ['AppearanceLink', 'AppearancePayload']) {
        expect(
          () => widgetOf(name),
          throwsGeneratorError(contains('is an HWAppearanceData. A tap')),
        );
      }
    });
  });
}
