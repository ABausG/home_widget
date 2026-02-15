import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWText', () {
    test('fixed constructor is const', () {
      const text = HWText.fixed('Hello');
      expect(text, isA<HWText>());
      expect(text, isA<HWWidget>());
    });

    test('data constructor is const', () {
      const ref = HWDataRef<String>('key');
      const text = HWText.data(ref);
      expect(text, isA<HWText>());
      expect(text, isA<HWWidget>());
    });
  });
}
