import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _text = 'Text(text = "a", '
    'style = TextStyle(color = GlanceTheme.colors.onSurface))';

void main() {
  group('HWAlign', () {
    const inRow = HWEmitContext(enclosingLinearAxis: HWAxis.horizontal);
    const inColumn = HWEmitContext(enclosingLinearAxis: HWAxis.vertical);

    group('model', () {
      test('centers its child by default', () {
        const align = HWAlign(child: HWText.fixed('a'));
        expect(align.alignment, HWAlignment.center);
        expect(align.childWidgets, [const HWText.fixed('a')]);
      });

      test('passes the child questions on', () {
        const align = HWAlign(
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
        expect(align.dataDependencies, contains(const HWString('k')));
        expect(
          align.swiftViewModifiers.any((e) => e.contains('colorScheme')),
          isTrue,
        );
      });

      test('takes its room even around a child rendering nothing', () {
        const align = HWAlign(
          alignment: HWAlignment.bottomEnd,
          child: HWDataOnly([HWString('hidden')]),
        );
        expect(align.swiftRendersNothing, isFalse);
        expect(align.kotlinRendersNothing, isFalse);
        expect(
          align.toSwift(0, dataExpr: 'data'),
          'Color.clear\n'
          '.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .bottomTrailing)',
        );
        expect(
          align.toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.BottomEnd) {}',
        );
        expect(align.kotlinImports, {
          'import androidx.glance.GlanceModifier',
          'import androidx.glance.layout.Box',
          'import androidx.glance.layout.Alignment',
          'import androidx.glance.layout.fillMaxSize',
        });
        expect(
          const HWColumn(children: [_child, align])
              .toKotlin(0, dataExpr: 'data'),
          contains(
            '    Box(modifier = GlanceModifier.defaultWeight().fillMaxWidth(), '
            'contentAlignment = Alignment.BottomEnd) {}\n',
          ),
        );
      });

      test('places a frame larger than itself by its own alignment', () {
        expect(
          const HWAlign(alignment: HWAlignment.bottomEnd, child: _child)
              .swiftFrameAlignment,
          '.bottomTrailing',
        );
        expect(
          const HWSizedBox(
            width: 80,
            height: 40,
            child: HWAlign(
              alignment: HWAlignment.centerEnd,
              child: HWText.fixed('a'),
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('.frame(width: 80.0, height: 40.0, alignment: .trailing)'),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('fills both axes and places the child', () {
        expect(
          const HWAlign(alignment: HWAlignment.topEnd, child: _child)
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n'
          '.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .topTrailing)',
        );
      });

      test('wraps a conditional child in a Group so the frame chains', () {
        const align = HWAlign(
          alignment: HWAlignment.bottomEnd,
          child: HWBoolConditional(
            data: HWBool('flag', defaultValue: false),
            whenTrue: HWText.fixed('on'),
            whenFalse: HWText.fixed('off'),
          ),
        );
        final result = align.toSwift(0, dataExpr: 'data');
        expect(result, startsWith('Group {\n'));
        expect(result, contains('if data.flag == true {'));
        expect(
          result,
          endsWith(
            '\n}\n.frame(maxWidth: .infinity, maxHeight: .infinity, '
            'alignment: .bottomTrailing)',
          ),
        );
      });

      test('respects the indent it is emitted at', () {
        expect(
          const HWAlign(child: _child).toSwift(1, dataExpr: 'data'),
          '    Text("a")\n'
          '    .frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .center)',
        );
      });
    });

    group('Android (Glance)', () {
      test('is a Box filling both axes', () {
        expect(
          const HWAlign(alignment: HWAlignment.bottomStart, child: _child)
              .toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.BottomStart) {\n'
          '    $_text\n'
          '}',
        );
      });

      test('shares the main axis of an enclosing Column by weight', () {
        expect(
          const HWAlign(child: _child)
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          startsWith(
            'Box(modifier = GlanceModifier.defaultWeight().fillMaxWidth(), '
            'contentAlignment = Alignment.Center) {',
          ),
        );
        expect(
          const HWColumn(children: [HWAlign(child: _child), _child])
              .toKotlin(0, dataExpr: 'data'),
          contains('Box(modifier = GlanceModifier.defaultWeight()'
              '.fillMaxWidth(), contentAlignment = Alignment.Center) {'),
        );
      });

      test('shares the main axis of an enclosing Row by weight', () {
        expect(
          const HWAlign(child: _child)
              .toKotlin(0, dataExpr: 'data', context: inRow),
          startsWith(
            'Box(modifier = GlanceModifier.defaultWeight().fillMaxHeight(), '
            'contentAlignment = Alignment.Center) {',
          ),
        );
      });

      test('lays its child out itself, not the layout around it', () {
        expect(
          const HWAlign(child: HWSizedBox.expand(child: _child))
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          'Box(modifier = GlanceModifier.defaultWeight().fillMaxWidth(), '
          'contentAlignment = Alignment.Center) {\n'
          '    Text(modifier = GlanceModifier.fillMaxSize(), text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))\n'
          '}',
        );
      });

      test('emits a conditional child inside the Box', () {
        expect(
          const HWAlign(
            child: HWBoolConditional(
              data: HWBool('flag', defaultValue: false),
              whenTrue: HWText.fixed('on'),
              whenFalse: HWText.fixed('off'),
            ),
          ).toKotlin(0, dataExpr: 'data'),
          contains('    if (data.flag == true) {'),
        );
      });

      test('kotlinImports follow what is emitted', () {
        expect(
          const HWAlign(child: _child).kotlinImports,
          containsAll(<String>[
            'import androidx.glance.GlanceModifier',
            'import androidx.glance.layout.Box',
            'import androidx.glance.layout.Alignment',
            'import androidx.glance.layout.fillMaxSize',
            'import androidx.glance.text.Text',
          ]),
        );
        expect(
          const HWAlign(child: _child).kotlinImportsIn(HWAxis.horizontal),
          allOf(
            contains('import androidx.glance.layout.fillMaxHeight'),
            isNot(contains('import androidx.glance.layout.fillMaxSize')),
          ),
        );
        expect(
          const HWAlign(child: _child).kotlinImportsIn(HWAxis.vertical),
          contains('import androidx.glance.layout.fillMaxWidth'),
        );
      });
    });

    group('baseline', () {
      test('has no baseline of its own', () {
        expect(const HWAlign(child: _child).kotlinReportsBaseline, isFalse);
        expect(const HWAlign(child: _child).kotlinBaselineText(), isNull);
        expect(const HWAlign(child: _child).kotlinPaddingAddsRoom, isTrue);
      });

      test('a baseline row leaves it at the top', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              '50',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
            HWText.fixed('Points', style: HWTextStyle(fontSize: 14)),
            const HWAlign(child: _child),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect('HomeWidgetFonts.baselinePadding('.allMatches(result).length, 2);
        expect(
          result,
          contains('Box(modifier = GlanceModifier.defaultWeight()'
              '.fillMaxHeight(), contentAlignment = Alignment.Center) {'),
        );
      });

      test('takes the gap of a spaced stack on its own Box', () {
        expect(
          const HWColumn(
            spacing: 8,
            children: [_child, HWAlign(child: _child)],
          ).toKotlin(0, dataExpr: 'data'),
          contains(
            'Box(modifier = GlanceModifier.padding(top = 8.0.dp)'
            '.defaultWeight().fillMaxWidth(), '
            'contentAlignment = Alignment.Center) {',
          ),
        );
      });
    });
  });
}

const _child = HWText.fixed('a');
