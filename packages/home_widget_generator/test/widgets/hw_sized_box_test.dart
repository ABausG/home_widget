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
        expect(
          const HWSizedBox(
            width: 8,
            child: HWSizedBox(
              child: HWColumn(
                children: [HWText.fixed('a')],
                crossAxisAlignment: HWCrossAxisAlignment.center,
              ),
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('.frame(width: 8.0, alignment: .top)'),
        );
        expect(const HWSizedBox().swiftFrameAlignment, '.topLeading');
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

      test('a bounded box cuts off a child that clips its own bounds', () {
        expect(
          const HWSizedBox(
            width: 40,
            height: 40,
            child: HWStack(
              children: [
                HWColoredBox(
                  color: HWColor.fixed(0xFF3366FF),
                  child: HWSizedBox(width: 80, height: 20),
                ),
              ],
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith(
            '.frame(width: 40.0, height: 40.0, alignment: .topLeading)\n'
            '.clipped()',
          ),
        );
      });

      test('padding around such a child is cut off at the box too', () {
        expect(
          const HWSizedBox(
            width: 40,
            height: 40,
            child: HWPadding(
              padding: HWEdgeInsets.all(4),
              child: HWStack(children: [HWText.fixed('a')]),
            ),
          ).toSwift(0, dataExpr: 'data'),
          endsWith(
            '.frame(width: 40.0, height: 40.0, alignment: .topLeading)\n'
            '.clipped()',
          ),
        );
      });

      group('a child picked at runtime', () {
        const stack = HWStack(children: [HWText.fixed('a')]);
        const bordered = HWDecoratedBox(
          decoration: HWBoxDecoration(
            border: HWBoxBorder(
              thickness: 2,
              color: HWColor.fixed(0xFF000000),
            ),
          ),
          child: HWText.fixed('b'),
        );
        const frame =
            '.frame(width: 64.0, height: 64.0, alignment: .topLeading)';

        String boxed(HWWidget child) =>
            HWSizedBox(width: 64, height: 64, child: child)
                .toSwift(0, dataExpr: 'data');

        test('is cut off once a branch clips itself', () {
          expect(
            boxed(
              const HWBoolConditional(
                data: HWBool('flag', defaultValue: false),
                whenTrue: stack,
                whenFalse: HWText.fixed('b'),
              ),
            ),
            endsWith('$frame\n.clipped()'),
          );
        });

        test('is framed per branch once a branch draws a border', () {
          final conditional = boxed(
            const HWBoolConditional(
              data: HWBool('flag', defaultValue: false),
              whenTrue: stack,
              whenFalse: bordered,
            ),
          );
          expect(conditional, startsWith('if data.flag == true {\n'));
          expect(conditional, contains('    $frame\n    .clipped()\n} else {'));
          expect(
            conditional,
            contains('    Text("b")\n    $frame\n    .overlay('),
          );
          expect(
            boxed(const HWSizeAdaptive(small: stack, large: bordered)),
            isNot(contains('}\n$frame')),
          );
          expect(
            boxed(const HWAdaptive(ios: bordered, android: stack)),
            startsWith('Text("b")\n$frame\n.overlay('),
          );
          expect(
            boxed(const HWAdaptive(ios: stack, android: bordered)),
            endsWith('$frame\n.clipped()'),
          );
        });
      });

      test('a border around such a child is stroked over the clip', () {
        final result = const HWSizedBox(
          width: 40,
          height: 40,
          child: HWDecoratedBox(
            decoration: HWBoxDecoration(
              border: HWBoxBorder(
                thickness: 2,
                color: HWColor.fixed(0xFF000000),
              ),
            ),
            child: HWStack(children: [HWText.fixed('a')]),
          ),
        ).toSwift(0, dataExpr: 'data');
        expect(
          result,
          contains(
            '.frame(width: 40.0, height: 40.0, alignment: .topLeading)\n'
            '.clipped()\n'
            '.overlay(',
          ),
        );
        expect('.clipped()'.allMatches(result), hasLength(2));
      });

      group('a decorated child', () {
        const rounded = HWBoxDecoration(
          color: HWColor.fixed(0xFF3366FF),
          borderRadius: HWBorderRadius.circular(16),
          border: HWBoxBorder(
            thickness: 0,
            color: HWColor.fixed(0xFF3366FF),
          ),
        );
        const fill = '.background(RoundedRectangle(cornerRadius: 16.0)'
            '.fill(Color(red: 0.2, green: 0.4, blue: 1.0, opacity: 1.0)))';
        const stroke = '.overlay(RoundedRectangle(cornerRadius: 16.0)'
            '.strokeBorder(Color(red: 0.2, green: 0.4, blue: 1.0, '
            'opacity: 1.0), '
            'lineWidth: 0.0))';
        const wide = '.frame(maxWidth: .infinity, alignment: .topLeading)';

        test('is decorated across the whole box', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWDecoratedBox(
                decoration: rounded,
                child: HWText.fixed('a'),
              ),
            ).toSwift(0, dataExpr: 'data'),
            'Text("a")\n$wide\n$fill\n$stroke',
          );
        });

        test('matches the box inside the decoration', () {
          const inside = HWDecoratedBox(
            decoration: rounded,
            child: HWSizedBox(
              width: double.infinity,
              child: HWText.fixed('a'),
            ),
          );
          const outside = HWSizedBox(
            width: double.infinity,
            child: HWDecoratedBox(
              decoration: rounded,
              child: HWText.fixed('a'),
            ),
          );
          for (final stack in [
            (List<HWWidget> c) => HWColumn(children: c),
            (List<HWWidget> c) => HWRow(children: c),
          ]) {
            expect(
              stack(const [outside]).toSwift(0, dataExpr: 'data'),
              stack(const [inside]).toSwift(0, dataExpr: 'data'),
            );
          }
          expect(
            const HWColumn(children: [outside]).toSwift(0, dataExpr: 'data'),
            contains('    Text("a")\n    $wide\n    $fill\n    $stroke\n'),
          );
        });

        test('is colored across the whole box', () {
          expect(
            const HWSizedBox(
              width: 80,
              height: 40,
              child: HWColoredBox(
                color: HWColor.fixed(0xFF3366FF),
                child: HWText.fixed('a'),
              ),
            ).toSwift(0, dataExpr: 'data'),
            'Text("a")\n'
            '.frame(width: 80.0, height: 40.0, alignment: .topLeading)\n'
            '.background(Color(red: 0.2, green: 0.4, blue: 1.0, opacity: 1.0))',
          );
        });

        test('reaches through nested decorations', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWColoredBox(
                color: HWColor.fixed(0xFF000000),
                child: HWDecoratedBox(
                  decoration: rounded,
                  child: HWText.fixed('a'),
                ),
              ),
            ).toSwift(0, dataExpr: 'data'),
            'Text("a")\n$wide\n$fill\n$stroke\n'
            '.background(Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0))',
          );
        });

        group('behind a padding', () {
          const pad8 = '.padding(EdgeInsets(top: 8.0, leading: 8.0, '
              'bottom: 8.0, trailing: 8.0))';
          const blue = '.background(RoundedRectangle(cornerRadius: 16.0)'
              '.fill(Color(red: 0.2, green: 0.4, blue: 1.0, opacity: 1.0)))';
          const card = HWDecoratedBox(
            decoration: HWBoxDecoration(
              color: HWColor.fixed(0xFF3366FF),
              borderRadius: HWBorderRadius.circular(16),
            ),
            child: HWText.fixed('a'),
          );

          test('is framed inside the padding along an infinite axis', () {
            const box = HWSizedBox(
              width: double.infinity,
              child: HWPadding(padding: HWEdgeInsets.all(8), child: card),
            );
            expect(
              box.toSwift(0, dataExpr: 'data'),
              'Text("a")\n$wide\n$blue\n$pad8',
            );
            expect(
              const HWColumn(children: [box]).toSwift(0, dataExpr: 'data'),
              contains('    Text("a")\n    $wide\n    $blue\n    $pad8\n'),
            );
            expect(
              const HWRow(children: [box]).toSwift(0, dataExpr: 'data'),
              contains('    Text("a")\n    $wide\n    $blue\n    $pad8\n'),
            );
          });

          test('gives a finite axis up to the padding', () {
            expect(
              const HWSizedBox(
                width: 80,
                height: 40,
                child: HWPadding(
                  padding: HWEdgeInsets.only(left: 8, right: 4, top: 30),
                  child: card,
                ),
              ).toSwift(0, dataExpr: 'data'),
              startsWith(
                'Text("a")\n'
                '.frame(width: 68.0, height: 10.0, alignment: .topLeading)\n'
                '$blue\n',
              ),
            );
            expect(
              const HWSizedBox(
                width: 10,
                child: HWPadding(padding: HWEdgeInsets.all(8), child: card),
              ).toSwift(0, dataExpr: 'data'),
              contains('.frame(width: 0.0, alignment: .topLeading)\n'),
            );
          });

          test('is framed inside a padding between two decorations', () {
            expect(
              const HWSizedBox(
                width: 80,
                child: HWColoredBox(
                  color: HWColor.fixed(0xFF000000),
                  child: HWPadding(padding: HWEdgeInsets.all(8), child: card),
                ),
              ).toSwift(0, dataExpr: 'data'),
              'Text("a")\n'
              '.frame(width: 64.0, alignment: .topLeading)\n'
              '$blue\n'
              '$pad8\n'
              '.background(Color(red: 0.0, green: 0.0, blue: 0.0, '
              'opacity: 1.0))',
            );
          });

          test('a padding around no decoration is framed as before', () {
            expect(
              const HWSizedBox(
                width: 80,
                child: HWPadding(
                  padding: HWEdgeInsets.all(8),
                  child: HWText.fixed('a'),
                ),
              ).toSwift(0, dataExpr: 'data'),
              'Text("a")\n$pad8\n.frame(width: 80.0, alignment: .topLeading)',
            );
          });
        });

        test('is framed at the alignment of what it decorates', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWDecoratedBox(
                decoration: rounded,
                child: HWIcon.glyph(0xE88A, font: _materialIcons),
              ),
            ).toSwift(0, dataExpr: 'data'),
            contains('.frame(maxWidth: .infinity, alignment: .center)\n'
                '.background('),
          );
        });
      });

      test('an infinite axis is no bound to cut the child off at', () {
        final result = const HWSizedBox(
          width: double.infinity,
          child: HWStack(children: [HWText.fixed('a')]),
        ).toSwift(0, dataExpr: 'data');
        expect(
          result,
          endsWith('.frame(maxWidth: .infinity, alignment: .topLeading)'),
        );
        expect('.clipped()'.allMatches(result), hasLength(1));
      });

      test('a box sized to zero around such a child clips once', () {
        final result = const HWSizedBox(
          width: 0,
          child: HWStack(children: [HWText.fixed('a')]),
        ).toSwift(0, dataExpr: 'data');
        expect('.clipped()'.allMatches(result), hasLength(2));
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

      test('a childless box asking for no room at all renders nothing', () {
        expect(const HWSizedBox().swiftRendersNothing, isTrue);
        expect(const HWSizedBox().toSwift(0, dataExpr: 'data'), isEmpty);
        expect(const HWSizedBox.shrink().swiftRendersNothing, isTrue);
        expect(
          const HWSizedBox.shrink().toSwift(0, dataExpr: 'data'),
          isEmpty,
        );
        expect(
          const HWSizedBox(width: 8).toSwift(0, dataExpr: 'data'),
          'Color.clear\n.frame(width: 8.0, height: 0.0)',
        );
      });

      test('a box around a child rendering nothing renders nothing', () {
        const box = HWSizedBox(
          width: 80,
          height: 40,
          child: HWDataOnly([HWString('hidden')]),
        );
        expect(box.swiftRendersNothing, isTrue);
        expect(box.toSwift(0, dataExpr: 'data'), isEmpty);
        expect(
          const HWSizedBox.expand(child: HWDataOnly([HWString('hidden')]))
              .toSwift(0, dataExpr: 'data'),
          isEmpty,
        );
      });

      test('shrink is the empty branch of a conditional', () {
        expect(
          const HWColumn(
            children: [
              HWBoolConditional(
                data: HWBool('flag', defaultValue: false),
                whenTrue: HWText.fixed('on'),
                whenFalse: HWSizedBox.shrink(),
              ),
            ],
          ).toSwift(0, dataExpr: 'data'),
          'VStack(alignment: .center, spacing: 0) {\n'
          '    if data.flag == true {\n'
          '        Text("on")\n'
          '    } else {\n'
          '\n'
          '    }\n'
          '}',
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

      group('a bordered child', () {
        const rounded = HWBoxDecoration(
          color: HWColor.fixed(0xFF3366FF),
          borderRadius: HWBorderRadius.circular(16),
          border: HWBoxBorder(
            thickness: 0,
            color: HWColor.fixed(0xFF000000),
          ),
        );
        const fillColor = 'background(ColorProvider(day = Color(0xFF3366FF), '
            'night = Color(0xFF3366FF)))';
        const borderColor = 'background(ColorProvider(day = Color(0xFF000000), '
            'night = Color(0xFF000000)))';
        const text = 'text = "a", '
            'style = TextStyle(color = GlanceTheme.colors.onSurface))';

        String card(String room, String fill) => 'Box(\n'
            '    modifier = GlanceModifier.$room$borderColor'
            '.cornerRadius(16.0.dp).padding(0.0.dp)\n'
            ') {\n'
            '    Box(\n'
            '        modifier = GlanceModifier.$fill.$fillColor'
            '.cornerRadius(16.0.dp)\n'
            '    ) {\n'
            '        Text(modifier = GlanceModifier.$fill, $text\n'
            '    }\n'
            '}';

        const outside = HWSizedBox(
          width: double.infinity,
          child: HWDecoratedBox(
            decoration: rounded,
            child: HWText.fixed('a'),
          ),
        );
        const inside = HWDecoratedBox(
          decoration: rounded,
          child: HWSizedBox(
            width: double.infinity,
            child: HWText.fixed('a'),
          ),
        );

        test('is filled across the whole box at the top level', () {
          for (final box in const <HWWidget>[outside, inside]) {
            expect(
              box.toKotlin(0, dataExpr: 'data'),
              card('fillMaxWidth().', 'fillMaxWidth()'),
            );
            expect(
              box.kotlinImports,
              contains('import androidx.glance.layout.fillMaxWidth'),
            );
          }
        });

        test('fills the cross axis of a column', () {
          for (final box in const <HWWidget>[outside, inside]) {
            expect(
              box.kotlinRoomIn(HWAxis.vertical),
              isA<HWKotlinRoom>()
                  .having((r) => r.weight, 'weight', isFalse)
                  .having((r) => r.fillsWidth, 'fillsWidth', isTrue),
            );
            expect(
              box.toKotlin(0, dataExpr: 'data', context: inColumn),
              card('fillMaxWidth().', 'fillMaxWidth()'),
            );
          }
        });

        test('takes a weight along a row', () {
          for (final box in const <HWWidget>[outside, inside]) {
            expect(
              box.kotlinRoomIn(HWAxis.horizontal),
              isA<HWKotlinRoom>()
                  .having((r) => r.weight, 'weight', isTrue)
                  .having((r) => r.fillsWidth, 'fillsWidth', isFalse),
            );
            expect(
              box.toKotlin(0, dataExpr: 'data', context: inRow),
              card('defaultWeight().', 'fillMaxWidth()'),
            );
          }
          for (final box in const <HWWidget>[outside, inside]) {
            expect(
              HWRow(children: [box, const HWText.fixed('b')])
                  .toKotlin(0, dataExpr: 'data'),
              contains('    Box(\n'
                  '        modifier = GlanceModifier.defaultWeight().'),
            );
          }
        });

        test('fills a fixed size inside the border', () {
          expect(
            const HWSizedBox(
              width: 80,
              height: 40,
              child: HWDecoratedBox(
                decoration: rounded,
                child: HWText.fixed('a'),
              ),
            ).toKotlin(0, dataExpr: 'data'),
            card('width(80.0.dp).height(40.0.dp).', 'fillMaxSize()'),
          );
        });

        test('a size wins over the room the decorated child asks for', () {
          expect(
            const HWSizedBox(
              width: 80,
              child: HWDecoratedBox(
                decoration: rounded,
                child: HWSizedBox.expand(child: HWText.fixed('a')),
              ),
            ).toKotlin(0, dataExpr: 'data', context: inColumn),
            startsWith(
              'Box(\n    modifier = GlanceModifier.width(80.0.dp)'
              '.defaultWeight().$borderColor',
            ),
          );
        });

        test('is reached through a colored box', () {
          final result = const HWColumn(
            children: [
              HWSizedBox(
                width: double.infinity,
                child: HWColoredBox(
                  color: HWColor.fixed(0xFF3366FF),
                  child: HWDecoratedBox(
                    decoration: rounded,
                    child: HWText.fixed('a'),
                  ),
                ),
              ),
            ],
          ).toKotlin(0, dataExpr: 'data');
          expect(
            result,
            contains('    Box(\n'
                '        modifier = GlanceModifier.fillMaxWidth()'
                '.$fillColor.$borderColor'),
          );
          expect(
            result,
            contains('            Text(modifier = GlanceModifier'
                '.fillMaxWidth(), $text'),
          );
        });

        test('without a fill the child fills the border', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWDecoratedBox(
                decoration: HWBoxDecoration(
                  border: HWBoxBorder(
                    thickness: 2,
                    color: HWColor.fixed(0xFF000000),
                  ),
                ),
                child: HWText.fixed('a'),
              ),
            ).toKotlin(0, dataExpr: 'data', context: inRow),
            'Box(\n'
            '    modifier = GlanceModifier.defaultWeight().$borderColor'
            '.cornerRadius(0.0.dp).padding(2.0.dp)\n'
            ') {\n'
            '        Text(modifier = GlanceModifier.fillMaxWidth(), $text\n'
            '}',
          );
        });

        test('a box leaving the axes open changes nothing', () {
          expect(
            const HWSizedBox(
              child: HWDecoratedBox(
                decoration: rounded,
                child: HWText.fixed('a'),
              ),
            ).toKotlin(0, dataExpr: 'data'),
            const HWDecoratedBox(
              decoration: rounded,
              child: HWText.fixed('a'),
            ).toKotlin(0, dataExpr: 'data'),
          );
        });
      });

      group('a padded decoration', () {
        const pad = 'padding(start = 8.0.dp, top = 8.0.dp, '
            'end = 8.0.dp, bottom = 8.0.dp)';
        const text = 'text = "a", '
            'style = TextStyle(color = GlanceTheme.colors.onSurface))';
        const blue = 'background(ColorProvider(day = Color(0xFF3366FF), '
            'night = Color(0xFF3366FF))).cornerRadius(16.0.dp)';
        const card = HWDecoratedBox(
          decoration: HWBoxDecoration(
            color: HWColor.fixed(0xFF3366FF),
            borderRadius: HWBorderRadius.circular(16),
          ),
          child: HWText.fixed('a'),
        );
        const wide = HWSizedBox(
          width: double.infinity,
          child: HWPadding(padding: HWEdgeInsets.all(8), child: card),
        );

        String padded(String room, String fill, {String indent = ''}) =>
            '${indent}Box(modifier = GlanceModifier.$room$pad) {\n'
            '$indent    Text(modifier = GlanceModifier.$fill.$blue, $text\n'
            '$indent}';

        test('fills the padding Box at the top level', () {
          expect(
            wide.toKotlin(0, dataExpr: 'data'),
            padded('fillMaxWidth().', 'fillMaxWidth()'),
          );
          expect(
            wide.kotlinImports,
            containsAll([
              'import androidx.glance.layout.fillMaxWidth',
              'import androidx.glance.appwidget.cornerRadius',
            ]),
          );
        });

        test('fills the cross axis of a column', () {
          expect(
            const HWColumn(children: [wide]).toKotlin(0, dataExpr: 'data'),
            contains(
              padded('fillMaxWidth().', 'fillMaxWidth()', indent: '    '),
            ),
          );
        });

        test('takes a weight along a row', () {
          expect(wide.kotlinRoomIn(HWAxis.horizontal).weight, isTrue);
          expect(
            const HWRow(children: [wide, HWText.fixed('b')])
                .toKotlin(0, dataExpr: 'data'),
            contains(
              padded('defaultWeight().', 'fillMaxWidth()', indent: '    '),
            ),
          );
        });

        test('a finite size goes on the padding Box', () {
          expect(
            const HWSizedBox(
              width: 80,
              height: 40,
              child: HWPadding(padding: HWEdgeInsets.all(8), child: card),
            ).toKotlin(0, dataExpr: 'data'),
            padded('width(80.0.dp).height(40.0.dp).', 'fillMaxSize()'),
          );
        });

        test('between two decorations the outer one covers the padding', () {
          expect(
            const HWSizedBox(
              width: 80,
              child: HWColoredBox(
                color: HWColor.fixed(0xFF000000),
                child: HWPadding(padding: HWEdgeInsets.all(8), child: card),
              ),
            ).toKotlin(0, dataExpr: 'data'),
            padded(
              'width(80.0.dp).background(ColorProvider(day = '
                  'Color(0xFF000000), night = Color(0xFF000000))).',
              'fillMaxWidth()',
            ),
          );
        });

        test('matches the size inside the padding', () {
          expect(
            const HWColumn(
              children: [
                HWPadding(
                  padding: HWEdgeInsets.all(8),
                  child: HWSizedBox(width: double.infinity, child: card),
                ),
              ],
            ).toKotlin(0, dataExpr: 'data'),
            const HWColumn(children: [wide]).toKotlin(0, dataExpr: 'data'),
          );
        });

        test('a padding around no decoration is sized as before', () {
          expect(
            const HWSizedBox(
              width: 80,
              child: HWPadding(
                padding: HWEdgeInsets.all(8),
                child: HWText.fixed('a'),
              ),
            ).toKotlin(0, dataExpr: 'data'),
            'Text(modifier = GlanceModifier.width(80.0.dp).$pad, $text',
          );
        });

        test('a decoration around a padded box covers the padding', () {
          expect(
            const HWDecoratedBox(
              decoration: HWBoxDecoration(
                color: HWColor.fixed(0xFF3366FF),
                borderRadius: HWBorderRadius.circular(16),
              ),
              child: HWPadding(
                padding: HWEdgeInsets.all(8),
                child: HWSizedBox(
                  width: double.infinity,
                  child: HWText.fixed('a'),
                ),
              ),
            ).toKotlin(0, dataExpr: 'data', context: inRow),
            'Text(modifier = GlanceModifier.$blue.$pad.defaultWeight(), $text',
          );
        });
      });

      test('a decorated child without a border is sized itself', () {
        expect(
          const HWSizedBox(
            width: double.infinity,
            child: HWDecoratedBox(
              decoration: HWBoxDecoration(color: HWColor.fixed(0xFF3366FF)),
              child: HWText.fixed('a'),
            ),
          ).toKotlin(0, dataExpr: 'data', context: inRow),
          'Text(modifier = GlanceModifier.defaultWeight()'
          '.background(ColorProvider(day = Color(0xFF3366FF), '
          'night = Color(0xFF3366FF))), text = "a", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))',
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
        expect(
          const HWSizedBox(width: 8).toKotlin(1, dataExpr: 'data'),
          '    Spacer(modifier = GlanceModifier.width(8.0.dp))',
        );
      });

      test('a gap asking for no room at all is no Spacer', () {
        expect(const HWSizedBox().kotlinRendersNothing, isTrue);
        expect(const HWSizedBox().toKotlin(0, dataExpr: 'data'), isEmpty);
        expect(const HWSizedBox().kotlinImports, isEmpty);
        expect(const HWSizedBox.shrink().kotlinRendersNothing, isTrue);
        expect(
          const HWSizedBox.shrink().toKotlin(0, dataExpr: 'data'),
          isEmpty,
        );
      });

      test('a child rendering nothing leaves nothing to size', () {
        const empty = HWSizedBox.expand(
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(empty.kotlinRendersNothing, isTrue);
        expect(empty.toKotlin(0, dataExpr: 'data'), isEmpty);
        expect(empty.kotlinImports, isEmpty);
        expect(
          const HWSizedBox(width: 8, child: HWDataOnly([HWString('hidden')]))
              .toKotlin(0, dataExpr: 'data'),
          isEmpty,
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

      test('a stack collects the imports of each branch the box sizes', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            HWText.fixed('a'),
            HWSizedBox.expand(
              child: HWDataExists(
                data: HWString('flag'),
                whenPresent: HWText.fixed('on'),
                whenAbsent: HWImage(HWImageData('avatar')),
              ),
            ),
          ],
        );
        expect(
          column.kotlinImports,
          allOf(
            contains('import androidx.glance.layout.fillMaxWidth'),
            contains('import androidx.glance.text.Text'),
            contains('import androidx.glance.Image'),
          ),
        );
      });

      test('an axis left open asks for the room the child asks for there', () {
        const box =
            HWSizedBox(width: 50, child: HWAlign(child: HWText.fixed('b')));
        expect(box.kotlinRoomIn(HWAxis.horizontal).modifiers, [
          'fillMaxHeight()',
        ]);
        expect(box.kotlinRoomIn(HWAxis.vertical).modifiers, [
          'defaultWeight()',
        ]);
        expect(box.kotlinRoomIn(null).modifiers, ['fillMaxHeight()']);
        expect(
          const HWSizedBox(
            width: 50,
            height: 20,
            child: HWAlign(child: HWText.fixed('b')),
          ).kotlinRoomIn(HWAxis.vertical).modifiers,
          isEmpty,
        );
      });

      test('a stack in a row fills the height an open-height box asks for', () {
        expect(
          const HWRow(
            children: [
              HWText.fixed('a'),
              HWStack(
                children: [
                  HWSizedBox(
                    width: 50,
                    child: HWAlign(child: HWText.fixed('b')),
                  ),
                ],
              ),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          contains(
            '    Box(modifier = GlanceModifier.fillMaxHeight(), '
            'contentAlignment = Alignment.TopStart) {\n',
          ),
        );
      });

      test('a gap before it keeps the weight the child asks for', () {
        expect(
          const HWColumn(
            spacing: 8,
            children: [
              HWText.fixed('a'),
              HWSizedBox(width: 50, child: HWAlign(child: HWText.fixed('b'))),
            ],
          ).toKotlin(0, dataExpr: 'data'),
          contains(
            '    Box(modifier = GlanceModifier.defaultWeight()'
            '.padding(top = 8.0.dp)) {\n',
          ),
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
          node.children.first.kotlinImportsIn(HWAxis.horizontal),
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

    group('the size reaching a decoration', () {
      const blue = HWColor.fixed(0xFF3366FF);
      const black = HWColor.fixed(0xFF000000);
      const swiftBlue = '.background(Color(red: 0.2, green: 0.4, blue: 1.0, '
          'opacity: 1.0))';
      const swiftBlack = '.background(Color(red: 0.0, green: 0.0, blue: 0.0, '
          'opacity: 1.0))';
      const wide = '.frame(maxWidth: .infinity, alignment: .topLeading)';
      const text = 'style = TextStyle(color = GlanceTheme.colors.onSurface))';
      const blueA = HWColoredBox(color: blue, child: HWText.fixed('a'));
      const blackB = HWColoredBox(color: black, child: HWText.fixed('b'));
      const bordered = HWDecoratedBox(
        decoration: HWBoxDecoration(
          color: blue,
          border: HWBoxBorder(thickness: 1, color: black),
        ),
        child: HWText.fixed('a'),
      );

      group('through a widget picked at runtime', () {
        const conditional = HWSizedBox(
          width: double.infinity,
          child: HWBoolConditional(
            data: HWBool('flag', defaultValue: false),
            whenTrue: blueA,
            whenFalse: blackB,
          ),
        );

        test('frames each branch inside its decoration on iOS', () {
          expect(conditional.toSwift(0, dataExpr: 'data'), '''
if data.flag == true {
    Text("a")
    $wide
    $swiftBlue
} else {
    Text("b")
    $wide
    $swiftBlack
}''');
        });

        test('sizes each branch on Android as before', () {
          final kotlin = conditional.toKotlin(0, dataExpr: 'data');
          expect(
            kotlin,
            contains('Text(modifier = GlanceModifier.fillMaxWidth()'
                '.background(ColorProvider(day = Color(0xFF3366FF)'),
          );
          expect(
            kotlin,
            contains('Text(modifier = GlanceModifier.fillMaxWidth()'
                '.background(ColorProvider(day = Color(0xFF000000)'),
          );
        });

        test('frames a plain branch beside a decorated one on its own', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWDataExists(
                data: HWString('title'),
                whenPresent: blueA,
                whenAbsent: HWText.fixed('none'),
              ),
            ).toSwift(0, dataExpr: 'data'),
            contains('} else {\n    Text("none")\n    $wide\n}'),
          );
        });

        test('leaves a conditional without a decoration framed as one', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWBoolConditional(
                data: HWBool('flag', defaultValue: false),
                whenTrue: HWText.fixed('a'),
                whenFalse: HWText.fixed('b'),
              ),
            ).toSwift(0, dataExpr: 'data'),
            allOf(startsWith('Group {\n'), endsWith('}\n$wide')),
          );
        });

        test('frames every slot of a size adaptive', () {
          final swift = const HWSizedBox(
            width: double.infinity,
            child: HWSizeAdaptive(small: blueA, large: HWText.fixed('b')),
          ).toSwift(0, dataExpr: 'data');
          expect(swift, contains('    Text("a")\n    $wide\n    $swiftBlue\n'));
          expect(swift, contains('    Text("b")\n    $wide\n'));
          expect(swift, isNot(contains('}\n$wide')));
        });

        test('frames the iOS side of an adaptive inside its decoration', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWAdaptive(ios: blueA, android: HWText.fixed('b')),
            ).toSwift(0, dataExpr: 'data'),
            'Text("a")\n$wide\n$swiftBlue',
          );
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWAdaptive(ios: HWText.fixed('a'), android: blueA),
            ).toSwift(0, dataExpr: 'data'),
            'Text("a")\n$wide',
          );
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWAdaptive(ios: HWText.fixed('a'), android: blueA),
            ).toKotlin(0, dataExpr: 'data'),
            startsWith('Text(modifier = GlanceModifier.fillMaxWidth()'
                '.background('),
          );
        });
      });

      group('through a box leaving the axis open', () {
        test('fills the open axis around a padding on iOS', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWPadding(
                padding: HWEdgeInsets.all(8),
                child: HWSizedBox(height: 20, child: blueA),
              ),
            ).toSwift(0, dataExpr: 'data'),
            'Text("a")\n'
            '.frame(height: 20.0, alignment: .topLeading)\n'
            '$wide\n'
            '$swiftBlue\n'
            '.padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, '
            'trailing: 8.0))',
          );
        });

        test('fills the open axis inside a border on Android', () {
          expect(
            const HWSizedBox(
              width: double.infinity,
              child: HWSizedBox(height: 20, child: bordered),
            ).toKotlin(0, dataExpr: 'data'),
            'Box(\n'
            '    modifier = GlanceModifier.fillMaxWidth().height(20.0.dp)'
            '.background(ColorProvider(day = Color(0xFF000000), '
            'night = Color(0xFF000000))).cornerRadius(0.0.dp).padding(1.0.dp)\n'
            ') {\n'
            '    Box(\n'
            '        modifier = GlanceModifier.fillMaxSize()'
            '.background(ColorProvider(day = Color(0xFF3366FF), '
            'night = Color(0xFF3366FF))).cornerRadius(0.0.dp)\n'
            '    ) {\n'
            '        Text(modifier = GlanceModifier.fillMaxSize(), '
            'text = "a", $text\n'
            '    }\n'
            '}',
          );
        });

        test('fills the open axis on both platforms at once', () {
          const padded = HWSizedBox(
            width: double.infinity,
            child: HWPadding(
              padding: HWEdgeInsets.all(8),
              child: HWSizedBox(height: 20, child: bordered),
            ),
          );
          expect(
            padded.toSwift(0, dataExpr: 'data'),
            startsWith('Text("a")\n'
                '.frame(height: 20.0, alignment: .topLeading)\n$wide\n'),
          );
          expect(
            padded.toKotlin(0, dataExpr: 'data'),
            contains('Text(modifier = GlanceModifier.fillMaxSize(), '),
          );
        });

        test('keeps an axis both boxes set as it was', () {
          const nested = HWSizedBox(
            width: double.infinity,
            child: HWSizedBox(width: 40, child: blueA),
          );
          expect(
            nested.toSwift(0, dataExpr: 'data'),
            'Text("a")\n'
            '.frame(width: 40.0, alignment: .topLeading)\n'
            '$swiftBlue\n'
            '$wide',
          );
        });
      });

      test('decides whether a padding keeps its gap in a Box of its own', () {
        expect(
          const HWPadding(
            padding: HWEdgeInsets.all(8),
            child: HWSizedBox(width: 40, child: blueA),
          ).toKotlin(0, dataExpr: 'data'),
          startsWith('Box(modifier = GlanceModifier.padding('),
        );
        expect(
          const HWPadding(
            padding: HWEdgeInsets.all(8),
            child: HWSizedBox(
              width: 40,
              child: HWDecoratedBox(
                decoration: HWBoxDecoration(),
                child: HWText.fixed('a'),
              ),
            ),
          ).toKotlin(0, dataExpr: 'data'),
          startsWith('Text(modifier = GlanceModifier.padding('),
        );
      });
    });
  });
}
