import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidget.toKotlin', () {
    test('emits fixed text', () {
      final node = HWText.fixed('Hello');
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, 'Text(text = "Hello")');
    });

    test('emits string data ref', () {
      final node = HWText(HWString('label'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = data.label ?: "")');
    });

    test('emits int data ref', () {
      final node = HWText(HWInt('count'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = (data.count?.toString() ?: "0"))');
    });

    test('emits bool data ref', () {
      final node = HWText(HWBool('flag'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = (data.flag?.toString() ?: "false"))');
    });

    test('emits double data ref', () {
      final node = HWText(HWDouble('ratio'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = (data.ratio?.toString() ?: "0.0"))');
    });

    test('escapes strings', () {
      final node = HWText.fixed('Price: \$5');
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, 'Text(text = "Price: \\\$5")');
    });

    test('respects indent', () {
      final node = HWText.fixed('Hello');
      final result = node.toKotlin(1, dataExpr: 'data');
      expect(result, '    Text(text = "Hello")');
    });

    test('HWText emits style and alignment', () {
      final node = HWText.fixed(
        'Styled',
        style: HWTextStyle(
            fontSize: 24,
            fontWeight: HWFontWeight.bold,
            italic: true,
            underline: true,
            color: HWFixedColor(0xFFFF0000)),
        textAlign: HWTextAlign.center,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('fontSize = 24.sp'));
      expect(result, contains('fontWeight = FontWeight.Bold'));
      expect(result, contains('fontStyle = FontStyle.Italic'));
      expect(result, contains('textDecoration = TextDecoration.Underline'));
      expect(result, contains('textAlign = TextAlign.Center'));
    });

    test('HWRoleTextStyle emits default metrics when unprovided', () {
      final node = HWText.fixed('Role', style: HWRoleTextStyle.headline());
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('fontSize = 18.sp'));
      expect(result, contains('fontWeight = FontWeight.Medium'));
    });

    test('HWTextStyle baseStyle resolution', () {
      final node = HWText.fixed(
        'Base Base',
        style: HWTextStyle(
          color: HWFixedColor(0xFF00FF00),
          baseStyle: HWRoleTextStyle.title(
            italic: true,
          ),
        ),
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('fontSize = 22.sp'));
      expect(result, contains('fontStyle = FontStyle.Italic'));
      expect(result, contains('0xFF00FF00'));
    });
  });

  group('HWWidget.toSwift', () {
    test('emits fixed text', () {
      final node = HWText.fixed('Hello');
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, 'Text("Hello")');
    });

    test('emits string data ref', () {
      final node = HWText(HWString('label'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.label ?? "")');
    });

    test('emits int data ref', () {
      final node = HWText(HWInt('count'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.count != nil ? "\\(data.count!)" : "0")');
    });

    test('emits bool data ref', () {
      final node = HWText(HWBool('flag'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.flag != nil ? "\\(data.flag!)" : "false")');
    });

    test('emits double data ref', () {
      final node = HWText(HWDouble('ratio'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.ratio != nil ? "\\(data.ratio!)" : "0.0")');
    });

    test('escapes strings', () {
      final node = HWText.fixed('He said "Hi"');
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, 'Text("He said \\"Hi\\"")');
    });

    test('respects indent', () {
      final node = HWText.fixed('Hello');
      final result = node.toSwift(1, dataExpr: 'data');
      expect(result, '    Text("Hello")');
    });

    test('HWText emits style and alignment', () {
      final node = HWText.fixed(
        'Styled',
        style: HWTextStyle(
          fontSize: 24,
          fontWeight: HWFontWeight.bold,
          italic: true,
          underline: true,
          color: HWFixedColor(0xFFFF0000),
        ),
        textAlign: HWTextAlign.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.system(size: 24.0, weight: .bold))'));
      expect(
        result,
        contains(
          '.foregroundColor(Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))',
        ),
      );
      expect(result, contains('.italic()'));
      expect(result, contains('.underline(true)'));
      expect(result, contains('.multilineTextAlignment(.center)'));
    });

    test('HWRoleTextStyle emits semantic font', () {
      final node = HWText.fixed('Role', style: HWRoleTextStyle.headline());
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.headline)'));
    });

    test('HWRoleTextStyle overridden by explicit size', () {
      final node = HWText.fixed(
        'Role Override',
        style: HWRoleTextStyle.headline(fontSize: 30),
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.system(size: 30.0))'));
    });

    test('HWTextStyle baseStyle resolution', () {
      final node = HWText.fixed(
        'Base Base',
        style: HWTextStyle(
          color: HWFixedColor(0xFF00FF00),
          baseStyle: HWRoleTextStyle.title(
            italic: true,
          ),
        ),
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.title)'));
      expect(result, contains('.italic()'));
      expect(result, contains('green: 1.0'));
    });
  });
}
