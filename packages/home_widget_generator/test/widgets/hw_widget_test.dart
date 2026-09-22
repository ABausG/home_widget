import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  const leaf = HWText.fixed('leaf');
  const ios = HWText(HWString('ios'));
  const android = HWText(HWString('android'));

  group('HWWidget tree traversal', () {
    test('a leaf has no child widgets', () {
      expect(leaf.childWidgets, isEmpty);
      expect(leaf.descendants, [leaf]);
    });

    test('a single-child widget exposes its child', () {
      const padding = HWPadding(
        child: leaf,
        padding: HWEdgeInsets.all(4),
      );
      expect(padding.childWidgets, [leaf]);
      expect(padding.descendants, [padding, leaf]);
    });

    test('a multi-child widget exposes its children', () {
      const column = HWColumn(children: [leaf, ios]);
      expect(column.childWidgets, [leaf, ios]);
      expect(column.descendants, [column, leaf, ios]);
    });

    test('an adaptive widget exposes both platform subtrees', () {
      const adaptive = HWAdaptive(ios: ios, android: android);
      expect(adaptive.childWidgets, [ios, android]);
      expect(adaptive.descendants, [adaptive, ios, android]);
    });

    test('descendants walk nested containers in render order', () {
      const tree = HWColumn(
        children: [
          HWPadding(
            child: HWAdaptive(ios: ios, android: android),
            padding: HWEdgeInsets.all(2),
          ),
          leaf,
        ],
      );
      final padding = tree.children.first as HWPadding;
      final adaptive = padding.child as HWAdaptive;
      expect(
        tree.descendants,
        [tree, padding, adaptive, ios, android, leaf],
      );
    });
  });

  group('HWWidget Glance room', () {
    const spread = HWColumn(
      mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      children: [HWText.fixed('a')],
    );
    const color = HWFixedColor(0xFF00FF00);

    List<String> roomIn(HWWidget widget, HWAxis? axis) =>
        widget.kotlinRoomIn(axis).modifiers;

    test('a stack spreading its children takes a weight along its own axis',
        () {
      expect(roomIn(spread, HWAxis.vertical), ['defaultWeight()']);
      expect(roomIn(spread, HWAxis.horizontal), ['fillMaxHeight()']);
      expect(roomIn(spread, null), ['fillMaxHeight()']);

      const row = HWRow(
        mainAxisAlignment: HWMainAxisAlignment.center,
        children: [HWText.fixed('a')],
      );
      expect(roomIn(row, HWAxis.horizontal), ['defaultWeight()']);
      expect(roomIn(row, HWAxis.vertical), ['fillMaxWidth()']);
    });

    test('a stack hugging its children asks for nothing', () {
      expect(
        roomIn(const HWColumn(children: [leaf]), HWAxis.vertical),
        isEmpty,
      );
      expect(
        roomIn(
          const HWRow(
            mainAxisAlignment: HWMainAxisAlignment.start,
            children: [leaf],
          ),
          HWAxis.horizontal,
        ),
        isEmpty,
      );
      expect(roomIn(leaf, HWAxis.vertical), isEmpty);
    });

    test('an expanded box shares the axis it sits along by weight', () {
      const expanded = HWSizedBox.expand(child: spread);
      expect(
        roomIn(expanded, HWAxis.vertical),
        ['defaultWeight()', 'fillMaxWidth()'],
      );
      expect(
        roomIn(expanded, HWAxis.horizontal),
        ['defaultWeight()', 'fillMaxHeight()'],
      );
      expect(roomIn(expanded, null), ['fillMaxSize()']);
    });

    test('a size in pixels is no room of its own', () {
      expect(
        roomIn(const HWSizedBox(width: 8, height: 8, child: spread), null),
        isEmpty,
      );
      expect(
        roomIn(
          const HWSizedBox(width: 8, height: double.infinity, child: spread),
          HWAxis.vertical,
        ),
        ['defaultWeight()'],
      );
    });

    test('wrappers injecting into the child ask for its room', () {
      expect(
        roomIn(
          const HWPadding(padding: HWEdgeInsets.all(4), child: spread),
          HWAxis.vertical,
        ),
        ['defaultWeight()'],
      );
      expect(
        roomIn(
          const HWColoredBox(color: color, child: spread),
          HWAxis.vertical,
        ),
        ['defaultWeight()'],
      );
      expect(
        roomIn(
          const HWDecoratedBox(
            decoration: HWBoxDecoration(color: color),
            child: spread,
          ),
          HWAxis.vertical,
        ),
        ['defaultWeight()'],
      );
    });

    test("a border's Box asks for no room of its own", () {
      const bordered = HWDecoratedBox(
        decoration: HWBoxDecoration(
          border: HWBoxBorder(thickness: 1, color: color),
        ),
        child: spread,
      );
      expect(roomIn(bordered, HWAxis.vertical), isEmpty);
    });

    test('a conditional or a size-adaptive leaves the room to each branch', () {
      const conditional = HWDataExists(
        data: HWString('maybe'),
        whenPresent: spread,
        whenAbsent: HWSizedBox.expand(child: leaf),
      );
      expect(roomIn(conditional, HWAxis.vertical), isEmpty);
      final branches = const HWColumn(
        spacing: 8,
        children: [ios, conditional],
      ).toKotlin(0, dataExpr: 'data');
      expect(
        branches,
        contains(
          '        Column(modifier = GlanceModifier.padding(top = 8.0.dp)'
          '.defaultWeight(), ',
        ),
      );
      expect(
        branches,
        contains(
          '        Text(modifier = GlanceModifier.padding(top = 8.0.dp)'
          '.fillMaxWidth().defaultWeight(), text = "leaf", ',
        ),
      );
      expect(branches, isNot(contains('Box(')));

      const adaptive = HWSizeAdaptive(small: leaf, large: spread);
      expect(roomIn(adaptive, HWAxis.vertical), isEmpty);
      final slots = const HWColumn(
        spacing: 8,
        children: [ios, adaptive],
      ).toKotlin(0, dataExpr: 'data');
      expect(
        slots,
        contains(
          '            Column(modifier = GlanceModifier.padding(top = 8.0.dp)'
          '.defaultWeight(), ',
        ),
      );
      expect(
        slots,
        contains(
          '            Text(modifier = GlanceModifier.padding(top = 8.0.dp), '
          'text = "leaf", ',
        ),
      );
    });

    test('an adaptive asks for what its Android side does', () {
      expect(
        roomIn(const HWAdaptive(ios: leaf, android: spread), HWAxis.vertical),
        ['defaultWeight()'],
      );
      expect(
        roomIn(const HWAdaptive(ios: spread, android: leaf), HWAxis.vertical),
        isEmpty,
      );
    });
  });

  group('HWWidget Glance padding', () {
    const color = HWFixedColor(0xFF00FF00);
    const icon = HWIcon.glyph(0xe800, font: HWIconFont(family: 'Icons'));

    test('adds room around a view that draws neither background nor size', () {
      expect(leaf.kotlinPaddingAddsRoom, isTrue);
      expect(const HWColumn(children: [leaf]).kotlinPaddingAddsRoom, isTrue);
      expect(
        const HWImage(HWImageData('avatar'), width: 8).kotlinPaddingAddsRoom,
        isTrue,
      );
      expect(
        const HWPadding(padding: HWEdgeInsets.all(4), child: leaf)
            .kotlinPaddingAddsRoom,
        isTrue,
      );
      expect(
        const HWSizedBox.expand(child: leaf).kotlinPaddingAddsRoom,
        isTrue,
      );
      expect(
        const HWDecoratedBox(decoration: HWBoxDecoration(), child: leaf)
            .kotlinPaddingAddsRoom,
        isTrue,
      );
    });

    test('is covered by a background or a border', () {
      expect(
        const HWColoredBox(color: color, child: leaf).kotlinPaddingAddsRoom,
        isFalse,
      );
      expect(
        const HWDecoratedBox(
          decoration: HWBoxDecoration(color: color),
          child: leaf,
        ).kotlinPaddingAddsRoom,
        isFalse,
      );
      expect(
        const HWDecoratedBox(
          decoration: HWBoxDecoration(
            border: HWBoxBorder(thickness: 1, color: color),
          ),
          child: leaf,
        ).kotlinPaddingAddsRoom,
        isFalse,
      );
      expect(
        const HWPadding(
          padding: HWEdgeInsets.all(4),
          child: HWColoredBox(color: color, child: leaf),
        ).kotlinPaddingAddsRoom,
        isFalse,
      );
    });

    test('is given up by the fixed size of an icon', () {
      expect(icon.kotlinPaddingAddsRoom, isFalse);
      expect(
        const HWSizedBox.expand(child: icon).kotlinPaddingAddsRoom,
        isFalse,
      );
      expect(
        const HWSizedBox(width: 8, child: leaf).kotlinPaddingAddsRoom,
        isFalse,
      );
    });

    test('is taken by each branch Android may render on its own', () {
      const mixed = HWDataExists(
        data: HWString('maybe'),
        whenPresent: leaf,
        whenAbsent: icon,
      );
      final branches = const HWColumn(
        spacing: 8,
        children: [ios, mixed],
      ).toKotlin(0, dataExpr: 'data');
      expect(
        branches,
        contains(
          '    if (data.maybe != null) {\n'
          '        Text(modifier = GlanceModifier.padding(top = 8.0.dp), '
          'text = "leaf", ',
        ),
      );
      expect(
        branches,
        contains(
          '    } else {\n'
          '        Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {\n'
          '            Image(modifier = GlanceModifier.size(24.dp), ',
        ),
      );

      final slots = const HWColumn(
        spacing: 8,
        children: [ios, HWSizeAdaptive(small: leaf, large: icon)],
      ).toKotlin(0, dataExpr: 'data');
      expect(
        slots,
        contains(
          '            Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {\n'
          '                Image(modifier = GlanceModifier.size(24.dp), ',
        ),
      );
      expect(
        slots,
        contains(
          '            Text(modifier = GlanceModifier.padding(top = 8.0.dp), '
          'text = "leaf", ',
        ),
      );

      expect(
        const HWAdaptive(ios: leaf, android: icon).kotlinPaddingAddsRoom,
        isFalse,
      );
      expect(
        const HWAdaptive(ios: icon, android: leaf).kotlinPaddingAddsRoom,
        isTrue,
      );
    });
  });

  group('HWWidget rendering nothing', () {
    const dataOnly = HWDataOnly([HWString('id')]);

    test('only a data-only widget renders nothing', () {
      expect(dataOnly.swiftRendersNothing, isTrue);
      expect(dataOnly.kotlinRendersNothing, isTrue);
      expect(leaf.swiftRendersNothing, isFalse);
      expect(leaf.kotlinRendersNothing, isFalse);
    });

    test('an adaptive renders nothing on the platform of a data-only side', () {
      const iosOnly = HWAdaptive(ios: leaf, android: dataOnly);
      expect(iosOnly.swiftRendersNothing, isFalse);
      expect(iosOnly.kotlinRendersNothing, isTrue);
      const androidOnly = HWAdaptive(ios: dataOnly, android: leaf);
      expect(androidOnly.swiftRendersNothing, isTrue);
      expect(androidOnly.kotlinRendersNothing, isFalse);
    });
  });

  group('HWWidget clipping a SwiftUI frame', () {
    const stack = HWStack(children: [leaf]);

    test('only a widget clipping its own bounds asks for it', () {
      expect(leaf.swiftClipsFrame, isFalse);
      expect(stack.swiftClipsFrame, isTrue);
      expect(
        const HWStack(fit: HWStackFit.expand, children: [leaf]).swiftClipsFrame,
        isTrue,
      );
    });

    test('a single-child wrapper asks for whatever its child does', () {
      expect(
        const HWPadding(padding: HWEdgeInsets.all(4), child: leaf)
            .swiftClipsFrame,
        isFalse,
      );
      expect(
        const HWPadding(padding: HWEdgeInsets.all(4), child: stack)
            .swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWColoredBox(color: HWColor.fixed(0xFF000000), child: stack)
            .swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWDecoratedBox(
          decoration: HWBoxDecoration(color: HWColor.fixed(0xFF000000)),
          child: stack,
        ).swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWDecoratedBox(
          decoration: HWBoxDecoration(
            border: HWBoxBorder(
              thickness: 1,
              color: HWColor.fixed(0xFF000000),
            ),
          ),
          child: stack,
        ).swiftClipsFrame,
        isFalse,
      );
      expect(const HWAlign(child: stack).swiftClipsFrame, isTrue);
      expect(const HWAlign(child: leaf).swiftClipsFrame, isFalse);
    });

    test('a sized box asks for it for its child, a gap for nothing', () {
      expect(const HWSizedBox(child: stack).swiftClipsFrame, isTrue);
      expect(const HWSizedBox(child: leaf).swiftClipsFrame, isFalse);
      expect(const HWSizedBox(width: 8).swiftClipsFrame, isFalse);
    });

    test('a conditional asks for it while either branch does', () {
      expect(
        const HWDataExists(
          data: HWBool('flag'),
          whenPresent: stack,
          whenAbsent: leaf,
        ).swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWDataExists(
          data: HWBool('flag'),
          whenPresent: leaf,
          whenAbsent: stack,
        ).swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWDataExists(
          data: HWBool('flag'),
          whenPresent: leaf,
          whenAbsent: leaf,
        ).swiftClipsFrame,
        isFalse,
      );
    });

    test('an adaptive asks for what its iOS side does', () {
      expect(
        const HWAdaptive(ios: stack, android: leaf).swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWAdaptive(ios: leaf, android: stack).swiftClipsFrame,
        isFalse,
      );
    });

    test('a size adaptive asks for it while any slot does', () {
      expect(
        const HWSizeAdaptive(small: stack, large: leaf).swiftClipsFrame,
        isTrue,
      );
      expect(
        const HWSizeAdaptive(small: leaf, large: leaf).swiftClipsFrame,
        isFalse,
      );
    });
  });
}
