import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWText', () {
    test('fixed constructor is const', () {
      const text = HWText.fixed('Hello');
      expect(text, isA<HWText>());
      expect(text, isA<HWWidget>());
    });

    test('data type constructor is const', () {
      const text = HWText(HWString('key'));
      expect(text, isA<HWText>());
      expect(text, isA<HWWidget>());
    });
  });
}
