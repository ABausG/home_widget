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

const string = HWString.fixed('Hi');
const localizedString = HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'});
const integer = HWInt.fixed(3);
const decimal = HWDouble.fixed(2.5);
const wholeDecimal = HWDouble.fixed(3);
const flag = HWBool.fixed(true);
const lowFlag = HWBool.fixed(false);
const date = HWDateTime.fixed('2026-09-22T10:00:00Z');
const image = HWImageData.asset('assets/logo.png');
const icon = HWIconData.fixed(Icons.wb_sunny);
const directionalIcon = HWIconData.fixed(Icons.arrow_back);
const notAnIcon = HWIconData.fixed('Icons.wb_sunny');

const storedString = HWString('label', defaultValue: 'Hi');
const storedInteger = HWInt('count', defaultValue: 3);
const storedDecimal = HWDouble('ratio', defaultValue: 2.5);
const storedFlag = HWBool('flag', defaultValue: true);
const storedDate = HWDateTime('at', previewValue: '2026-09-22T10:00:00Z');

@HomeWidget(
  name: 'IconDataForm',
  widget: HWIcon(
    HWIconData.fixed(Icons.wb_sunny),
    size: 32,
    color: HWColor.fixed(0xFF112233),
    semanticLabel: 'Sunny',
  ),
)
class IconDataForm {}

@HomeWidget(
  name: 'DirectionalIconDataForm',
  widget: HWIcon(HWIconData.fixed(Icons.arrow_back)),
)
class DirectionalIconDataForm {}

@HomeWidget(
  name: 'NotAnIconDataForm',
  widget: HWIcon(HWIconData.fixed('Icons.wb_sunny')),
)
class NotAnIconDataForm {}

@HomeWidget(
  name: 'OutOfRangeIconDataForm',
  widget: HWIcon(
    HWIconData.fixed(IconData(0x110000, fontFamily: 'MaterialIcons')),
  ),
)
class OutOfRangeIconDataForm {}

