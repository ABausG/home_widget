import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _a = HWText.fixed('a');
const _b = HWText.fixed('b');
const _hidden = HWDataOnly([HWString('hidden')]);

String _text(String content) => 'Text(text = "$content", '
    'style = TextStyle(color = GlanceTheme.colors.onSurface))';

void main() {
  group('HWStack', () {
    const inRow = HWEmitContext(enclosingLinearAxis: HWAxis.horizontal);
    const inColumn = HWEmitContext(enclosingLinearAxis: HWAxis.vertical);

    group('model', () {
      test('stacks its children at the top start, loosely, by default', () {
        const stack = HWStack(children: [_a, _b]);
        expect(stack.alignment, HWAlignment.topStart);
        expect(stack.fit, HWStackFit.loose);
      });

      test('lists the children as they were written', () {
        const stack = HWStack(fit: HWStackFit.expand, children: [_a, _b]);
        expect(stack.childWidgets, [_a, _b]);
        expect(stack.descendants, hasLength(3));
      });

      test('collects what the children contribute', () {
        const stack = HWStack(
          children: [
            HWText(HWString('k')),
            HWImage(HWImageData('avatar')),
          ],
        );
        expect(
          stack.dataDependencies,
          containsAll(<HWDataType<dynamic>>[
            const HWString('k'),
            const HWImageData('avatar'),
          ]),
        );
      });

      test('an empty loose stack renders nothing', () {
        const empty = HWStack(children: []);
        expect(empty.swiftRendersNothing, isTrue);
        expect(empty.kotlinRendersNothing, isTrue);
        expect(empty.toSwift(0, dataExpr: 'data'), isEmpty);
        expect(empty.toKotlin(0, dataExpr: 'data'), isEmpty);
        expect(empty.kotlinImports, isEmpty);

        const hidden = HWStack(children: [_hidden]);
        expect(hidden.swiftRendersNothing, isTrue);
        expect(hidden.kotlinRendersNothing, isTrue);
      });

      test('an expanding stack with nothing to show still fills', () {
        const stack = HWStack(fit: HWStackFit.expand, children: [_hidden]);
        expect(stack.swiftRendersNothing, isFalse);
        expect(stack.kotlinRendersNothing, isFalse);
        expect(
          stack.toSwift(0, dataExpr: 'data'),
          'ZStack(alignment: .topLeading) {\n'
          '}\n'
          '.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .topLeading)\n'
          '.clipped()',
        );
        expect(
          stack.toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '}',
        );
      });

      test('a stack holding something renders', () {
        expect(const HWStack(children: [_a]).swiftRendersNothing, isFalse);
        expect(const HWStack(children: [_a]).kotlinRendersNothing, isFalse);
      });

      test('places a frame larger than itself by its own alignment', () {
        expect(
          const HWStack(alignment: HWAlignment.bottomEnd, children: [_a])
              .swiftFrameAlignment,
          '.bottomTrailing',
        );
        expect(
          const HWSizedBox(
            width: 64,
            height: 64,
            child: HWStack(
              alignment: HWAlignment.bottomEnd,
              children: [_a],
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith(
            '.frame(width: 64.0, height: 64.0, alignment: .bottomTrailing)\n'
            '.clipped()',
          ),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('a loose stack is a clipped ZStack', () {
        expect(
          const HWStack(alignment: HWAlignment.centerEnd, children: [_a, _b])
              .toSwift(0, dataExpr: 'data'),
          'ZStack(alignment: .trailing) {\n'
          '    Text("a")\n'
          '    Text("b")\n'
          '}\n'
          '.clipped()',
        );
      });

      test('an expanding stack frames itself and every child', () {
        expect(
          const HWStack(
            fit: HWStackFit.expand,
            alignment: HWAlignment.center,
            children: [_a],
          ).toSwift(0, dataExpr: 'data'),
          'ZStack(alignment: .center) {\n'
          '    Text("a")\n'
          '    .frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .center)\n'
          '}\n'
          '.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .center)\n'
          '.clipped()',
        );
      });

      test('a child that places itself is left alone', () {
        expect(
          const HWStack(
            fit: HWStackFit.expand,
            alignment: HWAlignment.center,
            children: [HWAlign(alignment: HWAlignment.topEnd, child: _a)],
          ).toSwift(0, dataExpr: 'data'),
          'ZStack(alignment: .center) {\n'
          '    Text("a")\n'
          '    .frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .topTrailing)\n'
          '}\n'
          '.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .center)\n'
          '.clipped()',
        );
      });

      test('a child filling both axes gets no frame of the stack', () {
        expect(
          const HWStack(
            fit: HWStackFit.expand,
            alignment: HWAlignment.center,
            children: [HWSizedBox.expand(child: _a)],
          ).toSwift(0, dataExpr: 'data'),
          'ZStack(alignment: .center) {\n'
          '    Text("a")\n'
          '    .frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .topLeading)\n'
          '}\n'
          '.frame(maxWidth: .infinity, maxHeight: .infinity, '
          'alignment: .center)\n'
          '.clipped()',
        );
      });

      test('a child rendering nothing takes no room in the stack', () {
        expect(
          const HWStack(children: [_hidden, _a]).toSwift(0, dataExpr: 'data'),
          'ZStack(alignment: .topLeading) {\n'
          '    Text("a")\n'
          '}\n'
          '.clipped()',
        );
      });

      test('respects the indent it is emitted at', () {
        expect(
          const HWStack(children: [_a]).toSwift(1, dataExpr: 'data'),
          '    ZStack(alignment: .topLeading) {\n'
          '        Text("a")\n'
          '    }\n'
          '    .clipped()',
        );
      });
    });

    group('Android (Glance)', () {
      test('a loose stack is a Box asking for no room', () {
        expect(
          const HWStack(alignment: HWAlignment.bottomCenter, children: [_a, _b])
              .toKotlin(0, dataExpr: 'data'),
          'Box(contentAlignment = Alignment.BottomCenter) {\n'
          '    ${_text('a')}\n'
          '    ${_text('b')}\n'
          '}',
        );
      });

      test('an expanding stack fills, and each child fills it', () {
        expect(
          const HWStack(
            fit: HWStackFit.expand,
            alignment: HWAlignment.center,
            children: [_a],
          ).toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.Center) {\n'
          '    Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.Center) {\n'
          '        ${_text('a')}\n'
          '    }\n'
          '}',
        );
      });

      test('a child that places itself is not nested in a second Box', () {
        expect(
          const HWStack(
            fit: HWStackFit.expand,
            alignment: HWAlignment.center,
            children: [HWAlign(alignment: HWAlignment.topEnd, child: _a)],
          ).toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.Center) {\n'
          '    Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopEnd) {\n'
          '        ${_text('a')}\n'
          '    }\n'
          '}',
        );
      });

      test('a child filling both axes is not nested in a Box of the stack', () {
        expect(
          const HWAlign(
            child: HWStack(
              fit: HWStackFit.expand,
              children: [HWSizedBox.expand(child: _a)],
            ),
          ).toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.Center) {\n'
          '    Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '        Text(modifier = GlanceModifier.fillMaxSize(), text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))\n'
          '    }\n'
          '}',
        );
        expect(
          const HWStack(
            fit: HWStackFit.expand,
            children: [
              HWStack(fit: HWStackFit.expand, children: [_a]),
              HWSizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _b,
              ),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '    Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '        Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '            ${_text('a')}\n'
          '        }\n'
          '    }\n'
          '    Text(modifier = GlanceModifier.fillMaxSize(), text = "b", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))\n'
          '}',
        );
      });

      test('a loose stack asks for the room of every branch a child can pick',
          () {
        const conditional = HWStack(
          children: [
            HWBoolConditional(
              data: HWBool('flag', defaultValue: false),
              whenTrue: HWSizedBox.expand(child: _a),
              whenFalse: _b,
            ),
          ],
        );
        expect(
          conditional.toKotlin(0, dataExpr: 'data'),
          startsWith(
            'Box(modifier = GlanceModifier.fillMaxSize(), '
            'contentAlignment = Alignment.TopStart) {\n'
            '    if (data.flag == true) {\n',
          ),
        );
        expect(
          conditional.kotlinImports,
          contains('import androidx.glance.layout.fillMaxSize'),
        );

        const adaptive = HWStack(
          children: [
            HWSizeAdaptive(
              small: _a,
              large: HWSizedBox(width: double.infinity, child: _b),
            ),
          ],
        );
        expect(
          adaptive.toKotlin(0, dataExpr: 'data'),
          startsWith(
            'Box(modifier = GlanceModifier.fillMaxWidth(), '
            'contentAlignment = Alignment.TopStart) {\n'
            '    when (LocalSize.current) {\n',
          ),
        );

        expect(
          const HWStack(
            children: [
              _a,
              HWDataExists(
                data: HWString('maybe'),
                whenPresent: _hidden,
                whenAbsent: HWSizedBox.expand(child: _hidden),
              ),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          startsWith('Box(contentAlignment = Alignment.TopStart) {'),
        );
      });

      test('shares the main axis of an enclosing stack by weight', () {
        expect(
          const HWStack(fit: HWStackFit.expand, children: [_a])
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          startsWith(
            'Box(modifier = GlanceModifier.defaultWeight().fillMaxWidth(), ',
          ),
        );
        expect(
          const HWStack(fit: HWStackFit.expand, children: [_a])
              .toKotlin(0, dataExpr: 'data', context: inRow),
          startsWith(
            'Box(modifier = GlanceModifier.defaultWeight().fillMaxHeight(), ',
          ),
        );
        expect(
          const HWStack(children: [_a])
              .toKotlin(0, dataExpr: 'data', context: inColumn),
          startsWith('Box(contentAlignment = Alignment.TopStart) {'),
        );
      });

      test('a loose stack asks for the room its children ask for', () {
        const aligned = HWStack(children: [HWAlign(child: _a)]);
        expect(
          aligned.toKotlin(0, dataExpr: 'data'),
          startsWith(
            'Box(modifier = GlanceModifier.fillMaxSize(), '
            'contentAlignment = Alignment.TopStart) {',
          ),
        );
        expect(
          aligned.toKotlin(0, dataExpr: 'data', context: inColumn),
          startsWith(
            'Box(modifier = GlanceModifier.defaultWeight().fillMaxWidth(), ',
          ),
        );
        expect(
          aligned.toKotlin(0, dataExpr: 'data', context: inRow),
          startsWith(
            'Box(modifier = GlanceModifier.defaultWeight().fillMaxHeight(), ',
          ),
        );
        expect(
          aligned.kotlinImports,
          containsAll(<String>[
            'import androidx.glance.GlanceModifier',
            'import androidx.glance.layout.fillMaxSize',
          ]),
        );
      });

      test('a loose stack asks for one axis while only one is asked for', () {
        const bar = HWStack(
          children: [HWSizedBox(width: double.infinity, child: _a)],
        );
        expect(
          bar.toKotlin(0, dataExpr: 'data'),
          startsWith(
            'Box(modifier = GlanceModifier.fillMaxWidth(), '
            'contentAlignment = Alignment.TopStart) {',
          ),
        );
        expect(
          bar.kotlinImports,
          allOf(
            contains('import androidx.glance.layout.fillMaxWidth'),
            isNot(contains('import androidx.glance.layout.fillMaxSize')),
          ),
        );
        expect(
          bar.toKotlin(0, dataExpr: 'data', context: inRow),
          startsWith('Box(modifier = GlanceModifier.defaultWeight(), '),
        );
      });

      test('a child rendering nothing asks for no room either', () {
        expect(
          const HWStack(
            children: [_a, HWSizedBox.expand(child: _hidden)],
          ).toKotlin(0, dataExpr: 'data'),
          startsWith('Box(contentAlignment = Alignment.TopStart) {'),
        );
      });

      test('a Box is no linear layout, so a child fills rather than weighs',
          () {
        expect(
          const HWColumn(
            children: [
              HWStack(children: [HWSizedBox.expand(child: _a)]),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          contains('Text(modifier = GlanceModifier.fillMaxSize(), '
              'text = "a", '),
        );
      });

      test('a conditional child is emitted inside the Box', () {
        expect(
          const HWStack(
            children: [
              HWBoolConditional(
                data: HWBool('flag', defaultValue: false),
                whenTrue: _a,
                whenFalse: _b,
              ),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          'Box(contentAlignment = Alignment.TopStart) {\n'
          '    if (data.flag == true) {\n'
          '        ${_text('a')}\n'
          '    } else {\n'
          '        ${_text('b')}\n'
          '    }\n'
          '}',
        );
      });

      test('a child rendering nothing is no child of the Box', () {
        expect(
          const HWStack(children: [_hidden, _a]).toKotlin(0, dataExpr: 'data'),
          'Box(contentAlignment = Alignment.TopStart) {\n'
          '    ${_text('a')}\n'
          '}',
        );
        expect(
          const HWStack(fit: HWStackFit.expand, children: [_hidden, _a])
              .toKotlin(0, dataExpr: 'data'),
          'Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '    Box(modifier = GlanceModifier.fillMaxSize(), '
          'contentAlignment = Alignment.TopStart) {\n'
          '        ${_text('a')}\n'
          '    }\n'
          '}',
        );
      });

      test('kotlinImports follow what is emitted', () {
        expect(
          const HWStack(children: [_a]).kotlinImports,
          allOf(
            containsAll(<String>[
              'import androidx.glance.layout.Box',
              'import androidx.glance.layout.Alignment',
              'import androidx.glance.text.Text',
            ]),
            isNot(contains('import androidx.glance.GlanceModifier')),
          ),
        );
        expect(
          const HWStack(fit: HWStackFit.expand, children: [_a]).kotlinImports,
          containsAll(<String>[
            'import androidx.glance.GlanceModifier',
            'import androidx.glance.layout.fillMaxSize',
          ]),
        );
        expect(
          const HWStack(fit: HWStackFit.expand, children: [_a])
              .kotlinImportsIn(HWAxis.vertical),
          containsAll(<String>[
            'import androidx.glance.layout.fillMaxWidth',
            'import androidx.glance.layout.fillMaxSize',
          ]),
        );
        expect(
          const HWStack(children: [_a]).kotlinImportsIn(HWAxis.vertical),
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );
        expect(
          const HWStack(children: [_hidden]).kotlinImports,
          isEmpty,
        );
      });

      test('a stack in a spaced column takes the gap on its own Box', () {
        expect(
          const HWColumn(
            spacing: 8,
            children: [
              _a,
              HWStack(children: [_b]),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          contains(
            'Box(modifier = GlanceModifier.padding(top = 8.0.dp), '
            'contentAlignment = Alignment.TopStart) {',
          ),
        );
      });
    });

    group('baseline', () {
      test('has no baseline of its own', () {
        expect(const HWStack(children: [_a]).kotlinReportsBaseline, isFalse);
        expect(const HWStack(children: [_a]).kotlinBaselineText(), isNull);
        expect(const HWStack(children: [_a]).kotlinPaddingAddsRoom, isTrue);
      });

      test('a baseline row leaves it at the top', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              '50',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
            HWText.fixed('Points', style: HWTextStyle(fontSize: 14)),
            const HWStack(children: [_a]),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect('HomeWidgetFonts.baselinePadding('.allMatches(result).length, 2);
        expect(
          result,
          contains('Box(contentAlignment = Alignment.TopStart) {'),
        );
      });
    });
  });
}
