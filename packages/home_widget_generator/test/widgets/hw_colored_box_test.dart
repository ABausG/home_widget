import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWColoredBox', () {
    group('iOS (SwiftUI)', () {
      test('HWFixedColor: background on Text', () {
        final node = HWColoredBox(
          color: HWFixedColor(0xFFFF0000),
          child: HWText(HWString.fixed('x')),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('Text(verbatim: "x")'));
        expect(result, contains('.background('));
        expect(result, contains('Color(red:'));
      });

      test('HWAppearanceData: picks a side by the environment', () {
        final node = HWColoredBox(
          color: HWAppearanceData(
            light: HWFixedColor(0xFF0000FF),
            dark: HWFixedColor(0xFFFF00FF),
          ),
          child: HWText(HWString.fixed('y')),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.background((hwAppearance(hwEnvironment, '));
        expect(result, contains(' ?? Color.clear)'));
        expect(
          node.swiftViewModifiers,
          contains('@Environment(\\.self) var hwEnvironment'),
        );
      });

      test('a stored color is a data field painting nothing without a value',
          () {
        const node = HWColoredBox(
          color: HWColor('swatch'),
          child: HWText(HWString.fixed('y')),
        );
        expect(node.dataDependencies, contains(const HWColor('swatch')));
        expect(node.nativeHelpers, contains(HWNativeHelper.hwColor));
        expect(
          node.toSwift(0, dataExpr: 'data'),
          contains('.background((hwColor(data.swatch) ?? Color.clear))'),
        );
      });

      test('a child rendering nothing leaves nothing to paint', () {
        const node = HWColoredBox(
          color: HWFixedColor(0xFF00FF00),
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.swiftRendersNothing, isTrue);
        expect(node.toSwift(0, dataExpr: 'data'), isEmpty);
        expect(
          const HWColumn(children: [node, HWText(HWString.fixed('x'))])
              .toSwift(0, dataExpr: 'data'),
          isNot(contains('.background(')),
        );
      });

      test('HWDefaultColor: semantic Color.secondary', () {
        final node = HWColoredBox(
          color: HWDefaultColor(HWColorRole.contentSecondary),
          child: HWText(HWString.fixed('z')),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.background(Color.secondary'));
      });
    });

    group('Android (Glance)', () {
      test('kotlinImports include background and Box', () {
        final node = HWColoredBox(
          color: HWFixedColor(0xFF000000),
          child: HWText(HWString.fixed('a')),
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
          child: HWText(HWString.fixed('x')),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('background('));
        expect(result, contains('ColorProvider'));
        expect(result, contains('Color(0xFFFF0000)'));
      });

      test('HWAppearanceData of two fixed colors stays one ColorProvider', () {
        final node = HWColoredBox(
          color: HWAppearanceData(
            light: HWFixedColor(0xFF111111),
            dark: HWFixedColor(0xFFEEEEEE),
          ),
          child: HWText(HWString.fixed('t')),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(
          result,
          contains(
            'background(ColorProvider(day = Color(0xFF111111), '
            'night = Color(0xFFEEEEEE)))',
          ),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.color.ColorProvider'),
        );
      });

      test('a stored color falls back to transparent', () {
        const node = HWColoredBox(
          color: HWColor('swatch'),
          child: HWText(HWString.fixed('t')),
        );
        expect(
          node.toKotlin(0, dataExpr: 'widgetData'),
          contains(
            'background((hwColor(widgetData.swatch) ?: ColorProvider(day = '
            'Color.Transparent, night = Color.Transparent)))',
          ),
        );
      });

      test('a child rendering nothing leaves nothing to paint', () {
        const node = HWColoredBox(
          color: HWFixedColor(0xFF00FF00),
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.kotlinRendersNothing, isTrue);
        expect(node.toKotlin(0, dataExpr: 'data'), isEmpty);
        expect(node.kotlinImports, isEmpty);
        expect(node.kotlinImportsIn(HWAxis.vertical), isEmpty);
      });

      test('a stack skips it exactly as the root does', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            HWColoredBox(
              color: HWFixedColor(0xFF00FF00),
              child: HWDataOnly([HWString('hidden')]),
            ),
            HWText(HWString.fixed('x')),
          ],
        );

        final kotlin = column.toKotlin(0, dataExpr: 'data');
        expect(kotlin, isNot(contains('Box')));
        expect(kotlin, isNot(contains('background')));
        expect(
          column.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
        );
      });

      test('HWDefaultColor: GlanceTheme in output', () {
        final node = HWColoredBox(
          color: HWDefaultColor(HWColorRole.contentPrimary),
          child: HWText(HWString.fixed('d')),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('GlanceTheme.colors.onSurface'));
      });
    });
  });
}
