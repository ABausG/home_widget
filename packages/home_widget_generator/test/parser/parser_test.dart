import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
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

      final file = File(p.join(Directory.current.path, 'test',
          'temp_${DateTime.now().millisecondsSinceEpoch}.dart'));
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
        final annotation = element.metadata2.annotations.firstWhere(
            (m) => m.element2?.enclosingElement2?.name3 == 'HomeWidget');

        return WidgetTreeParser(annotation).parse();
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
      expect((column.children[0] as HWText).toSwift(0, dataExpr: ''),
          contains('Hello'));
      expect(column.mainAxisAlignment, HWMainAxisAlignment.center);
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
  });
}
