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

    test('HWJson wraps child field metadata and accessors', () {
      const type = HWJson('fileKey', HWBool('flag', defaultValue: false));
      expect(type.dartType, 'Map<String, dynamic>');
      expect(type.defaultValue, false);
      expect(type.swiftAccess('entry.data'), 'entry.data.fileKey?.flag');
      expect(type.kotlinAccess('widgetData'), 'widgetData.fileKey?.flag');
    });

    test('Equality works', () {
      expect(const HWString('a'), equals(const HWString('a')));
      expect(const HWString('a'), isNot(equals(const HWString('b'))));
      expect(const HWString('a'), isNot(equals(const HWInt('a'))));

      expect(
        const HWString('a', defaultValue: 'v1'),
        equals(const HWString('a', defaultValue: 'v1')),
      );
      expect(
        const HWString('a', defaultValue: 'v1'),
        isNot(equals(const HWString('a', defaultValue: 'v2'))),
      );
      expect(
        const HWString('a', defaultValue: 'v1'),
        isNot(equals(const HWString('a'))),
      );
      expect(
        const HWJson('root', HWString('a')),
        equals(const HWJson('root', HWString('a'))),
      );
      expect(
        const HWJson('root', HWString('a')),
        isNot(equals(const HWJson('root', HWString('b')))),
      );
      expect(
        const HWJson('root', HWString('a')),
        isNot(equals(const HWJson('root', HWJson('a', HWString('b'))))),
      );
    });

    test('HWInt and HWDouble equality includes defaultValue', () {
      expect(const HWInt('k'), equals(const HWInt('k')));
      expect(
        const HWInt('k', defaultValue: 1),
        equals(const HWInt('k', defaultValue: 1)),
      );
      expect(
        const HWInt('k'),
        isNot(equals(const HWInt('k', defaultValue: 1))),
      );

      expect(const HWDouble('d'), equals(const HWDouble('d')));
      expect(
        const HWDouble('d', defaultValue: 1.0),
        equals(const HWDouble('d', defaultValue: 1.0)),
      );
    });

    test('HWString escapes special characters in defaultValue', () {
      const cases = <(String input, String kotlinEscaped, String swiftEscaped)>[
        (r'hello"world', r'hello\"world', r'hello\"world'),
        (r'back\slash', r'back\\slash', r'back\\slash'),
        (r'dollar$sign', r'dollar\$sign', r'dollar$sign'),
      ];

      for (final (input, kotlinEscaped, swiftEscaped) in cases) {
        final type = HWString('key', defaultValue: input);
        expect(
          type.androidReadValue(store: 'prefs', key: 'k'),
          'prefs.getString("k", "$kotlinEscaped")',
        );
        expect(
          type.iosReadValue(store: 'defaults', key: 'k'),
          '(defaults?.string(forKey: "k") ?? "$swiftEscaped")',
        );
      }
    });

    test('androidReadValue and iosReadValue (with and without defaultValue)',
        () {
      const store = 'prefs';
      const key = 'full.key';
      const s = HWString('a');
      expect(
        s.androidReadValue(store: store, key: key),
        'prefs.getString("full.key", null)',
      );
      expect(
        const HWString('a', defaultValue: 'd')
            .androidReadValue(store: store, key: key),
        'prefs.getString("full.key", "d")',
      );
      expect(
        s.iosReadValue(store: 'defaults', key: key),
        'defaults?.string(forKey: "full.key")',
      );
      expect(
        const HWString('a', defaultValue: 'd')
            .iosReadValue(store: 'defaults', key: key),
        '(defaults?.string(forKey: "full.key") ?? "d")',
      );
      for (final t in <HWDataType<dynamic>>[
        const HWInt('i'),
        const HWInt('i2', defaultValue: 1),
        const HWDouble('d'),
        const HWDouble('d2', defaultValue: 1.2),
        const HWBool('b'),
        const HWBool('b2', defaultValue: true),
      ]) {
        t.androidReadValue(store: 'p', key: 'k');
        t.iosReadValue(store: 'd', key: 'k');
      }
    });

    test('androidToString and iosToString', () {
      const o = 'data.x';
      const i = 'data.x';
      for (final t in <(HWDataType<dynamic>, String, String)>[
        (const HWString('k'), r'data.x ?: ""', r'data.x ?? ""'),
        (
          const HWInt('k'),
          r'(data.x?.toString() ?: "0")',
          r'data.x != nil ? "\(data.x)" : "0"'
        ),
        (
          const HWDouble('k'),
          r'(data.x?.toString() ?: "0.0")',
          r'data.x != nil ? "\(data.x)" : "0.0"'
        ),
        (
          const HWBool('k'),
          r'(data.x?.toString() ?: "false")',
          r'data.x != nil ? "\(data.x)" : "false"'
        ),
      ]) {
        expect(
          t.$1.androidToString(outerValue: o, innerValue: i),
          t.$2,
        );
        expect(
          t.$1.iosToString(outerValue: o, innerValue: i),
          t.$3,
        );
      }
    });
  });
}
