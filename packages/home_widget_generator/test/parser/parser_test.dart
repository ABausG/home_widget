import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';
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
      expect(out, contains('HStack(alignment: .bottom)'));
      expect(out, contains('Spacer()'));
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

    test('parses HWFill', () async {
      final code = '''
@HomeWidget(
  name: 'TestWidget',
  widget: HWFill(
    child: HWText.fixed('fill'),
  ),
)
class TestWidget {}
''';
      final widget = await parseCode(code);
      expect(widget, isA<HWFill>());
      expect(((widget as HWFill).child as HWText).fixedContent, 'fill');
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
  });
}
