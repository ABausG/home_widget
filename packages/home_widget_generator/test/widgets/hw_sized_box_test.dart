import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _materialIcons = HWIconFont(family: 'MaterialIcons');

void main() {
  group('HWSizedBox', () {
    const inRow = HWEmitContext(enclosingLinearAxis: HWAxis.horizontal);
    const inColumn = HWEmitContext(enclosingLinearAxis: HWAxis.vertical);

    group('model', () {
      test('constructors set the dimensions they name', () {
        const box = HWSizedBox(width: 8, height: 12);
        expect(box.width, 8.0);
        expect(box.height, 12.0);
        expect(box.child, isNull);

        const shrink = HWSizedBox.shrink();
        expect(shrink.width, 0.0);
        expect(shrink.height, 0.0);

        const expand = HWSizedBox.expand();
        expect(expand.width, double.infinity);
        expect(expand.height, double.infinity);
      });

      test('delegates the child questions to the child', () {
        const box = HWSizedBox.expand(
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
        expect(box.dataDependencies, contains(const HWString('k')));
        expect(box.childWidgets, hasLength(1));
        expect(
          box.swiftViewModifiers.any((e) => e.contains('colorScheme')),
          isTrue,
        );
        expect(
          box.kotlinImports.any(
            (s) => s.contains('ColorProvider') || s.contains('glance.color'),
          ),
          isTrue,
        );
      });

      test('a box without a child contributes nothing of its own', () {
        const box = HWSizedBox(width: 8);
        expect(box.childWidgets, isEmpty);
        expect(box.dataDependencies, isEmpty);
        expect(box.swiftViewModifiers, isEmpty);
        expect(box.descendants, hasLength(1));
        expect(box.fontVariants, isEmpty);
        expect(box.iconCodePoints, isEmpty);
        expect(box.nativeHelpers, isEmpty);
      });
    });

    group('iOS (SwiftUI)', () {
      test('a fixed width frames only that axis', () {
        expect(
          const HWSizedBox(width: 80, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(width: 80.0, alignment: .topLeading)',
        );
      });

      test('a fixed height frames only that axis', () {
        expect(
          const HWSizedBox(height: 40, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(height: 40.0, alignment: .topLeading)',
        );
      });

      test('both axes end up in one frame', () {
        expect(
          const HWSizedBox(width: 80, height: 40.5, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(width: 80.0, height: 40.5, '
          'alignment: .topLeading)',
        );
      });

      test('an infinite axis becomes a max frame', () {
        expect(
          const HWSizedBox(width: double.infinity, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(maxWidth: .infinity, alignment: .topLeading)',
        );
        expect(
          const HWSizedBox(height: double.infinity, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(maxHeight: .infinity, alignment: .topLeading)',
        );
      });

      test('expand asks for both axes in one frame', () {
        expect(
          const HWSizedBox.expand(child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .topLeading)',
        );
      });

      test('a mixed box chains the two frame overloads', () {
        expect(
          const HWSizedBox(
            width: 80,
            height: double.infinity,
            child: HWText.fixed('a'),
          ).toSwift(0, dataExpr: 'data'),
          'Text("a")\n'
          '.frame(width: 80.0, alignment: .topLeading)\n'
          '.frame(maxHeight: .infinity, alignment: .topLeading)',
        );
      });

      test('shrink frames the child to nothing and cuts it off', () {
        expect(
          const HWSizedBox.shrink(child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(width: 0.0, height: 0.0, alignment: .topLeading)'
          '\n.clipped()',
        );
        expect(
          const HWSizedBox(width: 0, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")\n.frame(width: 0.0, alignment: .topLeading)\n.clipped()',
        );
      });

      test('the frame places the child where its own alignment would', () {
        expect(
          const HWSizedBox.expand(
            child: HWColumn(
              children: [HWText.fixed('a')],
              crossAxisAlignment: HWCrossAxisAlignment.center,
              mainAxisAlignment: HWMainAxisAlignment.center,
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith(
            '.frame(maxWidth: .infinity, maxHeight: .infinity, '
            'alignment: .top)',
          ),
        );
        expect(
          const HWSizedBox.expand(
            child: HWColumn(
              children: [HWText.fixed('a')],
              crossAxisAlignment: HWCrossAxisAlignment.end,
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('alignment: .topTrailing)'),
        );
        expect(
          const HWSizedBox.expand(
            child: HWRow(
              children: [HWText.fixed('a')],
              crossAxisAlignment: HWCrossAxisAlignment.center,
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('alignment: .leading)'),
        );
      });

      test('a picture is centered in a box larger than it is', () {
        expect(
          const HWSizedBox(
            width: 80,
            height: 40,
            child: HWImage(HWImageData('avatar')),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('.frame(width: 80.0, height: 40.0, alignment: .center)'),
        );
        expect(
          const HWSizedBox(
            width: 80,
            height: 40,
            child: HWIcon.glyph(0xE88A, font: _materialIcons),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('.frame(width: 80.0, height: 40.0, alignment: .center)'),
        );
      });

      test('a wrapper around the child passes its alignment on', () {
        expect(
          const HWSizedBox.expand(
            child: HWPadding(
              padding: HWEdgeInsets.all(4),
              child: HWColumn(children: [HWText.fixed('a')]),
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('alignment: .top)'),
        );
      });

      test('branches that disagree leave the child at the top start', () {
        expect(
          const HWSizedBox.expand(
            child: HWDataExists(
              data: HWBool('flag'),
              whenPresent: HWColumn(children: [HWText.fixed('on')]),
              whenAbsent: HWText.fixed('off'),
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('alignment: .topLeading)'),
        );
      });

      test('a box with room for its child does not clip', () {
        expect(
          const HWSizedBox(width: 80, child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          isNot(contains('.clipped()')),
        );
        expect(
          const HWSizedBox.expand(child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          isNot(contains('.clipped()')),
        );
      });

      test('a box without a dimension leaves the child alone', () {
        expect(
          const HWSizedBox(child: HWText.fixed('a'))
              .toSwift(0, dataExpr: 'data'),
          'Text("a")',
        );
      });

      test('a childless box is a clear gap, an open axis collapsing to 0', () {
        expect(
          const HWSizedBox(width: 8).toSwift(0, dataExpr: 'data'),
          'Color.clear\n.frame(width: 8.0, height: 0.0)',
        );
        expect(
          const HWSizedBox(height: 8).toSwift(0, dataExpr: 'data'),
          'Color.clear\n.frame(width: 0.0, height: 8.0)',
        );
        expect(
          const HWSizedBox(width: double.infinity, height: 8)
              .toSwift(0, dataExpr: 'data'),
          'Color.clear\n.frame(height: 8.0)\n.frame(maxWidth: .infinity)',
        );
      });

      test('a childless box asking for no room at all is no view', () {
        expect(
          const HWSizedBox().toSwift(0, dataExpr: 'data'),
          'EmptyView()',
        );
        expect(
          const HWSizedBox.shrink().toSwift(0, dataExpr: 'data'),
          'EmptyView()',
        );
        expect(
          const HWSizedBox(width: 8).toSwift(0, dataExpr: 'data'),
          'Color.clear\n.frame(width: 8.0, height: 0.0)',
        );
      });

      test('respects the indent it is emitted at', () {
        expect(
          const HWSizedBox(width: 8, child: HWText.fixed('a'))
              .toSwift(1, dataExpr: 'data'),
          '    Text("a")\n    .frame(width: 8.0, alignment: .topLeading)',
        );
        expect(
          const HWSizedBox(width: 8).toSwift(1, dataExpr: 'data'),
          '    Color.clear\n    .frame(width: 8.0, height: 0.0)',
        );
        expect(
          const HWSizedBox.shrink().toSwift(1, dataExpr: 'data'),
          '    EmptyView()',
        );
      });

      test('wraps a conditional child in a Group so the frame chains', () {
        const box = HWSizedBox.expand(
          child: HWDataExists(
            data: HWBool('flag'),
            whenPresent: HWText.fixed('on'),
            whenAbsent: HWText.fixed('off'),
          ),
        );
        final result = box.toSwift(0, dataExpr: 'data');
        expect(result, startsWith('Group {\n'));
        expect(result, contains('if data.flag != nil {'));
        expect(
          result,
          endsWith(
            '\n}\n.frame(maxWidth: .infinity, maxHeight: .infinity, '
            'alignment: .topLeading)',
          ),
        );
      });
    });

    group('Android (Glance)', () {
      test('a fixed dimension becomes width/height in dp', () {
        expect(
          const HWSizedBox(width: 80, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          'Text(modifier = GlanceModifier.width(80.0.dp), text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
        expect(
          const HWSizedBox(height: 40, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          'Text(modifier = GlanceModifier.height(40.0.dp), text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
        expect(
          const HWSizedBox(width: 80, height: 40, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          'Text(modifier = GlanceModifier.width(80.0.dp).height(40.0.dp), '
          'text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
      });

      test('an infinite axis fills outside a linear layout', () {
        expect(
          const HWSizedBox(width: double.infinity, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          contains('GlanceModifier.fillMaxWidth()'),
        );
        expect(
          const HWSizedBox(height: double.infinity, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          contains('GlanceModifier.fillMaxHeight()'),
        );
        expect(
          const HWSizedBox.expand(child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          'Text(modifier = GlanceModifier.fillMaxSize(), text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
      });

      test('the main axis of an enclosing Row is taken by weight', () {
        expect(
          const HWSizedBox(width: double.infinity, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data', context: inRow),
          contains('GlanceModifier.defaultWeight()'),
        );
        expect(
          const HWSizedBox(height: double.infinity, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data', context: inRow),
          contains('GlanceModifier.fillMaxHeight()'),
        );
        expect(
          const HWSizedBox.expand(child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data', context: inRow),
          contains('GlanceModifier.defaultWeight().fillMaxHeight()'),
        );
      });

      test('the main axis of an enclosing Column is taken by weight', () {
        expect(
          const HWSizedBox(height: double.infinity, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          contains('GlanceModifier.defaultWeight()'),
        );
        expect(
          const HWSizedBox(width: double.infinity, child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          contains('GlanceModifier.fillMaxWidth()'),
        );
        expect(
          const HWSizedBox.expand(child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          contains('GlanceModifier.fillMaxWidth().defaultWeight()'),
        );
      });

      test('a weight takes over the fill the child asked for', () {
        const box = HWSizedBox.expand(
          child: HWColumn(
            children: [HWText.fixed('a')],
            mainAxisAlignment: HWMainAxisAlignment.center,
          ),
        );
        final result = box.toKotlin(0, dataExpr: 'data', context: inColumn);
        expect(
          result,
          startsWith(
            'Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight(), ',
          ),
        );
        expect(result, isNot(contains('fillMaxHeight()')));
      });

      test('an outer box wins the axis it sizes', () {
        expect(
          const HWSizedBox(
            width: 80,
            child: HWSizedBox.expand(child: HWText.fixed('a')),
          ).toKotlin(0, dataExpr: 'data'),
          contains('GlanceModifier.width(80.0.dp).fillMaxHeight()'),
        );

        final nested = const HWSizedBox(
          width: 80,
          child: HWSizedBox(width: 100, child: HWText.fixed('a')),
        ).toKotlin(0, dataExpr: 'data');
        expect(nested, contains('width(80.0.dp)'));
        expect(nested, isNot(contains('width(100.0.dp)')));

        final colored = const HWSizedBox(
          width: 80,
          child: HWColoredBox(
            color: HWColor.fixed(0xFF0000FF),
            child: HWSizedBox.expand(child: HWText.fixed('a')),
          ),
        ).toKotlin(0, dataExpr: 'data');
        expect(colored, contains('GlanceModifier.width(80.0.dp).background('));
        expect(colored, contains('.fillMaxHeight()'));
        expect(colored, isNot(contains('fillMaxSize()')));
      });

      test('a box around an icon wins over the size it asks for', () {
        final result = const HWSizedBox(
          width: 80,
          height: 40,
          child: HWIcon.glyph(0xE88A, font: _materialIcons),
        ).toKotlin(0, dataExpr: 'data');
        expect(
          result,
          contains('GlanceModifier.width(80.0.dp).height(40.0.dp)'),
        );
        expect(result, isNot(contains('size(')));
      });

      test('a weight the outer box takes wins the axis too', () {
        expect(
          const HWSizedBox(
            width: double.infinity,
            child: HWSizedBox.expand(child: HWText.fixed('a')),
          ).toKotlin(0, dataExpr: 'data', context: inRow),
          contains('GlanceModifier.defaultWeight().fillMaxHeight(),'),
        );
      });

      test('shrink sizes both axes to zero', () {
        expect(
          const HWSizedBox.shrink(child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          contains('GlanceModifier.width(0.0.dp).height(0.0.dp)'),
        );
      });

      test('a box without a dimension leaves the child alone', () {
        expect(
          const HWSizedBox(child: HWText.fixed('a'))
              .toKotlin(0, dataExpr: 'data'),
          'Text(text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
      });

      test('a childless box is a Spacer', () {
        expect(
          const HWSizedBox(width: 8).toKotlin(0, dataExpr: 'data'),
          'Spacer(modifier = GlanceModifier.width(8.0.dp))',
        );
        expect(
          const HWSizedBox(width: 8, height: 12).toKotlin(0, dataExpr: 'data'),
          'Spacer(modifier = GlanceModifier.width(8.0.dp).height(12.0.dp))',
        );
        expect(
          const HWSizedBox(height: double.infinity)
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          'Spacer(modifier = GlanceModifier.defaultWeight())',
        );
        expect(const HWSizedBox().toKotlin(0, dataExpr: 'data'), 'Spacer()');
        expect(
          const HWSizedBox(width: 8).toKotlin(1, dataExpr: 'data'),
          '    Spacer(modifier = GlanceModifier.width(8.0.dp))',
        );
      });

      test('kotlinImports follow what is emitted', () {
        expect(
          const HWSizedBox(width: 8, child: HWText.fixed('a')).kotlinImports,
          containsAll(<String>[
            'import androidx.glance.GlanceModifier',
            'import androidx.glance.layout.width',
            'import androidx.compose.ui.unit.dp',
            'import androidx.glance.layout.Box',
          ]),
        );
        expect(
          const HWSizedBox.expand(child: HWText.fixed('a')).kotlinImports,
          contains('import androidx.glance.layout.fillMaxSize'),
        );
        expect(
          const HWSizedBox(width: 8).kotlinImports,
          allOf(
            contains('import androidx.glance.layout.Spacer'),
            isNot(contains('import androidx.glance.layout.Box')),
          ),
        );
        expect(
          const HWSizedBox(child: HWText.fixed('a')).kotlinImports,
          isNot(contains('import androidx.glance.GlanceModifier')),
        );
      });

      test('kotlinImportsIn swaps the fill for a weight', () {
        const box = HWSizedBox.expand(child: HWText.fixed('a'));
        expect(
          box.kotlinImportsIn(HWAxis.horizontal),
          allOf(
            contains('import androidx.glance.layout.fillMaxHeight'),
            isNot(contains('import androidx.glance.layout.fillMaxWidth')),
            isNot(contains('import androidx.glance.layout.fillMaxSize')),
          ),
        );
        expect(
          box.kotlinImportsIn(HWAxis.vertical),
          allOf(
            contains('import androidx.glance.layout.fillMaxWidth'),
            isNot(contains('import androidx.glance.layout.fillMaxHeight')),
          ),
        );
      });
    });

    group('emit context', () {
      const row = HWRow(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );

      test('an axis the box sets is no longer the enclosing one', () {
        const node = HWRow(
          children: [
            HWSizedBox(width: 100, child: row),
            HWText.fixed('b'),
          ],
        );
        // The inner row asks for its width as a fill rather than a weight, and
        // the box sizing that axis takes the fill over.
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(
            'Row(modifier = GlanceModifier.width(100.0.dp), '
            'verticalAlignment = Alignment.CenterVertically) {',
          ),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.fillMaxWidth'),
        );
      });

      test('an axis the box leaves open stays the enclosing one', () {
        const node = HWRow(
          children: [
            HWSizedBox(height: 40, child: row),
            HWText.fixed('b'),
          ],
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(
            'Row(modifier = GlanceModifier.height(40.0.dp).defaultWeight(), '
            'verticalAlignment = Alignment.CenterVertically) {',
          ),
        );
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );
      });
    });

    group('baseline', () {
      const text = HWText.fixed('a', style: HWTextStyle(fontSize: 21));

      test('a box without a height keeps the child baseline text', () {
        expect(
          const HWSizedBox(width: 8, child: text)
              .kotlinBaselineText()
              ?.ascent('data'),
          contains('21f'),
        );
      });

      test('a set height moves the top off the glyphs', () {
        expect(
          const HWSizedBox(height: 8, child: text).kotlinBaselineText(),
          isNull,
        );
        expect(
          const HWSizedBox(height: double.infinity, child: text)
              .kotlinBaselineText(),
          isNull,
        );
      });

      test('a childless box has no baseline text', () {
        expect(const HWSizedBox(width: 8).kotlinBaselineText(), isNull);
      });

      test('a bounded box reports the child baseline', () {
        expect(
          const HWSizedBox(width: 8, height: 8, child: text)
              .kotlinReportsBaseline,
          isTrue,
        );
        expect(const HWSizedBox(child: text).kotlinReportsBaseline, isTrue);
      });

      test('an infinite axis reports no baseline', () {
        expect(
          const HWSizedBox(width: double.infinity, child: text)
              .kotlinReportsBaseline,
          isFalse,
        );
        expect(
          const HWSizedBox.expand(child: text).kotlinReportsBaseline,
          isFalse,
        );
      });

      test('a childless box reports no baseline', () {
        expect(const HWSizedBox(width: 8).kotlinReportsBaseline, isFalse);
      });
    });
  });
}
