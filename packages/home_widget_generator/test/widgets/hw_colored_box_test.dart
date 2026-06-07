import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWColoredBox', () {
    group('iOS (SwiftUI)', () {
      test('HWFixedColor: background on Text', () {
        final node = HWColoredBox(
          color: HWFixedColor(0xFFFF0000),
          child: HWText.fixed('x'),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('Text("x")'));
        expect(result, contains('.background('));
        expect(result, contains('Color(red:'));
      });

      test('HWThemedColor: swiftViewModifiers for colorScheme', () {
        final node = HWColoredBox(
          color: HWThemedColor(
            light: HWFixedColor(0xFF0000FF),
            dark: HWFixedColor(0xFFFF00FF),
          ),
          child: HWText.fixed('y'),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('colorScheme == .dark'));
        expect(
          node.swiftViewModifiers,
          contains('@Environment(\\.colorScheme) var colorScheme'),
        );
      });

      test('HWDefaultColor: semantic Color.secondary', () {
        final node = HWColoredBox(
          color: HWDefaultColor(HWColorRole.contentSecondary),
          child: HWText.fixed('z'),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.background(Color.secondary'));
      });
    });

    group('Android (Glance)', () {
      test('kotlinImports include background and Box', () {
        final node = HWColoredBox(
          color: HWFixedColor(0xFF000000),
          child: HWText.fixed('a'),
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
          contains('import androidx.compose.ui.graphics.Color'),
        );
      });

      test('HWFixedColor: background(…) with ColorProvider in output', () {
        final node = HWColoredBox(
          color: HWFixedColor(0xFFFF0000),
          child: HWText.fixed('x'),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('background('));
        expect(result, contains('ColorProvider'));
        expect(result, contains('Color(0xFFFF0000)'));
      });

      test('HWThemedColor: kotlinImports include ColorProvider', () {
        final node = HWColoredBox(
          color: HWThemedColor(
            light: HWFixedColor(0xFF111111),
            dark: HWFixedColor(0xFFEEEEEE),
          ),
          child: HWText.fixed('t'),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('ColorProvider'));
        expect(
          node.kotlinImports,
          contains('import androidx.glance.color.ColorProvider'),
        );
      });

      test('HWDefaultColor: GlanceTheme in output', () {
        final node = HWColoredBox(
          color: HWDefaultColor(HWColorRole.contentPrimary),
          child: HWText.fixed('d'),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('GlanceTheme.colors.onSurface'));
      });
    });
  });
}
