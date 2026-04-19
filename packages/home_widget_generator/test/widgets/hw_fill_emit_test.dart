import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidget.toKotlin', () {
    test('HWFill emits fillMaxSize', () {
      final node = HWFill(child: HWText.fixed('a'));
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        'Text(modifier = GlanceModifier.fillMaxSize(), text = "a")',
      );
    });
  });

  group('HWWidget.toSwift', () {
    test('HWFill emits frame max', () {
      final node = HWFill(child: HWText.fixed('a'));
      final result = node.toSwift(0, dataExpr: 'data');
      expect(
        result,
        'Text("a")\n.frame(maxWidth: .infinity, maxHeight: .infinity)',
      );
    });
  });
}
