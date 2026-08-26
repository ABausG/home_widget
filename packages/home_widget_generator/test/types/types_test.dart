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

  group('codegen default literals', () {
    test('HWString emits a quoted literal only when a default is set', () {
      expect(const HWString('k').codegenKotlinDefaultLiteral(), isNull);
      expect(const HWString('k').codegenSwiftDefaultLiteral(), isNull);
      expect(
        const HWString('k', defaultValue: 'hi').codegenKotlinDefaultLiteral(),
        '"hi"',
      );
      expect(
        const HWString('k', defaultValue: 'hi').codegenSwiftDefaultLiteral(),
        '"hi"',
      );
    });

    test('HWString escapes the default per target language', () {
      const tricky = HWString('k', defaultValue: r'a"b$c');
      // Kotlin interpolates on `$`, Swift does not.
      expect(tricky.codegenKotlinDefaultLiteral(), r'"a\"b\$c"');
      expect(tricky.codegenSwiftDefaultLiteral(), r'"a\"b$c"');
    });

    test('HWInt emits a bare literal or null', () {
      expect(const HWInt('k').codegenKotlinDefaultLiteral(), isNull);
      expect(const HWInt('k').codegenSwiftDefaultLiteral(), isNull);
      expect(
        const HWInt('k', defaultValue: 42).codegenKotlinDefaultLiteral(),
        '42',
      );
      expect(
        const HWInt('k', defaultValue: 42).codegenSwiftDefaultLiteral(),
        '42',
      );
      // Zero is a real default, not an absent one.
      expect(
        const HWInt('k', defaultValue: 0).codegenKotlinDefaultLiteral(),
        '0',
      );
    });

    test('HWDouble emits a bare literal or null', () {
      expect(const HWDouble('k').codegenKotlinDefaultLiteral(), isNull);
      expect(const HWDouble('k').codegenSwiftDefaultLiteral(), isNull);
      expect(
        const HWDouble('k', defaultValue: 1.5).codegenKotlinDefaultLiteral(),
        '1.5',
      );
      expect(
        const HWDouble('k', defaultValue: 1.5).codegenSwiftDefaultLiteral(),
        '1.5',
      );
    });

    test('HWBool emits a bare literal or null', () {
      expect(const HWBool('k').codegenKotlinDefaultLiteral(), isNull);
      expect(const HWBool('k').codegenSwiftDefaultLiteral(), isNull);
      expect(
        const HWBool('k', defaultValue: true).codegenKotlinDefaultLiteral(),
        'true',
      );
      // False is a real default, not an absent one.
      expect(
        const HWBool('k', defaultValue: false).codegenSwiftDefaultLiteral(),
        'false',
      );
    });

    test('HWJson reports the literal of its leaf, however deeply nested', () {
      expect(
        const HWJson('root', HWInt('n', defaultValue: 7))
            .codegenKotlinDefaultLiteral(),
        '7',
      );
      expect(
        const HWJson('root', HWJson('mid', HWString('s', defaultValue: 'x')))
            .codegenSwiftDefaultLiteral(),
        '"x"',
      );
      expect(
        const HWJson('root', HWInt('n')).codegenKotlinDefaultLiteral(),
        isNull,
      );
    });
  });

  group('HWJson native plumbing', () {
    const json = HWJson('payload', HWInt('count', defaultValue: 3));

    test('is stored as a JSON string on both platforms', () {
      expect(json.kotlinType, 'String');
      expect(json.swiftType, 'String');
      expect(
        json.androidReadValue(store: 'prefs', key: 'p.payload'),
        'prefs.getString("p.payload", null)',
      );
      expect(
        json.iosReadValue(store: 'defaults', key: 'p.payload'),
        'defaults?.string(forKey: "p.payload")',
      );
    });

    test('stringification delegates to the leaf type', () {
      expect(
        json.androidToString(outerValue: 'v', innerValue: 'v'),
        r'(v?.toString() ?: "0")',
      );
      expect(
        json.iosToString(outerValue: 'v', innerValue: 'v'),
        r'v != nil ? "\(v)" : "0"',
      );
    });

    test('leafType and pathSegments walk through nested wrappers', () {
      const nested = HWJson('a', HWJson('b', HWString('c')));
      expect(nested.leafType, const HWString('c'));
      expect(nested.pathSegments, ['b', 'c']);
      expect(json.leafType, const HWInt('count', defaultValue: 3));
      expect(json.pathSegments, ['count']);
    });

    test('kotlin glance text applies the leaf default before stringifying', () {
      expect(
        json.kotlinGlanceJsonTextInterpolation('widgetData'),
        '((widgetData.payload?.count ?: 3)?.toString() ?: "0")',
      );
    });

    test('swift glance text describes non-string leaves', () {
      final swift = json.swiftGlanceJsonTextInterpolation('entry.data');
      expect(swift, startsWith('String(describing: '));
      expect(swift, contains('entry.data.payload?.count'));
      expect(swift, contains('?? (3)'));
    });

    test('swift glance text keeps string leaves quoted instead of described',
        () {
      const stringJson =
          HWJson('payload', HWString('label', defaultValue: 'x'));
      final swift = stringJson.swiftGlanceJsonTextInterpolation('entry.data');
      expect(swift, isNot(contains('String(describing:')));
      expect(swift, contains('entry.data.payload?.label'));
      // Falls through iosToString, which supplies the empty-string fallback.
      expect(swift, endsWith(' ?? ""'));
    });

    test('read expressions omit the elvis when the leaf has no default', () {
      const noDefault = HWJson('payload', HWInt('count'));
      expect(
        noDefault.kotlinReadExpr('widgetData'),
        'widgetData.payload?.count',
      );
      expect(
        noDefault.swiftReadExpr('entry.data'),
        'entry.data.payload?.count',
      );
    });

    test('hashCode agrees with == for structurally equal instances', () {
      final a = HWJson('root', const HWString('a'));
      final b = HWJson('root', const HWString('a'));
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.hashCode, isNot(HWJson('root', const HWString('b')).hashCode));
    });
  });
}
