import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWDecoratedBox', () {
    group('iOS (SwiftUI)', () {
      test('background color without border', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFF0000),
          ),
          child: HWText.fixed('x'),
        );

        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('Text("x")'));
        expect(result, contains('.background(Color(red:'));
        expect(result, isNot(contains('.overlay(')));
      });

      test('background and rounded border', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFFFFFF),
            border: HWBoxBorder(
              radius: 12,
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText.fixed('Decorated'),
        );

        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('RoundedRectangle(cornerRadius: 12.0)'));
        expect(result, contains('.fill(Color(red:'));
        expect(result, contains('.stroke(Color(red:'));
        expect(result, contains('lineWidth: 2.0'));
      });

      test('themed colors contribute colorScheme environment', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWThemedColor(
              light: HWFixedColor(0xFFFFFFFF),
              dark: HWFixedColor(0xFF000000),
            ),
            border: HWBoxBorder(
              thickness: 1,
              color: HWThemedColor(
                light: HWFixedColor(0xFF111111),
                dark: HWFixedColor(0xFFEEEEEE),
              ),
            ),
          ),
          child: HWText.fixed('Theme'),
        );

        expect(
          node.swiftViewModifiers,
          contains('@Environment(\\.colorScheme) var colorScheme'),
        );
      });
    });

    group('Android (Glance)', () {
      test('background color injects GlanceModifier.background', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFF0000),
          ),
          child: HWText.fixed('x'),
        );

        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('GlanceModifier.background('));
        expect(result, contains('ColorProvider'));
        expect(result, contains('Color(0xFFFF0000)'));
      });

      test('border emits nested Box with rounded background approximation', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFFFFFF),
            border: HWBoxBorder(
              radius: 12,
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText.fixed('Decorated'),
        );

        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('Box('));
        expect(result, contains('GlanceModifier.background(ColorProvider'));
        expect(result, contains('.cornerRadius(12.0.dp)'));
        expect(result, contains('.padding(2.0.dp)'));
        expect(result, contains('.cornerRadius(10.0.dp)'));
        expect(result, contains('Text(text = "Decorated")'));
      });

      test('kotlinImports include decoration dependencies', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWDefaultColor(HWColorRole.defaultBackground),
            border: HWBoxBorder(
              radius: 8,
              thickness: 1,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText.fixed('Imports'),
        );

        expect(
          node.kotlinImports,
          contains('import androidx.glance.background'),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.Box'),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.appwidget.cornerRadius'),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.padding'),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.compose.ui.unit.dp'),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.GlanceTheme'),
        );
      });
    });
  });
}
