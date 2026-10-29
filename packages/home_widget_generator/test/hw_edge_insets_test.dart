import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWEdgeInsets', () {
    test('all and equality', () {
      const a = HWEdgeInsets.all(8);
      const b = HWEdgeInsets.all(8);
      const c = HWEdgeInsets.all(9);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('== compares all edge values when not identical (non-const instances)',
        () {
      final a = HWEdgeInsets.all(1.0);
      final b = HWEdgeInsets.only(left: 1, top: 1, right: 1, bottom: 1);
      expect(identical(a, b), isFalse);
      expect(a, b);
    });

    test('symmetric equality', () {
      const a = HWEdgeInsets.symmetric(vertical: 2, horizontal: 3);
      const b = HWEdgeInsets.only(left: 3, top: 2, right: 3, bottom: 2);
      expect(a, b);
    });

    test('only uses explicit edges', () {
      const a = HWEdgeInsets.only(left: 1, top: 2, right: 3, bottom: 4);
      const b = HWEdgeInsets.only(left: 1, top: 2, right: 3, bottom: 4);
      expect(a, b);
      expect(
        const HWEdgeInsets.only(left: 0, top: 2, right: 3, bottom: 4),
        isNot(a),
      );
    });
  });
}
