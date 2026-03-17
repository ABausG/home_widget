import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWDataType', () {
    test('HWString returns correct types', () {
      const type = HWString('test');
      expect(type.dartType, 'String');
      expect(type.kotlinType, 'String');
      expect(type.swiftType, 'String');
    });

    test('HWInt returns correct types', () {
      const type = HWInt('test');
      expect(type.dartType, 'int');
      expect(type.kotlinType, 'Int');
      expect(type.swiftType, 'Int');
    });

    test('HWDouble returns correct types', () {
      const type = HWDouble('test');
      expect(type.dartType, 'double');
      expect(type.kotlinType, 'Double');
      expect(type.swiftType, 'Double');
    });

    test('HWBool returns correct types', () {
      const type = HWBool('test');
      expect(type.dartType, 'bool');
      expect(type.kotlinType, 'Boolean');
      expect(type.swiftType, 'Bool');
    });

    test('Equality works', () {
      expect(const HWString('a'), equals(const HWString('a')));
      expect(const HWString('a'), isNot(equals(const HWString('b'))));
      expect(const HWString('a'), isNot(equals(const HWInt('a'))));
    });
  });
}
