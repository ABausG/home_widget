import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidget tree traversal', () {
    const leaf = HWText.fixed('leaf');
    const ios = HWText(HWString('ios'));
    const android = HWText(HWString('android'));

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
}