@HomeWidget(
  name: 'LocalizedDataForm',
  widget: HWText(HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'})),
)
class LocalizedDataForm {}

@HomeWidget(
  name: 'TextDataForm',
  widget: HWColumn(
    children: [
      HWText(HWString.fixed('Hi')),
      HWText.number(HWInt.fixed(3), format: HWNumberFormat.percent()),
      HWText.number(HWDouble.fixed(2.5), format: HWNumberFormat.compact()),
    ],
  ),
)
class TextDataForm {}

@HomeWidget(
  name: 'FixedDate',
  widget: HWText.dateTime(
    HWDateTime.fixed('2026-09-22T10:00:00Z'),
    format: HWDateFormat.yMMMd,
  ),
)
class FixedDate {}

@HomeWidget(
  name: 'FixedFlagConditional',
  widget: HWBoolConditional(
    data: HWBool.fixed(true),
    whenTrue: HWText(HWString.fixed('on')),
    whenFalse: HWText(HWString.fixed('off')),
  ),
)
class FixedFlagConditional {}
''';

/// The top-level constant of [_schemas] holding the fixed form of [type], or
/// null for a wrapper, which has none.
///
/// Exhaustive over the sealed [HWDataType] on purpose: a new data type does
/// not compile here until it is given a fixed form, or is ruled a wrapper.
/// Add it to [_everyDataType] as well.
String? _fixedFormOf(HWDataType<dynamic> type) => switch (type) {
      HWLocalizedString() => 'localizedString',
      HWString() => 'string',
      HWInt() => 'integer',
      HWDouble() => 'decimal',
      HWBool() => 'flag',
      HWDateTime() => 'date',
      HWImageData() => 'image',
      HWIconData() => 'icon',
      HWJson() || HWTimedData() || HWItemData() => null,
    };

/// Whether the fixed form of [type] stays a data dependency of the widget
/// reading it, or null for a wrapper, which has no fixed form.
///
/// Exhaustive for the reason [_fixedFormOf] is.
bool? _fixedFormIsDataDependency(HWDataType<dynamic> type) => switch (type) {
      HWLocalizedString() => true,
      HWString() => false,
      HWInt() => false,
      HWDouble() => false,
      HWBool() => false,
      HWDateTime() => false,
      HWImageData() => true,
      HWIconData() => false,
      HWJson() || HWTimedData() || HWItemData() => null,
    };

/// One stored instance of every concrete data type.
const _everyDataType = <HWDataType<dynamic>>[
  HWString('label'),
  HWLocalizedString('title', defaultTranslations: {'en': 'Title'}),
  HWInt('count'),
  HWDouble('ratio'),
  HWBool('flag'),
  HWDateTime('at'),
  HWImageData('avatar'),
  HWIconData('mood', icons: []),
  HWJson('group', HWString('label')),
  HWTimedData(HWString('label')),
  HWItemData(HWString('label')),
];

void main() {
  late Map<String, DartObject> constants;
  late Map<String, ElementAnnotation> annotations;
  late File file;

  setUpAll(() async {
    file = File(
      p.join(
        Directory.current.path,
        'test',
        'temp_fixed_${DateTime.now().microsecondsSinceEpoch}.dart',
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

  HWWidget widgetOf(String name) => WidgetValueDecoder(
        annotations[name]!.computeConstantValue()!.getField('widget'),
        defaultLocale: 'en',
        resourcePrefix: 'home_widget_test_widget',
        fontResourcePrefix: 'hw_font_test_widget',
      ).decode();

  group('every data type has a fixed form', () {
    test('that is fixed and decodes as fixed, wrappers aside', () {
      final covered = <Type>{};
      for (final type in _everyDataType) {
        covered.add(type.runtimeType);
        expect(
          type.isDataDependency,
          isTrue,
          reason: 'a stored ${type.runtimeType} is no data dependency',
        );
        final name = _fixedFormOf(type);
        if (name == null) {
          expect(_fixedFormIsDataDependency(type), isNull);
          expect(
            type,
            anyOf(
              isA<HWJson<dynamic>>(),
              isA<HWTimedData<dynamic>>(),
              isA<HWItemData<dynamic>>(),
            ),
          );
          continue;
        }

        final fixed = decoded(name);
        expect(fixed, isNotNull, reason: '$name does not decode');
        expect(fixed!.isFixed, isTrue, reason: '$name is not fixed');
        expect(
          fixed.runtimeType,
          type.runtimeType,
          reason: '$name is not the fixed form of ${type.runtimeType}',
        );
        expect(
          fixed.isDataDependency,
          _fixedFormIsDataDependency(type),
          reason: '$name as a data dependency',
        );
      }
      expect(covered, hasLength(_everyDataType.length));
    });
  });

  group('decodes', () {
    test('HWString.fixed', () {
      expect(decoded('string'), const HWString.fixed('Hi'));
    });

    test('HWString.localizedFixed, with the locale and prefix stamped on', () {
      final string = decoded('localizedString');

      expect(
        string,
        const HWLocalizedString.resolved(
          '',
          defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
          isConstant: true,
          defaultLocale: 'en',
          resourcePrefix: 'home_widget_test_widget',
        ),
      );
    });

    test('HWInt.fixed', () {
      expect(decoded('integer'), const HWInt.fixed(3));
    });

    test('HWDouble.fixed', () {
      expect(decoded('decimal'), const HWDouble.fixed(2.5));
      expect(decoded('wholeDecimal'), const HWDouble.fixed(3));
    });

    test('HWBool.fixed, a false one included', () {
      expect(decoded('flag'), const HWBool.fixed(true));
      expect(decoded('lowFlag'), const HWBool.fixed(false));
    });

    test('HWDateTime.fixed, keeping the text as written', () {
      expect(
        decoded('date'),
        const HWDateTime.fixed('2026-09-22T10:00:00Z'),
      );
    });

    test('HWImageData.asset', () {
      expect(decoded('image'), const HWImageData.asset('assets/logo.png'));
    });

    test('HWIconData.fixed to its glyph, font and direction', () {
      final icon = decoded('icon') as HWIconData;
      expect(icon.fixedCodePoint, isNotNull);
      expect(icon.fixedIcon, isNull);
      expect(icon.iconFont, const HWIconFont(family: 'MaterialIcons'));
      expect(icon.fixedMatchTextDirection, isFalse);
      expect(icon.entries, isEmpty);
      expect(icon.codePoints, {icon.fixedCodePoint});

      final directional = decoded('directionalIcon') as HWIconData;
      expect(directional.fixedMatchTextDirection, isTrue);
      expect(directional.mirroredCodePoints, {directional.fixedCodePoint});
    });

    test('rejects an HWIconData.fixed that is not an icon', () {
      expect(
        () => decoded('notAnIcon'),
        throwsA(
          isA<GeneratorError>().having(
            (error) => error.message,
            'message',
            'Could not decode HWIconData.fixed. It takes a Flutter IconData '
                'such as Icons.favorite, got: String',
          ),
        ),
      );
    });

    test('a stored value as before', () {
      expect(
        decoded('storedString'),
        const HWString('label', defaultValue: 'Hi'),
      );
      expect(decoded('storedInteger'), const HWInt('count', defaultValue: 3));
      expect(
        decoded('storedDecimal'),
        const HWDouble('ratio', defaultValue: 2.5),
      );
      expect(decoded('storedFlag'), const HWBool('flag', defaultValue: true));
      expect(
        decoded('storedDate'),
        const HWDateTime('at', previewValue: '2026-09-22T10:00:00Z'),
      );
      for (final name in [
        'storedString',
        'storedInteger',
        'storedDecimal',
        'storedFlag',
        'storedDate',
      ]) {
        expect(decoded(name)!.isFixed, isFalse, reason: name);
      }
    });
  });

  group('HWIcon with an HWIconData.fixed', () {
    test('decodes to its glyph', () {
      final icon = widgetOf('IconDataForm') as HWIcon;
      final data = decoded('icon')! as HWIconData;

      expect(icon.data, isNull);
      expect(icon.codePoint, data.fixedCodePoint);
      expect(icon.font, const HWIconFont(family: 'MaterialIcons'));
      expect(icon.matchTextDirection, isFalse);
      expect(icon.size, 32);
      expect((icon.color! as HWFixedColor).value, 0xFF112233);
      expect(icon.semanticLabel, 'Sunny');
      expect(icon.fontResourcePrefix, 'hw_font_test_widget');
      expect(icon.dataDependencies, isEmpty);
      expect(icon.iconCodePoints, {
        const HWIconFont(family: 'MaterialIcons'): {data.fixedCodePoint},
      });
    });

    test('emits the glyph', () {
      final icon = widgetOf('IconDataForm') as HWIcon;
      final hex = '0x${icon.codePoint!.toRadixString(16).toUpperCase()}';

      expect(icon.toSwift(0, dataExpr: 'entry.data'), '''
Text(String(UnicodeScalar(UInt32($hex))!))
    .font(hwBundledFont("hw_font_icons_materialicons", size: 32))
    .frame(width: 32, height: 32)
    .foregroundColor(Color(red: 0.06666666666666667, green: 0.13333333333333333, blue: 0.2, opacity: 1.0))
    .accessibilityLabel("Sunny")''');
      expect(
        icon.toKotlin(0, dataExpr: 'data'),
        'Image(modifier = GlanceModifier.size(32.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, '
        'R.font.hw_font_test_widget__icons_materialicons, $hex, 32f)), '
        'contentDescription = "Sunny", '
        'colorFilter = ColorFilter.tint(ColorProvider('
        'day = Color(0xFF112233), night = Color(0xFF112233))))',
      );
      expect(icon.nativeHelpers, {HWNativeHelper.hwBundledFont});
      expect(icon.swiftViewModifiers, isEmpty);
    });

    test('mirrors a directional icon', () {
      final icon = widgetOf('DirectionalIconDataForm') as HWIcon;
      final hex = '0x${icon.codePoint!.toRadixString(16).toUpperCase()}';

      expect(icon.matchTextDirection, isTrue);
      expect(icon.toSwift(0, dataExpr: 'entry.data'), '''
Text(String(UnicodeScalar(UInt32($hex))!))
    .font(hwBundledFont("hw_font_icons_materialicons", size: 24))
    .frame(width: 24, height: 24)
    .foregroundColor(Color.primary)
    .accessibilityHidden(true)
    .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)''');
      expect(
        icon.toKotlin(0, dataExpr: 'data'),
        'Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, '
        'R.font.hw_font_test_widget__icons_materialicons, $hex, 24f, '
        'matchTextDirection = true)), contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))',
      );
      expect(
        icon.swiftViewModifiers,
        {r'@Environment(\.layoutDirection) var layoutDirection'},
      );
    });

    test('rejects a value that is not an icon', () {
      expect(
        () => widgetOf('NotAnIconDataForm'),
        throwsA(
          isA<GeneratorError>().having(
            (error) => error.message,
            'message',
            contains('Could not decode HWIconData.fixed'),
          ),
        ),
      );
    });

    test('rejects a glyph that is no codepoint', () {
      expect(
        () => widgetOf('OutOfRangeIconDataForm'),
        throwsA(
          isA<GeneratorError>().having(
            (error) => error.message,
            'message',
            contains('outside the Unicode range'),
          ),
        ),
      );
    });
  });

  group('HWText with a decoded fixed value', () {
    test('reads a localized constant out of its string resource', () {
      final text = widgetOf('LocalizedDataForm') as HWText;

      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(NSLocalizedString('
        '"home_widget_test_widget_t_50bb5ce3", comment: ""))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'data'),
        'Text(text = context.getString('
        'R.string.home_widget_test_widget_t_50bb5ce3), '
        'style = TextStyle(color = GlanceTheme.colors.onSurface))',
      );
      expect(text.nativeHelpers, isEmpty);
      expect(text.dataType, decoded('localizedString'));
      expect(text.dataDependencies, {text.dataType});
    });

    test('emits a fixed string and fixed numbers as literals', () {
      final column = widgetOf('TextDataForm');

      expect(column.toSwift(0, dataExpr: 'entry.data'), '''
