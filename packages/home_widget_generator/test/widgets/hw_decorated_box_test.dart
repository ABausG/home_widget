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
          child: HWText(HWString.fixed('x')),
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
            borderRadius: HWBorderRadius.circular(12),
            border: HWBoxBorder(
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText(HWString.fixed('Decorated')),
        );

        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('RoundedRectangle(cornerRadius: 12.0)'));
        expect(result, contains('.fill(Color(red:'));
        expect(result, contains('.strokeBorder(Color(red:'));
        expect(result, isNot(contains('.stroke(')));
        expect(result, contains('lineWidth: 2.0'));
      });

      test('a border around a child rendering nothing renders nothing', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFFFFFF),
            borderRadius: HWBorderRadius.circular(12),
            border: HWBoxBorder(
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.swiftRendersNothing, isTrue);
        expect(node.toSwift(0, dataExpr: 'data'), isEmpty);
        expect(
          const HWColumn(children: [node, HWText(HWString.fixed('x'))])
              .toSwift(0, dataExpr: 'data'),
          isNot(contains('.overlay(')),
        );
      });

      group('borderRadius', () {
        const blue = 'Color(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0)';
        const black = 'Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)';

        test('rounds a background without a border', () {
          expect(
            const HWDecoratedBox(
              decoration: HWBoxDecoration(
                color: HWFixedColor(0xFF0000FF),
                borderRadius: HWBorderRadius.circular(16),
              ),
              child: HWText(HWString.fixed('x')),
            ).toSwift(0, dataExpr: 'data'),
            'Text("x")\n'
            '.background(RoundedRectangle(cornerRadius: 16.0).fill($blue))',
          );
        });

        test('rounds a border without a background', () {
          expect(
            const HWDecoratedBox(
              decoration: HWBoxDecoration(
                borderRadius: HWBorderRadius.circular(16),
                border: HWBoxBorder(
                  thickness: 1,
                  color: HWFixedColor(0xFF000000),
                ),
              ),
              child: HWText(HWString.fixed('x')),
            ).toSwift(0, dataExpr: 'data'),
            'Text("x")\n'
            '.overlay(RoundedRectangle(cornerRadius: 16.0)'
            '.strokeBorder($black, lineWidth: 1.0))',
          );
        });

        test('square corners stay a plain background', () {
          expect(
            const HWDecoratedBox(
              decoration: HWBoxDecoration(
                color: HWFixedColor(0xFF0000FF),
                borderRadius: HWBorderRadius.circular(0),
              ),
              child: HWText(HWString.fixed('x')),
            ).toSwift(0, dataExpr: 'data'),
            'Text("x")\n.background($blue)',
          );
        });

        test('paints nothing on its own and never clips the child', () {
          const node = HWDecoratedBox(
            decoration: HWBoxDecoration(
              borderRadius: HWBorderRadius.circular(16),
            ),
            child: HWText(HWString.fixed('x')),
          );
          expect(node.toSwift(0, dataExpr: 'data'), 'Text("x")');
          expect(
            const HWDecoratedBox(
              decoration: HWBoxDecoration(
                color: HWFixedColor(0xFF0000FF),
                borderRadius: HWBorderRadius.circular(16),
              ),
              child: HWText(HWString.fixed('x')),
            ).toSwift(0, dataExpr: 'data'),
            isNot(contains('clip')),
          );
        });
      });

      test('a sized box inside is framed before the decoration', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFFFFFF),
            borderRadius: HWBorderRadius.circular(12),
            border: HWBoxBorder(
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWSizedBox(
            width: double.infinity,
            child: HWText(HWString.fixed('x')),
          ),
        );

        final result =
            const HWRow(children: [node, HWText(HWString.fixed('y'))])
                .toSwift(0, dataExpr: 'data');
        expect(
          result,
          contains('    Text("x")\n'
              '    .frame(maxWidth: .infinity, alignment: .topLeading)\n'
              '    .background(RoundedRectangle(cornerRadius: 12.0)'),
        );
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
          child: HWText(HWString.fixed('Theme')),
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
          child: HWText(HWString.fixed('x')),
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
            borderRadius: HWBorderRadius.circular(12),
            border: HWBoxBorder(
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText(HWString.fixed('Decorated')),
        );

        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('Box('));
        expect(result, contains('GlanceModifier.background(ColorProvider'));
        expect(result, contains('.cornerRadius(12.0.dp)'));
        expect(result, contains('.padding(2.0.dp)'));
        expect(result, contains('.cornerRadius(10.0.dp)'));
        expect(result, contains('Text(text = "Decorated",'));
      });

      test('border without a fill emits a single Box', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            borderRadius: HWBorderRadius.circular(12),
            border: HWBoxBorder(
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText(HWString.fixed('Decorated')),
        );

        final result = node.toKotlin(0, dataExpr: 'data');
        // With no fill there is nothing to nest, so the inset Box is skipped.
        expect('Box('.allMatches(result), hasLength(1));
        expect(result, startsWith('Box('));
        expect(result, contains('GlanceModifier.background(ColorProvider'));
        expect(result, contains('.cornerRadius(12.0.dp)'));
        expect(result, contains('.padding(2.0.dp)'));
        expect(result, isNot(contains('.cornerRadius(10.0.dp)')));
        expect(result, contains('Text(text = "Decorated",'));
      });

      group('borderRadius', () {
        const text = 'text = "x", '
            'style = TextStyle(color = GlanceTheme.colors.onSurface))';
        const blue =
            'ColorProvider(day = Color(0xFF0000FF), night = Color(0xFF0000FF))';

        test('rounds a background on the child without a Box', () {
          const node = HWDecoratedBox(
            decoration: HWBoxDecoration(
              color: HWFixedColor(0xFF0000FF),
              borderRadius: HWBorderRadius.circular(16),
            ),
            child: HWText(HWString.fixed('x')),
          );
          expect(
            node.toKotlin(0, dataExpr: 'data'),
            'Text(modifier = GlanceModifier.background($blue)'
            '.cornerRadius(16.0.dp), $text',
          );
          expect(
            node.kotlinImports,
            containsAll([
              'import androidx.glance.appwidget.cornerRadius',
              'import androidx.compose.ui.unit.dp',
            ]),
          );
          expect(
            node.kotlinImports,
            isNot(contains('import androidx.glance.layout.padding')),
          );
        });

        test('square corners and no color need no cornerRadius', () {
          const square = HWDecoratedBox(
            decoration: HWBoxDecoration(color: HWFixedColor(0xFF0000FF)),
            child: HWText(HWString.fixed('x')),
          );
          expect(
            square.toKotlin(0, dataExpr: 'data'),
            isNot(contains('corner')),
          );
          expect(
            square.kotlinImports,
            isNot(contains('import androidx.glance.appwidget.cornerRadius')),
          );

          const uncolored = HWDecoratedBox(
            decoration: HWBoxDecoration(
              borderRadius: HWBorderRadius.circular(16),
            ),
            child: HWText(HWString.fixed('x')),
          );
          expect(
            uncolored.toKotlin(0, dataExpr: 'data'),
            'Text($text',
          );
          expect(
            uncolored.kotlinImports,
            isNot(contains('import androidx.glance.appwidget.cornerRadius')),
          );
        });

        test('insets the fill radius by the border, never below zero', () {
          final result = const HWDecoratedBox(
            decoration: HWBoxDecoration(
              color: HWFixedColor(0xFF0000FF),
              borderRadius: HWBorderRadius.circular(1),
              border: HWBoxBorder(
                thickness: 2,
                color: HWFixedColor(0xFF000000),
              ),
            ),
            child: HWText(HWString.fixed('x')),
          ).toKotlin(0, dataExpr: 'data');
          expect(result, contains('.cornerRadius(1.0.dp).padding(2.0.dp)'));
          expect(
            result,
            contains('GlanceModifier.background($blue).cornerRadius(0.0.dp)'),
          );
        });
      });

      group('a border takes the room its child asks for', () {
        const decoration = HWBoxDecoration(
          color: HWFixedColor(0xFFFFFFFF),
          borderRadius: HWBorderRadius.circular(12),
          border: HWBoxBorder(
            thickness: 2,
            color: HWFixedColor(0xFF000000),
          ),
        );
        const tall = HWDecoratedBox(
          decoration: decoration,
          child: HWSizedBox(
            height: double.infinity,
            child: HWText(HWString.fixed('x')),
          ),
        );

        test('as a weight along a column', () {
          final room = tall.kotlinRoomIn(HWAxis.vertical);
          expect(room.weight, isTrue);
          expect(room.fillsHeight, isFalse);

          final result =
              const HWColumn(children: [tall, HWText(HWString.fixed('y'))])
                  .toKotlin(0, dataExpr: 'data');
          expect(
            result,
            contains('    Box(\n'
                '        modifier = GlanceModifier.defaultWeight()'
                '.background('),
          );
          expect(
            result,
            contains('            modifier = GlanceModifier.fillMaxHeight()'
                '.background('),
          );
          expect(
            result,
            contains('Text(modifier = GlanceModifier.fillMaxHeight(), '),
          );
        });

        test('as a fill across a row and at the top level', () {
          final room = tall.kotlinRoomIn(HWAxis.horizontal);
          expect(room.weight, isFalse);
          expect(room.fillsHeight, isTrue);
          expect(tall.kotlinRoomIn(null).fillsHeight, isTrue);

          expect(
            tall.toKotlin(0, dataExpr: 'data'),
            startsWith('Box(\n    modifier = GlanceModifier.fillMaxHeight()'
                '.background('),
          );
          expect(
            tall.kotlinImports,
            contains('import androidx.glance.layout.fillMaxHeight'),
          );
        });

        test('through a colored box around it', () {
          const colored = HWColoredBox(
            color: HWFixedColor(0xFF00FF00),
            child: tall,
          );
          expect(colored.kotlinRoomIn(HWAxis.vertical).weight, isTrue);
          expect(
            const HWColumn(children: [colored]).toKotlin(0, dataExpr: 'data'),
            contains('modifier = GlanceModifier.background(ColorProvider('
                'day = Color(0xFF00FF00), night = Color(0xFF00FF00)))'
                '.defaultWeight().background('),
          );
        });

        test('and none while the child hugs its content', () {
          const hugging = HWDecoratedBox(
            decoration: decoration,
            child: HWText(HWString.fixed('x')),
          );
          expect(hugging.kotlinRoomIn(HWAxis.vertical).modifiers, isEmpty);
          expect(
            hugging.toKotlin(0, dataExpr: 'data'),
            contains('modifier = GlanceModifier.background(ColorProvider('
                'day = Color(0xFFFFFFFF), night = Color(0xFFFFFFFF)))'
                '.cornerRadius(10.0.dp)'),
          );
        });
      });

      test('a border around a child rendering nothing renders nothing', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWFixedColor(0xFFFFFFFF),
            borderRadius: HWBorderRadius.circular(12),
            border: HWBoxBorder(
              thickness: 2,
              color: HWFixedColor(0xFF000000),
            ),
          ),
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
            HWDecoratedBox(
              decoration: HWBoxDecoration(
                border: HWBoxBorder(
                  thickness: 2,
                  color: HWFixedColor(0xFF000000),
                ),
              ),
              child: HWDataOnly([HWString('hidden')]),
            ),
            HWText(HWString.fixed('x')),
          ],
        );

        final kotlin = column.toKotlin(0, dataExpr: 'data');
        expect(kotlin, isNot(contains('Box')));
        expect(kotlin, isNot(contains('padding')));
        expect(
          column.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
        );
      });

      test('kotlinImports include decoration dependencies', () {
        const node = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWDefaultColor(HWColorRole.defaultBackground),
            borderRadius: HWBorderRadius.circular(8),
            border: HWBoxBorder(
              thickness: 1,
              color: HWFixedColor(0xFF000000),
            ),
          ),
          child: HWText(HWString.fixed('Imports')),
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
