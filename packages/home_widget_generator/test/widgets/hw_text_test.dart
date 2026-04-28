import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWText', () {
    group('model', () {
      test('fixed constructor is const', () {
        const text = HWText.fixed('Hello');
        expect(text, isA<HWText>());
        expect(text, isA<HWWidget>());
      });

      test('data type constructor is const', () {
        const text = HWText(HWString('key'));
        expect(text, isA<HWText>());
        expect(text, isA<HWWidget>());
      });
    });

    group('iOS (SwiftUI)', () {
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

      test('swiftViewModifiers: empty without style', () {
        expect(HWText.fixed('x').swiftViewModifiers, isEmpty);
      });

      test(
          'swiftViewModifiers: empty for role text (font chain is in toSwift only)',
          () {
        final node = HWText.fixed('a', style: HWRoleTextStyle.headline());
        expect(node.swiftViewModifiers, isEmpty);
      });

      test(
        'swiftViewModifiers: include colorScheme when color is HWThemedColor',
        () {
          final node = HWText.fixed(
            'Hi',
            style: const HWTextStyle(
              color: HWThemedColor(
                light: HWFixedColor(0xFF000000),
                dark: HWFixedColor(0xFFFFFFFF),
              ),
            ),
          );
          expect(
            node.swiftViewModifiers,
            contains('@Environment(\\.colorScheme) var colorScheme'),
          );
        },
      );

      test('with style, Text uses view modifiers in output', () {
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
        expect(result, contains('Text("Styled")'));
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

      test('textAlign justify maps to leading in Swift (LTR fallback)', () {
        const node = HWText.fixed('J', textAlign: HWTextAlign.justify);
        final r = node.toSwift(0, dataExpr: 'd');
        expect(r, contains('.multilineTextAlignment(.leading)'));
      });

      test('strikethrough in Swift from lineThrough', () {
        final node = HWText.fixed(
          'S',
          style: const HWTextStyle(lineThrough: true),
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('.strikethrough(true)'));
      });

      test('HWRoleTextStyle adds fontWeight when set with role', () {
        final node = HWText.fixed(
          'R',
          style: HWRoleTextStyle.headline(
            fontWeight: HWFontWeight.w700,
          ),
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('.font(.headline)'));
        expect(r, contains('.fontWeight(.bold)'));
      });

      test('only fontWeight without size or role in Swift', () {
        const node = HWText.fixed(
          'W',
          style: HWTextStyle(fontWeight: HWFontWeight.w500),
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('.fontWeight(.medium)'));
        expect(r, isNot(contains('.font(')));
      });

      test('HWRoleTextStyle body, callout, caption, captionSmall in Swift', () {
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.body())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.body)'),
        );
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.callout())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.callout)'),
        );
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.caption())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.caption)'),
        );
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.captionSmall())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.caption2)'),
        );
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

    group('Android (Glance)', () {
      test('HWTextStyle kotlinImports add sp, FontWeight, or TextDecoration',
          () {
        expect(
          const HWTextStyle(fontSize: 12).kotlinImports,
          contains('import androidx.compose.ui.unit.sp'),
        );
        expect(
          const HWTextStyle(fontWeight: HWFontWeight.w500).kotlinImports,
          contains('import androidx.glance.text.FontWeight'),
        );
        expect(
          const HWTextStyle(underline: true).kotlinImports,
          contains('import androidx.glance.text.TextDecoration'),
        );
      });

      test('kotlinImports include TextAlign when textAlign is set', () {
        final w = HWText.fixed('x', textAlign: HWTextAlign.end);
        expect(
          w.kotlinImports,
          contains('import androidx.glance.text.TextAlign'),
        );
      });

      test(
          'textAlign only, no style: style is TextStyle with only align in Kotlin',
          () {
        const node = HWText.fixed('Hi', textAlign: HWTextAlign.end);
        final r = node.toKotlin(0, dataExpr: 'd');
        expect(
          r,
          contains(
            'Text(text = "Hi", style = TextStyle(textAlign = TextAlign.End))',
          ),
        );
      });

      test('textAlign justify uses Start in Kotlin (fallback)', () {
        const node = HWText.fixed('J', textAlign: HWTextAlign.justify);
        final r = node.toKotlin(0, dataExpr: 'd');
        expect(
          r,
          contains('TextStyle(textAlign = TextAlign.Start)'),
        );
      });

      test('kotlinImports include Text', () {
        final w = HWText.fixed('x');
        expect(w.kotlinImports, contains('import androidx.glance.text.Text'));
        expect(
          w.kotlinImports,
          contains('import androidx.glance.text.TextStyle'),
        );
      });

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

      test('style and textAlign in Glance output', () {
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
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('fontSize = 24.sp'));
        expect(result, contains('fontWeight = FontWeight.Bold'));
        expect(result, contains('fontStyle = FontStyle.Italic'));
        expect(result, contains('textDecoration = TextDecoration.Underline'));
        expect(result, contains('textAlign = TextAlign.Center'));
      });

      test('strikethrough in Kotlin from lineThrough only', () {
        const node = HWText.fixed(
          'S',
          style: HWTextStyle(lineThrough: true),
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('textDecoration = TextDecoration.LineThrough'),
        );
      });

      test('combines Underline and LineThrough in Kotlin', () {
        const node = HWText.fixed(
          'B',
          style: HWTextStyle(
            underline: true,
            lineThrough: true,
            color: HWFixedColor(0xFF0000FF),
          ),
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          allOf(
            contains('TextDecoration.combine'),
            contains('TextDecoration.Underline'),
            contains('TextDecoration.LineThrough'),
          ),
        );
      });

      test('HWRoleTextStyle body, callout, caption, captionSmall in Glance',
          () {
        for (final entry in <(int, HWRoleTextStyle)>[
          (16, HWRoleTextStyle.body()),
          (14, HWRoleTextStyle.callout()),
          (12, HWRoleTextStyle.caption()),
          (11, HWRoleTextStyle.captionSmall()),
        ]) {
          final r =
              HWText.fixed('X', style: entry.$2).toKotlin(0, dataExpr: 'data');
          expect(
            r,
            contains('fontSize = ${entry.$1}.sp'),
            reason: 'fontSize ${entry.$1}',
          );
        }
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
  });
}