VStack(alignment: .center, spacing: 0) {
    Text("Hi")
    Text(hwFormatPercent(NSNumber(value: 3.0), minFraction: nil, maxFraction: nil))
    Text(hwFormatCompact(NSNumber(value: 2.5)))
}''');
      expect(column.toKotlin(0, dataExpr: 'data'), '''
Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text(text = "Hi", style = TextStyle(color = GlanceTheme.colors.onSurface))
    Text(text = hwFormatPercent(3.0, null, null, hwFormatLocale(context)), style = TextStyle(color = GlanceTheme.colors.onSurface))
    Text(text = hwFormatCompact(2.5, hwFormatLocale(context)), style = TextStyle(color = GlanceTheme.colors.onSurface))
}''');
      expect(column.nativeHelpers, {
        HWNativeHelper.hwFormatPercent,
        HWNativeHelper.hwFormatCompact,
      });
      expect(column.dataDependencies, isEmpty);
    });

    test('keeps the format of a fixed date', () {
      final text = widgetOf('FixedDate') as HWText;

      expect(text.dataType, const HWDateTime.fixed('2026-09-22T10:00:00Z'));
      expect(text.dateFormat, HWDateFormat.yMMMd);
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        startsWith('Text(hwParseIsoDate("2026-09-22T10:00:00.000Z").map { '),
      );
      expect(text.dataDependencies, isEmpty);
      expect(text.nativeHelpers, contains(HWNativeHelper.hwParseIsoDate));
    });
  });

  test('a conditional on a fixed flag decodes, for the validator to reject',
      () {
    final conditional = widgetOf('FixedFlagConditional') as HWBoolConditional;

    expect(conditional.data, const HWBool.fixed(true));
  });
}
