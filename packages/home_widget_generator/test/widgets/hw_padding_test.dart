import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWPadding', () {
    const padding = HWPadding(
      child: HWText.fixed('Hi'),
      padding: HWEdgeInsets.only(left: 1, top: 2, right: 3, bottom: 4),
    );

    group('model', () {
      test('delegates the child questions to the child', () {
        const bound = HWPadding(
          padding: HWEdgeInsets.all(4),
          child: HWText(
            HWString('k'),
            style: HWTextStyle(
              color: HWThemedColor(
                light: HWFixedColor(0xFF000000),
                dark: HWFixedColor(0xFFFFFFFF),
              ),
            ),
          ),
        );
        expect(bound.dataDependencies, contains(const HWString('k')));
        expect(bound.childWidgets, hasLength(1));
        expect(
          bound.swiftViewModifiers.any((e) => e.contains('colorScheme')),
          isTrue,
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('chains .padding(EdgeInsets…) after child', () {
        final result = padding.toSwift(0, dataExpr: 'data');
        expect(result, contains('Text("Hi")'));
        expect(
          result,
          contains('.padding(EdgeInsets('),
        );
        expect(
          result,
          contains('trailing: 3.0'),
        );
      });

      test('respects indent on modifier chain', () {
        final result = padding.toSwift(1, dataExpr: 'data');
        expect(
          result,
          '    Text("Hi")\n    .padding(EdgeInsets(top: 2.0, leading: 1.0, bottom: 4.0, trailing: 3.0))',
        );
      });
    });

    group('Android (Glance)', () {
      test('kotlinImports include padding and Box', () {
        expect(
          padding.kotlinImports,
          contains('import androidx.glance.layout.padding'),
        );
        expect(
          padding.kotlinImports,
          contains('import androidx.glance.layout.Box'),
        );
        expect(
          padding.kotlinImports,
          contains('import androidx.compose.ui.unit.dp'),
        );
      });

      test('toKotlin injects GlanceModifier.padding(…dp)', () {
        final result = padding.toKotlin(0, dataExpr: 'data');
        expect(
          result,
          'Text(modifier = GlanceModifier.padding(start = 1.0.dp, top = 2.0.dp, end = 3.0.dp, bottom = 4.0.dp), text = "Hi", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
        expect(result, contains('GlanceModifier.padding'));
      });

      group('around a child painting over its padding', () {
        const pad = 'padding(start = 8.0.dp, top = 8.0.dp, '
            'end = 8.0.dp, bottom = 8.0.dp)';
        const text = 'text = "a", '
            'style = TextStyle(color = GlanceTheme.colors.onSurface))';
        const black =
            'ColorProvider(day = Color(0xFF000000), night = Color(0xFF000000))';
        const colored = HWPadding(
          padding: HWEdgeInsets.all(8),
          child: HWColoredBox(
            color: HWColor.fixed(0xFF000000),
            child: HWText.fixed('a'),
          ),
        );

        test('puts the padding on a Box of its own', () {
          expect(
            colored.toKotlin(0, dataExpr: 'data'),
            'Box(modifier = GlanceModifier.$pad) {\n'
            '    Text(modifier = GlanceModifier.background($black), $text\n'
            '}',
          );
          expect(
            colored.kotlinImports,
            containsAll([
              'import androidx.glance.GlanceModifier',
              'import androidx.glance.layout.Box',
              'import androidx.glance.layout.padding',
            ]),
          );
          expect(colored.kotlinReportsBaseline, isFalse);
          expect(colored.kotlinBaselineText(), isNull);
        });

        test('the Box takes the room the child fills', () {
          const wide = HWPadding(
            padding: HWEdgeInsets.all(8),
            child: HWColoredBox(
              color: HWColor.fixed(0xFF000000),
              child: HWSizedBox(
                width: double.infinity,
                child: HWText.fixed('a'),
              ),
            ),
          );
          expect(
            const HWColumn(children: [wide]).toKotlin(0, dataExpr: 'data'),
            contains(
              '    Box(modifier = GlanceModifier.fillMaxWidth().$pad) {\n'
              '        Text(modifier = GlanceModifier.background($black)'
              '.fillMaxWidth(), $text\n',
            ),
          );
          expect(
            const HWRow(children: [wide]).toKotlin(0, dataExpr: 'data'),
            contains('    Box(modifier = GlanceModifier.defaultWeight().$pad)'),
          );
          expect(
            wide.kotlinImportsIn(HWAxis.vertical),
            contains('import androidx.glance.layout.fillMaxWidth'),
          );
        });

        test('a decoration around the padding still covers it', () {
          expect(
            const HWColoredBox(
              color: HWColor.fixed(0xFF000000),
              child: HWPadding(
                padding: HWEdgeInsets.all(8),
                child: HWText.fixed('a'),
              ),
            ).toKotlin(0, dataExpr: 'data'),
            'Text(modifier = GlanceModifier.background($black).$pad, $text',
          );
        });

        test('a child padding adds room to is still injected', () {
          expect(
            const HWPadding(
              padding: HWEdgeInsets.all(8),
              child: HWDecoratedBox(
                decoration: HWBoxDecoration(
                  borderRadius: HWBorderRadius.circular(8),
                ),
                child: HWText.fixed('a'),
              ),
            ).toKotlin(0, dataExpr: 'data'),
            'Text(modifier = GlanceModifier.$pad, $text',
          );
        });
      });

      test('a child rendering nothing leaves nothing to inset', () {
        const empty = HWPadding(
          padding: HWEdgeInsets.all(4),
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(empty.kotlinRendersNothing, isTrue);
        expect(empty.toKotlin(0, dataExpr: 'data'), isEmpty);
        expect(empty.kotlinImports, isEmpty);
      });
    });
  });
}
