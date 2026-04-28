import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  test('HomeWidgetInteractivityConfig equality and hashCode', () {
    final sameA = HomeWidgetInteractivityConfig(
      import: 'a.dart',
      callback: 'cb',
    );
    final sameB = HomeWidgetInteractivityConfig(
      import: 'a.dart',
      callback: 'cb',
    );
    expect(identical(sameA, sameB), isFalse);
    expect(sameA, sameB);
    expect(sameA.hashCode, sameB.hashCode);

    final x1 = HomeWidgetInteractivityConfig(
      import: 'a.dart',
      callback: 'cb1',
    );
    final y1 = HomeWidgetInteractivityConfig(
      import: 'a.dart',
      callback: 'cb2',
    );
    expect(x1, isNot(equals(y1)));
    expect(x1.hashCode, isNot(y1.hashCode));
  });
}
