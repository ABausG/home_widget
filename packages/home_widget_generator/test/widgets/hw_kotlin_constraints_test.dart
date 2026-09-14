import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWKotlinConstraints', () {
    test('starts at the size of the widget itself', () {
      expect(
        HWKotlinConstraints.widget.kotlinMaxWidth,
        'LocalSize.current.width.value',
      );
      expect(
        HWKotlinConstraints.widget.kotlinMaxHeight,
        'LocalSize.current.height.value',
      );
    });

    test('takes what an ancestor claimed off the widget size', () {
      const constraints = HWKotlinConstraints(
        horizontalInset: 12,
        verticalInset: 7.5,
      );
      expect(
        constraints.kotlinMaxWidth,
        'maxOf(0f, LocalSize.current.width.value - 12f)',
      );
      expect(
        constraints.kotlinMaxHeight,
        'maxOf(0f, LocalSize.current.height.value - 7.5f)',
      );
    });

    test('adds up what each ancestor deflates it by', () {
      final constraints = HWKotlinConstraints.widget
          .deflate(horizontal: 4, vertical: 2)
          .deflate(horizontal: 6);

      expect(
        constraints.kotlinMaxWidth,
        'maxOf(0f, LocalSize.current.width.value - 10f)',
      );
      expect(
        constraints.kotlinMaxHeight,
        'maxOf(0f, LocalSize.current.height.value - 2f)',
      );
    });
  });
}
