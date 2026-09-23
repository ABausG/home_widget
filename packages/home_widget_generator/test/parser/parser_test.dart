import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
import 'package:home_widget_generator/src/parser/widget_value_decoder.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('WidgetTreeParser', () {
    setUp(() async {
      // Setup
    });

    tearDown(() {
      // Teardown
    });

    // Helper to resolve code
    Future<HWWidget> parseCode(String code) async {
      // We need to write a pubspec or something?
      // Actually, simplest is to write file to `test/src/parser/temp.dart` (inside project)
      // so it picks up the project's package config!
      // But we need to be careful with concurrency.

      final file = File(
        p.join(
          Directory.current.path,
          'test',
          'temp_${DateTime.now().millisecondsSinceEpoch}.dart',
        ),
      );
      await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

$code
''');

      try {
        final collection = AnalysisContextCollection(
          includedPaths: [file.path],
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );
        final context = collection.contextFor(file.path);
        final result = await context.currentSession.getResolvedUnit(file.path);

        if (result is! ResolvedUnitResult) {
          throw StateError('Failed to resolve');
        }

        final element = result.unit.declaredFragment!.element.classes.first;
        final annotation = element.metadata.annotations.firstWhere(
          (m) => m.element?.enclosingElement?.name == 'HomeWidget',
        );

        return WidgetTreeParser(annotation).parse();
      } finally {
        if (await file.exists()) await file.delete();
      }
    }

    Future<GeneratorError> expectParseError(String code) async {
      final file = File(
        p.join(
          Directory.current.path,
          'test',
          'temp_err_${DateTime.now().millisecondsSinceEpoch}.dart',
        ),
      );
      await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

$code
''');
      try {
        final collection = AnalysisContextCollection(
          includedPaths: [file.path],
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );
        final context = collection.contextFor(file.path);
        final result = await context.currentSession.getResolvedUnit(file.path);
        if (result is! ResolvedUnitResult) {
          throw StateError('Failed to resolve');
        }
        final element = result.unit.declaredFragment!.element.classes.first;
        final annotation = element.metadata.annotations.firstWhere(
          (m) => m.element?.enclosingElement?.name == 'HomeWidget',
        );
        try {
          WidgetTreeParser(annotation).parse();
        } on GeneratorError catch (e) {
          return e;
        }
        throw StateError('Expected GeneratorError');
      } finally {
        if (await file.exists()) await file.delete();
      }
    }

    test('parses HWColumn with children', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText.fixed('Hello'),
      HWText.fixed('World'),
    ],
    mainAxisAlignment: HWMainAxisAlignment.center,
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWColumn>());
      final column = widget as HWColumn;
      expect(column.children.length, 2);
      expect(column.children[0], isA<HWText>());
      expect(
        (column.children[0] as HWText).toSwift(0, dataExpr: ''),
        contains('Hello'),
      );
      expect(column.mainAxisAlignment, HWMainAxisAlignment.center);
      expect(
        column.kotlinImports,
        contains('import androidx.glance.layout.Spacer'),
      );
    });

    test('parses HWRow with children', () async {
      final code = '''
@HomeWidget(
  name: 'TestRow',
  widget: HWRow(
    children: [HWText.fixed('L'), HWText.fixed('R')],
    crossAxisAlignment: HWCrossAxisAlignment.end,
    mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
  ),
)
class TestRowWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWRow>());
      final row = widget as HWRow;
      expect(row.children, hasLength(2));
      expect(row.crossAxisAlignment, HWCrossAxisAlignment.end);
      expect(row.mainAxisAlignment, HWMainAxisAlignment.spaceBetween);
      final out = row.toSwift(0, dataExpr: 'd');
      expect(out, contains('HStack(alignment: .bottom, spacing: 0)'));
      expect(out, contains('Spacer(minLength: 0)'));
    });

    test('parses HWRow with a baseline cross-axis alignment', () async {
      final code = '''
@HomeWidget(
  name: 'BaselineRow',
  widget: HWRow(
    children: [HWText.fixed('34'), HWText.fixed('kg')],
    crossAxisAlignment: HWCrossAxisAlignment.baseline,
  ),
)
class BaselineRowWidget {}
''';
      final widget = await parseCode(code);
      final row = widget as HWRow;
      expect(row.crossAxisAlignment, HWCrossAxisAlignment.baseline);
      expect(
        row.toSwift(0, dataExpr: 'd'),
        contains('HStack(alignment: .firstTextBaseline, spacing: 0)'),
      );
      expect(
        row.toKotlin(0, dataExpr: 'd'),
        contains('Row(verticalAlignment = Alignment.Top)'),
      );
    });

    test('rejects a baseline cross-axis alignment on HWColumn', () async {
      final code = '''
@HomeWidget(
  name: 'BaselineColumn',
  widget: HWColumn(
    children: [HWText.fixed('a')],
    crossAxisAlignment: HWCrossAxisAlignment.baseline,
  ),
)
class BaselineColumnWidget {}
''';
      final error = await expectParseError(code);
      expect(error.message, contains('HWColumn'));
      expect(error.message, contains('HWCrossAxisAlignment.baseline'));
      expect(error.message, contains('only applies to HWRow'));
    });

    test('parses spacing written as an int or a double literal', () async {
      final code = '''
@HomeWidget(
  name: 'Spaced',
  widget: HWColumn(
    spacing: 8,
    children: [
      HWRow(spacing: 12.5, children: [HWText.fixed('a'), HWText.fixed('b')]),
      HWRow(children: [HWText.fixed('c')]),
    ],
  ),
)
class SpacedWidget {}
''';
      final column = await parseCode(code) as HWColumn;
      expect(column.spacing, 8.0);
      expect((column.children[0] as HWRow).spacing, 12.5);
      expect((column.children[1] as HWRow).spacing, 0);
    });

    test('rejects a negative spacing on HWRow', () async {
      final code = '''
@HomeWidget(
  name: 'NegativeRow',
  widget: HWRow(spacing: -4, children: [HWText.fixed('a')]),
)
class NegativeRowWidget {}
''';
      final error = await expectParseError(code);
      expect(error.message, 'HWRow spacing must be 0 or more, got -4.');
    });

    test('rejects a negative spacing on HWColumn', () async {
      final code = '''
@HomeWidget(
  name: 'NegativeColumn',
  widget: HWColumn(spacing: -2.5, children: [HWText.fixed('a')]),
)
class NegativeColumnWidget {}
''';
      final error = await expectParseError(code);
      expect(error.message, 'HWColumn spacing must be 0 or more, got -2.5.');
    });

    test('parses HWText with data', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText(HWString('title')),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWText>());
      final text = widget as HWText;
      // dataType is not directly exposed as public field in HWText?
      // We can check generated code.
      expect(text.toSwift(0, dataExpr: 'data'), contains('data.title'));
    });

    test('parses HWColoredBox and HWThemedColor', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColoredBox(
    color: HWThemedColor(
      light: HWFixedColor(0xFFFF0000),
      dark: HWFixedColor(0xFF00FF00),
    ),
    child: HWText.fixed('Colored'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWColoredBox>());
      final box = widget as HWColoredBox;
      expect(box.color, isA<HWThemedColor>());
      final themedColor = box.color as HWThemedColor;
      expect(themedColor.light, isA<HWFixedColor>());
      expect((themedColor.light as HWFixedColor).value, 0xFFFF0000);
      expect(themedColor.dark, isA<HWFixedColor>());
      expect((themedColor.dark as HWFixedColor).value, 0xFF00FF00);

      expect(box.child, isA<HWText>());
      expect((box.child as HWText).fixedContent, 'Colored');
    });

    test('parses HWText with HWTextStyle', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText.fixed('Styled', style: HWTextStyle(color: HWFixedColor(0xFF0000FF))),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWText>());
      final text = widget as HWText;
      expect(text.style, isNotNull);
      expect(text.style!.color, isA<HWFixedColor>());
      expect((text.style!.color as HWFixedColor).value, 0xFF0000FF);
    });

    test('parses HWDefaultColor', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColoredBox(
    color: HWDefaultColor(HWColorRole.contentPrimary),
    child: HWText.fixed('DefaultColor'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWColoredBox>());
      final box = widget as HWColoredBox;
      expect(box.color, isA<HWDefaultColor>());
      expect((box.color as HWDefaultColor).role, HWColorRole.contentPrimary);
    });

    test('parses HWDecoratedBox with HWBoxDecoration and HWBoxBorder',
        () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDecoratedBox(
    decoration: HWBoxDecoration(
      color: HWFixedColor(0xFFFFFFFF),
      border: HWBoxBorder(
        radius: 12,
        thickness: 2,
        color: HWFixedColor(0xFF000000),
      ),
    ),
    child: HWText.fixed('Decorated'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWDecoratedBox>());
      final box = widget as HWDecoratedBox;
      expect(box.decoration.color, isA<HWFixedColor>());
      expect((box.decoration.color! as HWFixedColor).value, 0xFFFFFFFF);
      expect(box.decoration.border, isNotNull);
      expect(box.decoration.border!.radius, 12.0);
      expect(box.decoration.border!.thickness, 2.0);
      expect(box.decoration.border!.color, isA<HWFixedColor>());
      expect((box.decoration.border!.color as HWFixedColor).value, 0xFF000000);
      expect((box.child as HWText).fixedContent, 'Decorated');
    });

    test('parses HWText with complex HWTextStyle and align', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText.fixed('Complex', 
    textAlign: HWTextAlign.center,
    style: HWTextStyle(
      fontSize: 24,
      fontWeight: HWFontWeight.bold,
      italic: true,
      underline: true,
      lineThrough: false,
    )
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWText>());
      final text = widget as HWText;
      expect(text.textAlign, HWTextAlign.center);
      expect(text.style, isNotNull);
      expect(text.style!.fontSize, 24.0);
      expect(text.style!.fontWeight, HWFontWeight.bold);
      expect(text.style!.italic, true);
      expect(text.style!.underline, true);
      expect(text.style!.lineThrough, false);
      expect(text.style!.baseStyle, isNull);
      expect(text.style!.androidFont, isNull);
    });

    test('parses a preset androidFont next to a custom family', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText.fixed('Serif',
    style: HWTextStyle(
      fontFamily: 'Chewy',
      androidFont: HWAndroidFont.serif,
    )
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final text = widget as HWText;
      expect(text.style!.fontFamily, 'Chewy');
      expect(text.style!.androidFont, HWAndroidFont.serif);
      expect(text.style!.kotlinRenderer(), isA<HWGlanceTextRenderer>());
    });

    test('parses a named androidFont family', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText.fixed('Casual',
    style: HWTextStyle(androidFont: HWAndroidFont.family('casual'))
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final text = widget as HWText;
      expect(text.style!.androidFont, const HWAndroidFont.family('casual'));
    });

    test('parses the two androidFont choices naming no family', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWRow(
    children: [
      HWText.fixed('System',
        style: HWTextStyle(
          fontFamily: 'Chewy',
          androidFont: HWAndroidFont.system,
        )
      ),
      HWText.fixed('Custom',
        style: HWTextStyle(
          fontFamily: 'Chewy',
          androidFont: HWAndroidFont.custom,
        )
      ),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final children = (widget as HWRow).children.cast<HWText>();
      expect(children[0].style!.androidFont, HWAndroidFont.system);
      expect(children[1].style!.androidFont, HWAndroidFont.custom);
      expect(children[0].kotlinRendersBitmapText, isFalse);
      expect(children[1].kotlinRendersBitmapText, isTrue);
    });

    test('parses androidFont on an HWRoleTextStyle', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText.fixed('Role',
    style: HWRoleTextStyle.caption(
      fontFamily: 'Chewy',
      androidFont: HWAndroidFont.monospace,
    )
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final text = widget as HWText;
      expect(text.style, isA<HWRoleTextStyle>());
      expect(text.style!.androidFont, HWAndroidFont.monospace);
    });

    test('parses HWRoleTextStyle and baseStyle', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText.fixed('Role',
    style: HWTextStyle(
      color: HWFixedColor(0xFF000000),
      baseStyle: HWRoleTextStyle.headline(
        italic: true,
      ),
    ),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWText>());
      final text = widget as HWText;
      expect(text.style, isNotNull);
      expect(text.style!.color, isNotNull);
      expect(text.style!.baseStyle, isNotNull);
      expect(text.style!.baseStyle, isA<HWRoleTextStyle>());
      final roleStyle = text.style!.baseStyle as HWRoleTextStyle;
      expect(roleStyle.role, HWTextStyleRole.headline);
      expect(roleStyle.italic, true);
    });

    test('parses HWPadding with HWEdgeInsets.all', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWPadding(
    padding: HWEdgeInsets.all(12),
    child: HWText.fixed('Pad'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWPadding>());
      final pad = widget as HWPadding;
      expect(pad.padding.top, 12.0);
      expect(pad.padding.bottom, 12.0);
      expect(pad.padding.left, 12.0);
      expect(pad.padding.right, 12.0);
      expect((pad.child as HWText).fixedContent, 'Pad');
    });

    test('parses HWPadding with HWEdgeInsets.symmetric', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWPadding(
    padding: HWEdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: HWText.fixed('x'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final pad = widget as HWPadding;
      expect(pad.padding.top, 4.0);
      expect(pad.padding.bottom, 4.0);
      expect(pad.padding.left, 8.0);
      expect(pad.padding.right, 8.0);
    });

    test('parses HWPadding with HWEdgeInsets.only', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWPadding(
    padding: HWEdgeInsets.only(left: 1, top: 2, right: 3, bottom: 4),
    child: HWText.fixed('y'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final pad = widget as HWPadding;
      expect(pad.padding.left, 1.0);
      expect(pad.padding.top, 2.0);
      expect(pad.padding.right, 3.0);
      expect(pad.padding.bottom, 4.0);
    });

    test('parses HWDataExists', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataExists(
    data: HWString('k'),
    whenPresent: HWText.fixed('yes'),
    whenAbsent: HWText.fixed('no'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWDataExists>());
      final cond = widget as HWDataExists;
      expect(cond.data, const HWString('k'));
      expect((cond.whenPresent as HWText).fixedContent, 'yes');
      expect((cond.whenAbsent as HWText).fixedContent, 'no');
    });

    test('parses HWBoolConditional', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWBoolConditional(
    data: HWBool('flag', defaultValue: false),
    whenTrue: HWText.fixed('T'),
    whenFalse: HWText.fixed('F'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWBoolConditional>());
      final cond = widget as HWBoolConditional;
      expect(cond.data, const HWBool('flag', defaultValue: false));
      expect((cond.whenTrue as HWText).fixedContent, 'T');
      expect((cond.whenFalse as HWText).fixedContent, 'F');
    });

    test('parses HWBoolConditional with HWJson child bool', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWBoolConditional(
    data: HWJson('profile', HWBool('isActive', defaultValue: false)),
    whenTrue: HWText.fixed('T'),
    whenFalse: HWText.fixed('F'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWBoolConditional>());
      final cond = widget as HWBoolConditional;
      expect(
        cond.data,
        const HWJson('profile', HWBool('isActive', defaultValue: false)),
      );
    });

    test('parses a nested HWJson path', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText(
    HWJson('profile', HWJson('address', HWString('city'))),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final text = widget as HWText;
      expect(
        text.dataType,
        const HWJson('profile', HWJson('address', HWString('city'))),
      );
      // A JSON child is a legal leaf wrapper, so the path keeps descending.
      expect(
        (text.dataType! as HWJson).pathSegments,
        ['address', 'city'],
      );
    });

    test('parses a localized HWJson leaf without losing its translations',
        () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en', 'de'],
  ),
  widget: HWText(
    HWJson(
      'profile',
      HWString.localized(
        'name',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      ),
    ),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final json = (widget as HWText).dataType! as HWJson;
      final leaf = json.leafType as HWLocalizedString;

      expect(json.pathSegments, ['name']);
      expect(leaf.defaultTranslations, {'en': 'Hello', 'de': 'Hallo'});
      expect(leaf.isConstant, isFalse);
      expect(leaf.baseLocaleTag, 'en');
    });

    test('parses a localized HWTimedData without losing its translations',
        () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  localization: HomeWidgetLocalization(
    defaultLocale: 'de',
    supportedLocales: ['en', 'de'],
  ),
  widget: HWText(
    HWTimedData(
      HWString.localized(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      ),
    ),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final timed = (widget as HWText).dataType! as HWTimedData;
      final inner = timed.unwrapped as HWLocalizedString;

      expect(inner.key, 'greeting');
      expect(inner.defaultTranslations, {'en': 'Hello', 'de': 'Hallo'});
      expect(inner.isConstant, isFalse);
    });

    test('parses a localized leaf inside a timed HWJson', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  localization: HomeWidgetLocalization(
    defaultLocale: 'de',
    supportedLocales: ['en', 'de'],
  ),
  widget: HWText(
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
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final timed = (widget as HWText).dataType! as HWTimedData;
      final json = timed.unwrapped as HWJson;
      final leaf = json.leafType as HWLocalizedString;

      expect(json.pathSegments, ['summary']);
      expect(leaf.defaultTranslations, {'en': 'Sunny', 'de': 'Sonnig'});
      expect(leaf.isConstant, isFalse);
    });

    test('parses HWDateTime, plain, timed and inside HWJson', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataOnly([
    HWDateTime('when'),
    HWTimedData(HWDateTime('next')),
    HWJson('event', HWDateTime('start')),
  ]),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(
        (widget as HWDataOnly).data,
        const [
          HWDateTime('when'),
          HWTimedData(HWDateTime('next')),
          HWJson('event', HWDateTime('start')),
        ],
      );
    });

    test('parses preview values on every data type', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataOnly([
    HWString('s', defaultValue: 'd', previewValue: 'p'),
    HWInt('i', previewValue: 7),
    HWDouble('d', previewValue: 1.5),
    HWBool('b', previewValue: true),
    HWDateTime('when', previewValue: '2021-01-01T00:00:00Z'),
    HWJson('root', HWInt('n', previewValue: 3)),
    HWTimedData(HWString('t', previewValue: 'later')),
  ]),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(
        (widget as HWDataOnly).data,
        const [
          HWString('s', defaultValue: 'd', previewValue: 'p'),
          HWInt('i', previewValue: 7),
          HWDouble('d', previewValue: 1.5),
          HWBool('b', previewValue: true),
          HWDateTime('when', previewValue: '2021-01-01T00:00:00Z'),
          HWJson('root', HWInt('n', previewValue: 3)),
          HWTimedData(HWString('t', previewValue: 'later')),
        ],
      );
    });

    test('parses previewTranslations on a localized string', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWText(
    HWString.localized(
      'greeting',
      defaultTranslations: {'en': 'Hello'},
      previewTranslations: {'en': 'Sample'},
    ),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final localized = (widget as HWText).dataType! as HWLocalizedString;
      expect(localized.defaultTranslations, {'en': 'Hello'});
      expect(localized.previewTranslations, {'en': 'Sample'});
    });

    test('parses a preview asset on a runtime image', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(
    HWImageData('avatar', previewAsset: 'assets/sample.png'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(
        (widget as HWImage).imageData,
        const HWImageData('avatar', previewAsset: 'assets/sample.png'),
      );
    });

    test('parses HWText.number with every number format', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText.number(HWInt('a')),
      HWText.number(
        HWDouble('b'),
        format: HWNumberFormat.decimal(
          minimumFractionDigits: 1,
          maximumFractionDigits: 3,
          useGrouping: false,
        ),
      ),
      HWText.number(
        HWDouble('c'),
        format: HWNumberFormat.percent(maximumFractionDigits: 0),
      ),
      HWText.number(
        HWDouble('d'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.code('EUR'),
          decimalDigits: 2,
        ),
      ),
      HWText.number(
        HWDouble('e'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWString('cur')),
        ),
      ),
      HWText.number(HWInt('f'), format: HWNumberFormat.compact()),
      HWText.number(HWDouble('g'), format: HWNumberFormat.pattern('#,##0.00')),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final texts = (widget as HWColumn).children.cast<HWText>();
      expect(
        texts.map((t) => t.numberFormat),
        const [
          HWNumberFormat.decimal(),
          HWNumberFormat.decimal(
            minimumFractionDigits: 1,
            maximumFractionDigits: 3,
            useGrouping: false,
          ),
          HWNumberFormat.percent(maximumFractionDigits: 0),
          HWNumberFormat.currency(
            currency: HWCurrency.code('EUR'),
            decimalDigits: 2,
          ),
          HWNumberFormat.currency(currency: HWCurrency.data(HWString('cur'))),
          HWNumberFormat.compact(),
          HWNumberFormat.pattern('#,##0.00'),
        ],
      );
      expect(texts.first.dataType, const HWInt('a'));
      expect(
        texts[4].dataDependencies,
        {const HWDouble('e'), const HWString('cur')},
      );
    });

    test('parses HWText.fixedNumber, int and double', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText.fixedNumber(1234),
      HWText.fixedNumber(12.5, format: HWNumberFormat.compact()),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final texts = (widget as HWColumn).children.cast<HWText>();
      expect(texts[0].fixedNumber, 1234);
      expect(texts[0].numberFormat, const HWNumberFormat.decimal());
      expect(texts[1].fixedNumber, 12.5);
      expect(texts[1].numberFormat, const HWNumberFormat.compact());
      expect(
        texts[0].toKotlin(0, dataExpr: 'd'),
        contains('hwFormatDecimal(1234.0'),
      );
    });

    test('parses HWText.dateTime with every date format and time zone',
        () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText.dateTime(HWDateTime('a')),
      HWText.dateTime(HWDateTime('b'), format: HWDateFormat.yMMMd),
      HWText.dateTime(
        HWDateTime('c'),
        format: HWDateFormat.pattern('dd.MM.yyyy'),
      ),
      HWText.dateTime(
        HWDateTime('d'),
        format: HWDateFormat.styled(date: HWFormatStyle.full),
      ),
      HWText.dateTime(HWDateTime('e'), timeZone: HWTimeZone.utc),
      HWText.dateTime(
        HWDateTime('f'),
        timeZone: HWTimeZone.named('Europe/Berlin'),
      ),
      HWText.dateTime(
        HWDateTime('g'),
        timeZone: HWTimeZone.data(HWString('tz')),
      ),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final texts = (widget as HWColumn).children.cast<HWText>();
      expect(
        texts.map((t) => t.dateFormat),
        [
          HWDateFormat.defaultFormat,
          HWDateFormat.yMMMd,
          const HWDateFormat.pattern('dd.MM.yyyy'),
          const HWDateFormat.styled(date: HWFormatStyle.full),
          HWDateFormat.defaultFormat,
          HWDateFormat.defaultFormat,
          HWDateFormat.defaultFormat,
        ],
      );
      expect(
        texts.map((t) => t.timeZone),
        [
          HWTimeZone.local,
          HWTimeZone.local,
          HWTimeZone.local,
          HWTimeZone.local,
          HWTimeZone.utc,
          const HWTimeZone.named('Europe/Berlin'),
          const HWTimeZone.data(HWString('tz')),
        ],
      );
      expect(
        texts.last.dataDependencies,
        {const HWDateTime('g'), const HWString('tz')},
      );
    });

    test('a plain HWText on a number or a date keeps no format', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText(HWInt('a')),
      HWText(HWDateTime('b')),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final texts = (widget as HWColumn).children.cast<HWText>();
      expect(texts[0].numberFormat, isNull);
      expect(texts[0].formatsNumber, isTrue);
      expect(texts[1].dateFormat, isNull);
      expect(texts[1].formatsDate, isTrue);
      expect(
        texts[1].toSwift(0, dataExpr: 'd'),
        contains('hwFormatDateStyled(\$0, dateStyle: .medium, '
            'timeStyle: .short)'),
      );
    });

    test('parses HWTimedData wrapping primitives', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataOnly([
    HWTimedData(HWString('label', defaultValue: 'Sunny')),
    HWTimedData(HWInt('somethingelse')),
  ]),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final data = (widget as HWDataOnly).data;
      expect(
        data,
        const [
          HWTimedData(HWString('label', defaultValue: 'Sunny')),
          HWTimedData(HWInt('somethingelse')),
        ],
      );
      expect(data.first.key, 'label');
      expect(data.first.defaultValue, 'Sunny');
    });

    test('parses HWTimedData wrapping HWJson', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataOnly([
    HWTimedData(HWJson('weather', HWString('condition', defaultValue: 'sun'))),
  ]),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(
        (widget as HWDataOnly).data,
        const [
          HWTimedData(
            HWJson('weather', HWString('condition', defaultValue: 'sun')),
          ),
        ],
      );
    });

    test('throws when HWTimedData is nested inside HWTimedData', () async {
      final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataExists(
    data: HWTimedData(HWTimedData(HWString('label'))),
    whenPresent: HWText.fixed('yes'),
    whenAbsent: HWText.fixed('no'),
  ),
)
class TestWidget {}
''');
      expect(e.message, 'HWTimedData cannot be nested inside HWTimedData');
    });

    test('throws when HWTimedData is nested inside HWJson', () async {
      final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataExists(
    data: HWJson('weather', HWTimedData(HWString('condition'))),
    whenPresent: HWText.fixed('yes'),
    whenAbsent: HWText.fixed('no'),
  ),
)
class TestWidget {}
''');
      expect(
        e.message,
        'HWTimedData must be a root-level data field and cannot be nested '
        'inside HWJson',
      );
    });

    test('throws when HWJson has no child field', () async {
      final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataExists(
    data: HWJson('profile'),
    whenPresent: HWText.fixed('yes'),
    whenAbsent: HWText.fixed('no'),
  ),
)
class TestWidget {}
''');
      expect(e.message, 'HWDataExists requires data');
    });

    group('list builders', () {
      /// Stand-ins for Flutter's `IconData`, which the decoder reads by field.
      const icons = '''
class IconData {
  final int codePoint;
  final String? fontFamily;
  const IconData(this.codePoint, {this.fontFamily});
}

const sunny = IconData(0xe430, fontFamily: 'MaterialIcons');
const cloud = IconData(0xe16f, fontFamily: 'MaterialIcons');
const umbrella = IconData(0xe6d2, fontFamily: 'MaterialIcons');
''';

      test('parses HWRow.builder and HWColumn.builder', () async {
        final column = await parseCode('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWRow.builder(
        'forecast',
        maxItems: 5,
        spacing: 12,
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        crossAxisAlignment: HWCrossAxisAlignment.baseline,
        item: HWColumn(
          children: [
            HWText(HWItemData(HWString('day'))),
            HWText(HWString('unit')),
          ],
        ),
        whenEmpty: HWText.fixed('No forecast yet'),
      ),
      HWColumn.builder(
        'events',
        crossAxisAlignment: HWCrossAxisAlignment.start,
        item: HWText.fixed('event'),
      ),
    ],
  ),
)
class TestWidget {}
''') as HWColumn;
        final row = column.children[0] as HWRow;
        final events = column.children[1] as HWColumn;

        expect(column.isBuilder, isFalse);
        expect(row.isBuilder, isTrue);
        expect(row.list, 'forecast');
        expect(row.maxItems, 5);
        expect(row.spacing, 12.0);
        expect(row.mainAxisAlignment, HWMainAxisAlignment.spaceBetween);
        expect(row.crossAxisAlignment, HWCrossAxisAlignment.baseline);
        expect(row.children, isEmpty);
        expect(row.item, isA<HWColumn>());
        expect(row.whenEmpty, isA<HWText>());
        expect(row.dataDependencies, {const HWString('unit')});
        expect(row.itemReads, [const HWItemData(HWString('day'))]);

        expect(events.isBuilder, isTrue);
        expect(events.list, 'events');
        expect(events.maxItems, isNull);
        expect(events.whenEmpty, isNull);
        expect(events.spacing, 0);
        expect(events.crossAxisAlignment, HWCrossAxisAlignment.start);
        expect(events.item, isA<HWText>());
      });

      test('parses HWItemData over every field type with its previewValues',
          () async {
        final row = await parseCode('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWRow.builder(
    'rows',
    item: HWDataOnly([
      HWItemData(HWString('label'), previewValues: ['Mon', 'Tue']),
      HWItemData(
        HWString.localized('title', defaultTranslations: {'en': 'Event'}),
        previewValues: ['Party'],
      ),
      HWItemData(HWInt('count', defaultValue: 0), previewValues: [21, 17]),
      HWItemData(HWDouble('ratio'), previewValues: [1, 2.5]),
      HWItemData(HWBool('done'), previewValues: [true, false]),
      HWItemData(HWDateTime('day'), previewValues: ['2026-09-21T12:00:00Z']),
      HWItemData(HWImageData('avatar'), previewValues: ['assets/a.png']),
      HWItemData(
        HWIconData('condition', icons: [sunny, cloud]),
        previewValues: [cloud, sunny],
      ),
      HWItemData(HWString('plain')),
      HWTimedData(HWItemData(HWInt('hour'))),
    ]),
  ),
)
class TestWidget {}
$icons''') as HWRow;
        final data = (row.item! as HWDataOnly).data;

        expect(
          data[0],
          const HWItemData(HWString('label'), previewValues: ['Mon', 'Tue']),
        );
        final title = data[1] as HWItemData;
        expect(title.data, isA<HWLocalizedString>());
        expect(title.previewValues, ['Party']);
        expect(
          data[2],
          const HWItemData(
            HWInt('count', defaultValue: 0),
            previewValues: [21, 17],
          ),
        );
        final ratio = (data[3] as HWItemData).previewValues!;
        expect(ratio, [1.0, 2.5]);
        expect(ratio.first, isA<double>());
        expect(
          data[4],
          const HWItemData(HWBool('done'), previewValues: [true, false]),
        );
        expect(
          data[5],
          const HWItemData(
            HWDateTime('day'),
            previewValues: ['2026-09-21T12:00:00Z'],
          ),
        );
        expect(
          data[6],
          const HWItemData(
            HWImageData('avatar'),
            previewValues: ['assets/a.png'],
          ),
        );
        final condition = data[7] as HWItemData;
        expect(condition.previewValues, [0xe16f, 0xe430]);
        expect(iconLeafOf(condition)!.codePoints, {0xe430, 0xe16f});
        expect(data[8], const HWItemData(HWString('plain')));
        expect(data[9], const HWTimedData(HWItemData(HWInt('hour'))));
        expect(row.dataDependencies, isEmpty);
        expect(row.itemReads, data);
      });

      test('decodes item fields wherever a data field is taken', () async {
        final column = await parseCode('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder(
    'rows',
    item: HWColumn(
      children: [
        HWText.number(
          HWItemData(HWDouble('price')),
          format: HWNumberFormat.currency(
            currency: HWCurrency.data(HWItemData(HWString('currency'))),
          ),
        ),
        HWText.dateTime(
          HWItemData(HWDateTime('start')),
          timeZone: HWTimeZone.data(HWItemData(HWString('zone'))),
        ),
        HWImage(HWItemData(HWImageData('avatar'))),
        HWIcon(HWItemData(HWIconData('mood', icons: [sunny]))),
        HWDataExists(
          data: HWItemData(HWString('note')),
          whenPresent: HWText(HWItemData(HWString('note'))),
          whenAbsent: HWText(HWString('fallback')),
        ),
        HWBoolConditional(
          data: HWItemData(HWBool('done', defaultValue: false)),
          whenTrue: HWText.fixed('done'),
          whenFalse: HWText.fixed('open'),
        ),
      ],
    ),
  ),
)
class TestWidget {}
$icons''') as HWColumn;

        expect(column.dataDependencies, {const HWString('fallback')});
        expect(
          column.itemReads.map((read) => read.key),
          [
            'price',
            'currency',
            'start',
            'zone',
            'avatar',
            'mood',
            'note',
            'done',
          ],
        );
        final swift = column.toSwift(0, dataExpr: 'entry.data');
        expect(swift, contains('code: hwItem.currency ?? "", decimals: nil'));
        expect(swift, contains('timeZone: hwItem.zone'));
        expect(swift, contains('if let path = hwItem.avatar,'));
        expect(swift, contains('if let codePoint = hwItem.mood,'));
        expect(swift, contains('if hwItem.note != nil {'));
        expect(swift, contains('if hwItem.done == true {'));
        expect(swift, contains('Text(entry.data.fallback ?? "")'));
      });

      test('parses a builder inside the whenEmpty of another', () async {
        final row = await parseCode('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWRow.builder(
    'days',
    item: HWText(HWItemData(HWString('day'))),
    whenEmpty: HWColumn.builder(
      'hints',
      item: HWText(HWItemData(HWString('hint'))),
    ),
  ),
)
class TestWidget {}
''') as HWRow;
        final hints = row.whenEmpty! as HWColumn;

        expect(hints.list, 'hints');
        expect(hints.itemReads, [const HWItemData(HWString('hint'))]);
        expect(row.dataDependencies, isEmpty);
      });

      test('rejects a builder inside the item of another, naming both',
          () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWRow.builder(
    'days',
    item: HWColumn.builder('hours', item: HWText.fixed('hour')),
  ),
)
class TestWidget {}
''');
        expect(
          e.message,
          "Nested lists aren't supported yet: HWColumn.builder('hours') sits "
          "inside the item of HWRow.builder('days').",
        );
      });

      test('rejects a builder nested deep inside the item of another',
          () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder(
    'days',
    item: HWPadding(
      padding: HWEdgeInsets.all(4),
      child: HWColumn(
        children: [
          HWDataExists(
            data: HWItemData(HWString('note')),
            whenPresent: HWText.fixed('note'),
            whenAbsent: HWRow.builder('hours', item: HWText.fixed('hour')),
          ),
        ],
      ),
    ),
  ),
)
class TestWidget {}
''');
        expect(
          e.message,
          "Nested lists aren't supported yet: HWRow.builder('hours') sits "
          "inside the item of HWColumn.builder('days').",
        );
      });

      test('rejects a maxItems below 1', () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWRow.builder('forecast', maxItems: 0, item: HWText.fixed('a')),
)
class TestWidget {}
''');
        expect(
          e.message,
          "HWRow.builder('forecast') maxItems must be 1 or more, got 0.",
        );
      });

      test('rejects a negative spacing, naming the builder', () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder('events', spacing: -4, item: HWText.fixed('a')),
)
class TestWidget {}
''');
        expect(
          e.message,
          "HWColumn.builder('events') spacing must be 0 or more, got -4.",
        );
      });

      test('rejects a baseline cross-axis alignment on HWColumn.builder',
          () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder(
    'events',
    crossAxisAlignment: HWCrossAxisAlignment.baseline,
    item: HWText.fixed('a'),
  ),
)
class TestWidget {}
''');
        expect(e.message, contains('only applies to HWRow'));
      });

      for (final (wrapped, message) in [
        (
          "HWTimedData(HWInt('temperature'))",
          'HWItemData cannot wrap HWTimedData. A list is time-based as a '
              'whole, so write HWTimedData(HWItemData(...)) instead.',
        ),
        (
          "HWJson('weather', HWString('condition'))",
          'HWItemData cannot wrap HWJson. JSON objects inside a list item are '
              'not supported yet; wrap each value in an HWItemData of its own.',
        ),
        (
          "HWItemData(HWString('label'))",
          'HWItemData cannot wrap another HWItemData. A field reads the item '
              'of the builder it sits in, so wrap it in HWItemData once.',
        ),
        (
          "HWImageData.asset('assets/logo.png')",
          'HWItemData cannot wrap the asset image "assets/logo.png". An asset '
              'ships with the app, so there is nothing to store per item; '
              'show it with HWImage.asset instead.',
        ),
      ]) {
        test('rejects HWItemData($wrapped)', () async {
          final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder(
    'rows',
    item: HWDataOnly([HWItemData($wrapped)]),
  ),
)
class TestWidget {}
''');
          expect(e.message, message);
        });
      }

      test('rejects an item field inside HWJson', () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder(
    'rows',
    item: HWText(HWJson('weather', HWItemData(HWString('condition')))),
  ),
)
class TestWidget {}
''');
        expect(
          e.message,
          'An item field can\'t sit inside HWJson ("weather"). Use HWItemData '
          'on its own, inside the item of an HWColumn.builder or '
          'HWRow.builder.',
        );
      });

      test('an HWItemData missing its field decodes to nothing', () async {
        final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWDataExists(
    data: HWItemData(),
    whenPresent: HWText.fixed('yes'),
    whenAbsent: HWText.fixed('no'),
  ),
)
class TestWidget {}
''');
        expect(e.message, 'HWDataExists requires data');
      });

      for (final (field, previewValues, message) in [
        (
          "HWInt('count')",
          '[]',
          'The previewValues of HWItemData "count" are empty. Leave them '
              'out, or list one value per sample item.',
        ),
        (
          "HWInt('count')",
          "[1, 'two']",
          'previewValues[1] of HWItemData "count" must be an int, got String.',
        ),
        (
          "HWInt('count')",
          '[1, null]',
          'previewValues[1] of HWItemData "count" is null. List a value for '
              'every sample item.',
        ),
        (
          "HWDouble('ratio')",
          "[true]",
          'previewValues[0] of HWItemData "ratio" must be a number, got bool.',
        ),
        (
          "HWBool('done')",
          '[1]',
          'previewValues[0] of HWItemData "done" must be a bool, got int.',
        ),
        (
          "HWString('label')",
          '[1]',
          'previewValues[0] of HWItemData "label" must be a String, got int.',
        ),
        (
          "HWDateTime('day')",
          '[1]',
          'previewValues[0] of HWItemData "day" must be an ISO 8601 String, '
              'got int.',
        ),
        (
          "HWImageData('avatar')",
          '[1]',
          'previewValues[0] of HWItemData "avatar" must be the String path '
              'of a Flutter asset, got int.',
        ),
        (
          "HWIconData('condition', icons: [sunny, cloud])",
          "['sunny']",
          'previewValues[0] of HWItemData "condition" must be an IconData '
              'such as Icons.wb_sunny, got String.',
        ),
        (
          "HWIconData('condition', icons: [sunny, cloud])",
          '[cloud, umbrella]',
          'previewValues[1] of HWItemData "condition" is not one of its '
              'icons.',
        ),
      ]) {
        test('rejects previewValues $previewValues for $field', () async {
          final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn.builder(
    'rows',
    item: HWDataOnly([HWItemData($field, previewValues: $previewValues)]),
  ),
)
class TestWidget {}
$icons''');
          expect(e.message, message);
        });
      }
    });

    test('parses HWSizedBox.expand', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWSizedBox.expand(
    child: HWText.fixed('fill'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWSizedBox>());
      final box = widget as HWSizedBox;
      expect(box.width, double.infinity);
      expect(box.height, double.infinity);
      expect((box.child as HWText).fixedContent, 'fill');
    });

    test('parses HWSizedBox dimensions written as int and double', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWSizedBox(width: 8, height: 8.5),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final box = widget as HWSizedBox;
      expect(box.width, 8.0);
      expect(box.height, 8.5);
      expect(box.child, isNull);
    });

    test('parses HWSizedBox.shrink', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWSizedBox.shrink(),
)
class TestWidget {}
''';
      final box = await parseCode(code) as HWSizedBox;
      expect(box.width, 0.0);
      expect(box.height, 0.0);
      expect(box.child, isNull);
    });

    test('throws when an HWSizedBox dimension is negative', () async {
      final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWSizedBox(width: -1),
)
class TestWidget {}
''');
      expect(
        e.message,
        'HWSizedBox: width has to be zero or more, got -1.0.',
      );
    });

    test('throws when an HWSizedBox dimension is NaN', () async {
      final e = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWSizedBox(height: double.nan),
)
class TestWidget {}
''');
      expect(
        e.message,
        'HWSizedBox: height has to be zero or more, got NaN.',
      );
    });

    test('parses HWStack with its alignment and fit', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWStack(
    alignment: HWAlignment.bottomEnd,
    fit: HWStackFit.expand,
    children: [
      HWText.fixed('back'),
      HWText.fixed('front'),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWStack>());
      final stack = widget as HWStack;
      expect(stack.alignment, HWAlignment.bottomEnd);
      expect(stack.fit, HWStackFit.expand);
      expect(stack.children, hasLength(2));
      expect((stack.children.first as HWText).fixedContent, 'back');
    });

    test('parses an HWStack left at its defaults', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWStack(children: [HWText.fixed('only')]),
)
class TestWidget {}
''';
      final stack = await parseCode(code) as HWStack;
      expect(stack.alignment, HWAlignment.topStart);
      expect(stack.fit, HWStackFit.loose);
    });

    test('parses HWAlign with its alignment', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWAlign(
    alignment: HWAlignment.centerEnd,
    child: HWText.fixed('placed'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWAlign>());
      final align = widget as HWAlign;
      expect(align.alignment, HWAlignment.centerEnd);
      expect((align.child as HWText).fixedContent, 'placed');
    });

    test('parses an HWAlign left at its default', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWAlign(child: HWText.fixed('placed')),
)
class TestWidget {}
''';
      final align = await parseCode(code) as HWAlign;
      expect(align.alignment, HWAlignment.center);
    });

    test('parses HWImage with runtime HWImageData', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(HWImageData('avatar')),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWImage>());
      final image = widget as HWImage;
      expect(image.dataType, const HWImageData('avatar'));
      expect(image.imageData.key, 'avatar');
      expect(image.imageData.isAsset, isFalse);
      expect(image.fit, HWImageFit.contain);
      expect(image.width, isNull);
      expect(image.height, isNull);
      expect(image.semanticLabel, isNull);
      expect(image.dataDependencies, {const HWImageData('avatar')});
      expect(image.toSwift(0, dataExpr: 'data'), contains('data.avatar'));
      expect(image.toKotlin(0, dataExpr: 'data'), contains('data.avatar'));
    });

    test('parses HWImage with a timed HWImageData', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(HWTimedData(HWImageData('slide')), width: 32),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final image = widget as HWImage;
      expect(image.dataType, const HWTimedData(HWImageData('slide')));
      expect(image.imageData, const HWImageData('slide'));
      expect(image.width, 32);
      expect(image.dataDependencies, {
        const HWTimedData(HWImageData('slide')),
      });
      expect(image.toSwift(0, dataExpr: 'data'), contains('data.slide'));
      expect(image.toKotlin(0, dataExpr: 'data'), contains('data.slide'));
    });

    test('parses HWImage with an image at a JSON leaf', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(HWJson('contact', HWImageData('avatar'))),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final image = widget as HWImage;
      expect(image.dataType, const HWJson('contact', HWImageData('avatar')));
      expect(image.imageData, const HWImageData('avatar'));
      expect(
        image.toSwift(0, dataExpr: 'data'),
        contains('data.contact?.avatar'),
      );
      expect(
        image.toKotlin(0, dataExpr: 'data'),
        contains('data.contact?.avatar'),
      );
    });

    test('throws when HWImage is handed something other than an image',
        () async {
      final error = await expectParseError('''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(HWString('label')),
)
class TestWidget {}
''');
      expect(error.message, contains('HWImage requires an HWImageData'));
    });

    test('parses HWImage.asset and derives the key', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage.asset(
    'assets/images/logo.png',
    width: 100,
    height: 50,
    fit: HWImageFit.cover,
    semanticLabel: 'Logo',
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWImage>());
      final image = widget as HWImage;
      expect(image.imageData.isAsset, isTrue);
      expect(image.imageData.assetPath, 'assets/images/logo.png');
      expect(image.imageData.key, 'assetsImagesLogoPng');
      expect(image.width, 100.0);
      expect(image.height, 50.0);
      expect(image.fit, HWImageFit.cover);
      expect(image.semanticLabel, 'Logo');
      final swift = image.toSwift(0, dataExpr: 'data');
      expect(swift, contains('hwDecodeImage("assets/images/logo.png"'));
      expect(swift, contains('.frame(width: 100.0, height: 50.0)'));
      expect(swift, contains('.accessibilityLabel("Logo")'));
    });

    test('parses HWImage.asset with a package', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage.asset('assets/logo.png', package: 'my_icons'),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final image = widget as HWImage;
      expect(image.assetPackage, 'my_icons');
      expect(image.imageData.assetPath, 'assets/logo.png');
      expect(image.imageData.package, 'my_icons');
      expect(
        image.imageData.effectiveAssetKey,
        'packages/my_icons/assets/logo.png',
      );
      expect(image.imageData.key, 'packagesMyIconsAssetsLogoPng');
      expect(image.dataDependencies, {
        const HWImageData.asset('assets/logo.png', package: 'my_icons'),
      });
      expect(
        image.toSwift(0, dataExpr: 'data'),
        contains('hwDecodeImage("packages/my_icons/assets/logo.png"'),
      );
    });

    test('parses an explicit HWImageData.asset with a package', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(HWImageData.asset('assets/logo.png', package: 'my_icons')),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final image = widget as HWImage;
      expect(
        image.dataType,
        const HWImageData.asset('assets/logo.png', package: 'my_icons'),
      );
      expect(image.imageData.key, 'packagesMyIconsAssetsLogoPng');
    });

    test('parses HWImage with an explicit HWImageData.asset', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWImage(HWImageData.asset('assets/logo.png')),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final image = widget as HWImage;
      expect(image.dataType, const HWImageData.asset('assets/logo.png'));
      expect(image.imageData.key, 'assetsLogoPng');
    });

    test('parses HWImage nested in a column', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWColumn(
    children: [
      HWText.fixed('Title'),
      HWImage(HWImageData('avatar'), fit: HWImageFit.fill),
    ],
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      final column = widget as HWColumn;
      expect(column.children[1], isA<HWImage>());
      expect((column.children[1] as HWImage).fit, HWImageFit.fill);
      expect(column.dataDependencies, {const HWImageData('avatar')});
      expect(
        column.kotlinImports,
        containsAll(<String>[
          'import androidx.glance.Image',
          'import androidx.glance.ImageProvider',
        ]),
      );
      expect(column.nativeHelpers, contains(HWNativeHelper.hwDecodeImage));
    });

    test('throws when annotation constant value cannot be computed', () async {
      final e = await expectParseError('''
String n = "N";
@HomeWidget(
  name: n,
  widget: HWText.fixed("a"),
)
class BadConst {}
''');
      expect(
        e.message,
        'Could not compute constant value for annotation',
      );
    });

    test('throws when @HomeWidget has no widget', () async {
      final e = await expectParseError('''
@HomeWidget(name: "A")
class NoWidget {}
''');
      expect(
        e.message,
        'HomeWidget annotation does not contain a widget definition',
      );
    });
  });

  group('WidgetValueDecoder', () {
    test('throws when object reference is null', () {
      expect(
        () => WidgetValueDecoder(null).decode(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            'Widget object is null',
          ),
        ),
      );
    });

    test('throws for analyzer null object (isNull) same as null', () async {
      final file = File(
        p.join(
          Directory.current.path,
          'test',
          'temp_wvd_isnull_${DateTime.now().millisecondsSinceEpoch}.dart',
        ),
      );
      await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

const aNull = null;
@HomeWidget(
  name: "A",
  widget: HWText.fixed("a"),
)
class C {}
''');
      try {
        final collection = AnalysisContextCollection(
          includedPaths: [file.path],
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );
        final context = collection.contextFor(file.path);
        final result = await context.currentSession.getResolvedUnit(file.path);
        if (result is! ResolvedUnitResult) {
          throw StateError('Failed to resolve');
        }
        final lib = result.unit.declaredFragment!.element;
        DartObject? nullObj;
        for (final v in lib.topLevelVariables) {
          if (v.name == 'aNull') {
            nullObj = v.computeConstantValue();
            break;
          }
        }
        expect(nullObj, isNotNull);
        expect(nullObj!.isNull, isTrue);
        expect(
          () => WidgetValueDecoder(nullObj).decode(),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              'Widget object is null',
            ),
          ),
        );
      } finally {
        if (await file.exists()) await file.delete();
      }
    });

    test('decodeEnum falls back to the declaration index', () async {
      final file = File(
        p.join(
          Directory.current.path,
          'test',
          'temp_wvd_enum_${DateTime.now().millisecondsSinceEpoch}.dart',
        ),
      );
      await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

const align = HWTextAlign.center;
''');
      try {
        final collection = AnalysisContextCollection(
          includedPaths: [file.path],
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );
        final context = collection.contextFor(file.path);
        final result = await context.currentSession.getResolvedUnit(file.path);
        if (result is! ResolvedUnitResult) {
          throw StateError('Failed to resolve');
        }
        final align = result.unit.declaredFragment!.element.topLevelVariables
            .firstWhere((v) => v.name == 'align')
            .computeConstantValue()!;

        expect(
          WidgetValueDecoder.decodeEnum(align, HWTextAlign.values),
          HWTextAlign.center,
        );
        expect(
          WidgetValueDecoder.decodeEnum(align, HWFontWeight.values),
          HWFontWeight.values[HWTextAlign.center.index],
        );
        expect(
          WidgetValueDecoder.decodeEnum(align, [HWTextAlign.start]),
          isNull,
        );
      } finally {
        if (await file.exists()) await file.delete();
      }
    });

    group('format decoders reject objects of another format type', () {
      late DartObject numberFormat;
      late DartObject dateFormat;
      late DartObject currency;
      late DartObject timeZone;

      setUpAll(() async {
        final file = File(
          p.join(
            Directory.current.path,
            'test',
            'temp_wvd_formats_${DateTime.now().millisecondsSinceEpoch}.dart',
          ),
        );
        await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

const numberFormat = HWNumberFormat.decimal();
const dateFormat = HWDateFormat.yMd;
const currency = HWCurrency.code('EUR');
const timeZone = HWTimeZone.local;
''');
        try {
          final collection = AnalysisContextCollection(
            includedPaths: [file.path],
            resourceProvider: PhysicalResourceProvider.INSTANCE,
          );
          final context = collection.contextFor(file.path);
          final result =
              await context.currentSession.getResolvedUnit(file.path);
          if (result is! ResolvedUnitResult) {
            throw StateError('Failed to resolve');
          }
          final constants = {
            for (final v
                in result.unit.declaredFragment!.element.topLevelVariables)
              v.name: v.computeConstantValue()!,
          };
          numberFormat = constants['numberFormat']!;
          dateFormat = constants['dateFormat']!;
          currency = constants['currency']!;
          timeZone = constants['timeZone']!;
        } finally {
          if (await file.exists()) await file.delete();
        }
      });

      Matcher throwsGeneratorError(String message) => throwsA(
            isA<GeneratorError>().having((e) => e.message, 'message', message),
          );

      test('decodeNumberFormat', () {
        expect(
          () => WidgetValueDecoder.decodeNumberFormat(dateFormat),
          throwsGeneratorError(
            'Unknown number format type: HWSkeletonDateFormat',
          ),
        );
      });

      test('decodeDateFormat', () {
        expect(
          () => WidgetValueDecoder.decodeDateFormat(numberFormat),
          throwsGeneratorError(
            'Unknown date format type: HWDecimalNumberFormat',
          ),
        );
      });

      test('decodeCurrency', () {
        expect(
          () => WidgetValueDecoder.decodeCurrency(timeZone),
          throwsGeneratorError('Unknown currency type: HWLocalTimeZone'),
        );
      });

      test('decodeTimeZone', () {
        expect(
          () => WidgetValueDecoder.decodeTimeZone(currency),
          throwsGeneratorError('Unknown time zone type: HWFixedCurrency'),
        );
      });
    });
  });
}
