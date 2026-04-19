import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWDataType', () {
    test('HWString returns correct types and default value', () {
      const type = HWString('test');
      expect(type.dartType, 'String');
      expect(type.kotlinType, 'String');
      expect(type.swiftType, 'String');
      expect(type.defaultValue, null);

      const typeWithDefault = HWString('test', defaultValue: 'hello');
      expect(typeWithDefault.defaultValue, 'hello');
    });

    test('HWInt returns correct types and default value', () {
      const type = HWInt('test');
      expect(type.dartType, 'int');
      expect(type.kotlinType, 'Int');
      expect(type.swiftType, 'Int');
      expect(type.defaultValue, null);

      const typeWithDefault = HWInt('test', defaultValue: 42);
      expect(typeWithDefault.defaultValue, 42);
    });

    test('HWDouble returns correct types and default value', () {
      const type = HWDouble('test');
      expect(type.dartType, 'double');
      expect(type.kotlinType, 'Double');
      expect(type.swiftType, 'Double');
      expect(type.defaultValue, null);

      const typeWithDefault = HWDouble('test', defaultValue: 3.14);
      expect(typeWithDefault.defaultValue, 3.14);
    });

    test('HWBool returns correct types and default value', () {
      const type = HWBool('test');
      expect(type.dartType, 'bool');
      expect(type.kotlinType, 'Boolean');
      expect(type.swiftType, 'Bool');
      expect(type.defaultValue, null);

      const typeWithDefault = HWBool('test', defaultValue: true);
      expect(typeWithDefault.defaultValue, true);
    });

    test('Equality works', () {
      expect(const HWString('a'), equals(const HWString('a')));
      expect(const HWString('a'), isNot(equals(const HWString('b'))));
      expect(const HWString('a'), isNot(equals(const HWInt('a'))));

      expect(const HWString('a', defaultValue: 'v1'),
          equals(const HWString('a', defaultValue: 'v1')));
      expect(const HWString('a', defaultValue: 'v1'),
          isNot(equals(const HWString('a', defaultValue: 'v2'))));
      expect(const HWString('a', defaultValue: 'v1'),
          isNot(equals(const HWString('a'))));
    });
  });
}
