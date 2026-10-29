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
      expect(type.kotlinType, 'Long');
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

    test('a plain type passes through the generated Dart API unchanged', () {
      const type = HWString('label');
      expect(type.dartApiType('Forecast'), 'String');
      expect(type.dartGetDataType('Forecast'), 'String');
      expect(type.dartDecode('raw', 'Forecast'), 'raw');
      expect(type.dartEncode('value', 'Forecast'), isNull);

      const number = HWInt('count');
      expect(number.dartApiType('Forecast'), 'int');
      expect(number.dartGetDataType('Forecast'), 'int');
      expect(number.dartDecode('raw', 'Forecast'), 'raw');
      expect(number.dartEncode('value', 'Forecast'), isNull);
    });

    test('HWDateTime returns correct types and has no default value', () {
      const type = HWDateTime('when');
      expect(type.dartType, 'DateTime');
      expect(type.kotlinType, 'java.util.Date');
      expect(type.swiftType, 'Date');
      expect(type.defaultValue, isNull);
      expect(type.codegenKotlinDefaultLiteral(), isNull);
      expect(type.codegenSwiftDefaultLiteral(), isNull);
    });

    test('HWDateTime parses the stored ISO string on read', () {
      const type = HWDateTime('when');
      expect(
        type.iosReadValue(store: 'defaults', key: 'p.when'),
        'hwParseIsoDate(defaults?.string(forKey: "p.when") ?? "")',
      );
      expect(
        type.androidReadValue(store: 'prefs', key: 'p.when'),
        'hwParseIsoDate(prefs.getString("p.when", null) ?: "")',
      );
    });

    test('HWDateTime parses out of a timed entry and a JSON object', () {
      const type = HWDateTime('when');
      expect(
        type.iosTimedReadValue(valuesExpr: 'timedValues'),
        'hwParseIsoDate((timedValues["when"] as? String) ?? "")',
      );
      expect(
        type.androidTimedReadValue(valuesExpr: 'timedValues'),
        'hwParseIsoDate(if (timedValues.has("when") && '
        '!timedValues.isNull("when")) timedValues.optString("when") else "")',
      );
      expect(
        type.iosJsonReadValue(objExpr: 'values', key: 'start'),
        'hwParseIsoDate((values["start"] as? String) ?? "")',
      );
      expect(
        type.androidJsonReadValue(objExpr: 'values', key: 'start'),
        'hwParseIsoDate(if (values.has("start") && !values.isNull("start")) '
        'values.optString("start") else "")',
      );
    });

    test('HWDateTime stringifies raw, empty when absent', () {
      const type = HWDateTime('when');
      expect(
        type.iosToString(outerValue: 'd.when', innerValue: 'd.when!'),
        r'd.when != nil ? "\(d.when!)" : ""',
      );
      expect(
        type.androidToString(outerValue: 'd.when', innerValue: 'd.when'),
        '(d.when?.toString() ?: "")',
      );
    });

    test('HWTimedData wrapping an HWDateTime keeps the date contract', () {
      const type = HWTimedData(HWDateTime('when'));
      expect(type.swiftType, 'Date');
      expect(type.kotlinType, 'java.util.Date');
      expect(type.unwrapped, const HWDateTime('when'));
      expect(dateTimeLeafOf(type), const HWDateTime('when'));
    });

    test('leaf lookups find numbers and dates through every wrapper', () {
      expect(numberLeafOf(const HWInt('a')), const HWInt('a'));
      expect(
        numberLeafOf(const HWTimedData(HWDouble('a'))),
        const HWDouble('a'),
      );
      expect(
        numberLeafOf(const HWJson('p', HWJson('q', HWInt('a')))),
        const HWInt('a'),
      );
      expect(numberLeafOf(const HWString('a')), isNull);
      expect(numberLeafOf(const HWDateTime('a')), isNull);

      expect(dateTimeLeafOf(const HWDateTime('a')), const HWDateTime('a'));
      expect(
        dateTimeLeafOf(const HWJson('p', HWDateTime('a'))),
        const HWDateTime('a'),
      );
      expect(dateTimeLeafOf(const HWInt('a')), isNull);
    });

    test('HWJson wraps child field metadata and accessors', () {
      const type = HWJson('fileKey', HWBool('flag', defaultValue: false));
      expect(type.dartType, 'Map<String, dynamic>');
      expect(type.defaultValue, false);
      expect(type.swiftAccess('entry.data'), 'entry.data.fileKey?.flag');
      expect(type.kotlinAccess('widgetData'), 'widgetData.fileKey?.flag');
    });

    test('HWTimedData delegates to the wrapped data type', () {
      const wrapped = HWString('label', defaultValue: 'Sunny');
      const type = HWTimedData(wrapped);

      expect(type.key, 'label');
      expect(type.defaultValue, 'Sunny');
      expect(type.dartType, 'String');
      expect(type.kotlinType, 'String');
      expect(type.swiftType, 'String');
      expect(
        type.androidReadValue(store: 'prefs', key: 'k'),
        wrapped.androidReadValue(store: 'prefs', key: 'k'),
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'k'),
        wrapped.iosReadValue(store: 'defaults', key: 'k'),
      );
      expect(
        type.androidReadValue(store: 'prefs', key: 'k', preview: true),
        wrapped.androidReadValue(store: 'prefs', key: 'k', preview: true),
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'k', preview: true),
        wrapped.iosReadValue(store: 'defaults', key: 'k', preview: true),
      );
      expect(
        type.codegenKotlinFallbackLiteral(),
        wrapped.codegenKotlinFallbackLiteral(),
      );
      expect(
        type.codegenKotlinFallbackLiteral(preview: true),
        wrapped.codegenKotlinFallbackLiteral(preview: true),
      );
      expect(
        type.codegenSwiftFallbackLiteral(),
        wrapped.codegenSwiftFallbackLiteral(),
      );
      expect(
        type.codegenSwiftFallbackLiteral(preview: true),
        wrapped.codegenSwiftFallbackLiteral(preview: true),
      );
      expect(
        type.androidToString(outerValue: 'data.x', innerValue: 'data.x'),
        wrapped.androidToString(outerValue: 'data.x', innerValue: 'data.x'),
      );
      expect(
        type.iosToString(outerValue: 'data.x', innerValue: 'data.x'),
        wrapped.iosToString(outerValue: 'data.x', innerValue: 'data.x'),
      );
      expect(type.swiftAccess('entry.data'), 'entry.data.label');
      expect(type.kotlinAccess('widgetData'), 'widgetData.label');
    });

    test('HWTimedData hands back the getData type of the wrapped type', () {
      const wrapped = HWImageData('avatar');
      const type = HWTimedData(wrapped);

      expect(type.dartApiType('Weather'), wrapped.dartApiType('Weather'));
      expect(
        type.dartGetDataType('Weather'),
        wrapped.dartGetDataType('Weather'),
      );
      expect(type.dartGetDataType('Weather'), 'String');
      expect(
        type.dartGetDataType('Weather'),
        isNot(type.dartApiType('Weather')),
      );
    });

    test('HWTimedData delegates JSON accessors and read expressions', () {
      const wrapped =
          HWJson('weather', HWString('condition', defaultValue: 'x'));
      const type = HWTimedData(wrapped);

      expect(type.key, 'weather');
      expect(type.dartType, 'Map<String, dynamic>');
      expect(type.swiftAccess('entry.data'), wrapped.swiftAccess('entry.data'));
      expect(type.kotlinAccess('data'), wrapped.kotlinAccess('data'));
      expect(
        type.swiftReadExpr('entry.data'),
        wrapped.swiftReadExpr('entry.data'),
      );
      expect(type.kotlinReadExpr('data'), wrapped.kotlinReadExpr('data'));
    });

    test('HWTimedData exposes the native helpers of the wrapped type', () {
      const wrapped = HWJson('weather', HWString('condition'));
      expect(
        const HWTimedData(wrapped).nativeHelpers,
        wrapped.nativeHelpers,
      );
      expect(
        const HWTimedData(HWDateTime('when')).nativeHelpers,
        const HWDateTime('when').nativeHelpers,
      );
    });

    test('HWTimedData equality and hashCode are based on the wrapped type', () {
      expect(
        const HWTimedData(HWString('a')),
        equals(const HWTimedData(HWString('a'))),
      );
      expect(
        const HWTimedData(HWString('a')).hashCode,
        const HWTimedData(HWString('a')).hashCode,
      );
      expect(
        const HWTimedData(HWString('a')),
        isNot(equals(const HWTimedData(HWString('b')))),
      );
      expect(
        const HWTimedData(HWString('a')),
        isNot(equals(const HWTimedData(HWString('a', defaultValue: 'v')))),
      );
      expect(
        const HWTimedData(HWString('a')),
        isNot(equals(const HWString('a'))),
      );
      expect(
        const HWString('a'),
        isNot(equals(const HWTimedData(HWString('a')))),
      );
    });

    test('HWTimedData hashCode matches == across type arguments', () {
      const HWDataType<dynamic> dynamicallyTyped =
          HWTimedData<dynamic>(HWString('a'));
      const HWDataType<dynamic> stringTyped =
          HWTimedData<String>(HWString('a'));

      expect(dynamicallyTyped, equals(stringTyped));
      expect(dynamicallyTyped.hashCode, stringTyped.hashCode);
    });

    test('unwrapped returns the type itself except for HWTimedData', () {
      const plain = HWString('a');
      const json = HWJson('weather', HWString('condition'));

      expect(plain.unwrapped, same(plain));
      expect(json.unwrapped, same(json));
      expect(const HWTimedData(plain).unwrapped, same(plain));
      expect(const HWTimedData(json).unwrapped, same(json));
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

    test('doubles read Android preferences via raw bit decoding', () {
      expect(
        const HWDouble('d').androidReadValue(store: 'prefs', key: 'p.total'),
        'if (prefs.contains("p.total")) '
        'java.lang.Double.longBitsToDouble(prefs.getLong("p.total", 0L)) '
        'else null',
      );
      expect(
        const HWDouble('d', defaultValue: 1.5)
            .androidReadValue(store: 'prefs', key: 'p.total'),
        contains('else 1.5'),
      );
    });

    test('ints read Android preferences as Int, then as Long', () {
      expect(
        const HWInt('i').androidReadValue(store: 'prefs', key: 'p.count'),
        'if (prefs.contains("p.count")) '
        '(try { prefs.getInt("p.count", 0).toLong() } '
        'catch (_: ClassCastException) { prefs.getLong("p.count", 0L) }) '
        'else null',
      );
      expect(
        const HWInt('i', defaultValue: 7)
            .androidReadValue(store: 'prefs', key: 'p.count'),
        contains('else 7L'),
      );
    });

    test('androidToString and iosToString', () {
      const o = 'data.x';
      const i = 'data.x';
      for (final t in <(HWDataType<dynamic>, String, String)>[
        (const HWString('k'), r'data.x ?: ""', r'data.x ?? ""'),
        (
          const HWInt('k'),
          r'(data.x?.toString() ?: "")',
          r'data.x != nil ? "\(data.x)" : ""'
        ),
        (
          const HWInt('k', defaultValue: 3),
          r'(data.x?.toString() ?: "")',
          r'data.x != nil ? "\(data.x)" : ""'
        ),
        (
          const HWDouble('k'),
          r'(data.x?.toString() ?: "")',
          r'data.x != nil ? "\(data.x)" : ""'
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

    test('HWInt emits a Long literal or null', () {
      expect(const HWInt('k').codegenKotlinDefaultLiteral(), isNull);
      expect(const HWInt('k').codegenSwiftDefaultLiteral(), isNull);
      expect(
        const HWInt('k', defaultValue: 42).codegenKotlinDefaultLiteral(),
        '42L',
      );
      expect(
        const HWInt('k', defaultValue: 42).codegenSwiftDefaultLiteral(),
        '42',
      );
      // Zero is a real default, not an absent one.
      expect(
        const HWInt('k', defaultValue: 0).codegenKotlinDefaultLiteral(),
        '0L',
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

    test('the Dart literal quotes a string and prints everything else', () {
      expect(const HWString('k').codegenDartDefaultLiteral(), isNull);
      expect(
        const HWString('k', defaultValue: 'hi').codegenDartDefaultLiteral(),
        "'hi'",
      );
      expect(
        const HWInt('k', defaultValue: 42).codegenDartDefaultLiteral(),
        '42',
      );
      expect(
        const HWDouble('k', defaultValue: 1.5).codegenDartDefaultLiteral(),
        '1.5',
      );
      // False is a real default, not an absent one.
      expect(
        const HWBool('k', defaultValue: false).codegenDartDefaultLiteral(),
        'false',
      );
    });

    test('the Dart literal escapes what Dart reads as syntax', () {
      const tricky = HWString('k', defaultValue: r"a'b$c");
      expect(tricky.codegenDartDefaultLiteral(), r"'a\'b\$c'");
    });

    test('HWJson reports the literal of its leaf, however deeply nested', () {
      expect(
        const HWJson('root', HWInt('n', defaultValue: 7))
            .codegenKotlinDefaultLiteral(),
        '7L',
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
        '(v?.toString() ?: "")',
      );
      expect(
        json.iosToString(outerValue: 'v', innerValue: 'v'),
        r'v != nil ? "\(v)" : ""',
      );
    });

    test('leafType and pathSegments walk through nested wrappers', () {
      const nested = HWJson('a', HWJson('b', HWString('c')));
      expect(nested.leafType, const HWString('c'));
      expect(nested.pathSegments, ['b', 'c']);
      expect(json.leafType, const HWInt('count', defaultValue: 3));
      expect(json.pathSegments, ['count']);
    });

    test('kotlin glance text applies the leaf default', () {
      expect(
        json.kotlinGlanceJsonTextInterpolation('widgetData'),
        '(widgetData.payload?.count ?: 3L).toString()',
      );
    });

    test('kotlin glance text falls back when the leaf has no default', () {
      const noDefault = HWJson('payload', HWInt('count'));
      expect(
        noDefault.kotlinGlanceJsonTextInterpolation('widgetData'),
        '(widgetData.payload?.count?.toString() ?: "")',
      );
    });

    test('swift glance text falls back when a number leaf has no default', () {
      const noDefault = HWJson('payload', HWInt('count'));
      expect(
        noDefault.swiftGlanceJsonTextInterpolation('entry.data'),
        r'(entry.data.payload?.count).map { String(describing: $0) } ?? ""',
      );
    });

    test('swift glance text describes number leaves', () {
      expect(
        json.swiftGlanceJsonTextInterpolation('entry.data'),
        'String(describing: ((((entry.data.payload?.count) ?? (3)))))',
      );
    });

    test('glance text stringifies a date leaf raw', () {
      const dateJson = HWJson('payload', HWDateTime('when'));
      expect(
        dateJson.swiftGlanceJsonTextInterpolation('entry.data'),
        'String(describing: (entry.data.payload?.when))',
      );
      expect(
        dateJson.kotlinGlanceJsonTextInterpolation('widgetData'),
        '(widgetData.payload?.when?.toString() ?: "")',
      );
    });

    test('swift glance text keeps string leaves quoted instead of described',
        () {
      const stringJson =
          HWJson('payload', HWString('label', defaultValue: 'x'));
      final swift = stringJson.swiftGlanceJsonTextInterpolation('entry.data');
      expect(swift, isNot(contains('String(describing:')));
      expect(swift, contains('entry.data.payload?.label'));
      // The default already makes the read non-optional, so no further
      // coalesce is emitted on top of it.
      expect(swift, endsWith('?? ("x")))'));
    });

    test('swift glance text falls back when a string leaf has no default', () {
      const noDefault = HWJson('payload', HWString('label'));
      final swift = noDefault.swiftGlanceJsonTextInterpolation('entry.data');
      expect(swift, 'entry.data.payload?.label ?? ""');
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

    test('a localized leaf falls back through the locale resolver', () {
      const localized = HWJson(
        'profile',
        HWLocalizedString.resolved(
          'name',
          defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
          isConstant: false,
          defaultLocale: 'en',
        ),
      );

      expect(
        localized.kotlinReadExpr('widgetData'),
        '(widgetData.profile?.name ?: hwResolveLocalized(hwLocales, '
        'mapOf("en" to "Hello", "de" to "Hallo"), "en") ?: "Hello")',
      );
      expect(
        localized.swiftReadExpr('entry.data'),
        '((entry.data.profile?.name) ?? hwResolveLocalized(hwCurrentLocales(), '
        '["en": "Hello", "de": "Hallo"], baseLocale: "en") ?? "Hello")',
      );
      // No empty-string fallback is stacked on top of the chain.
      expect(
        localized.kotlinGlanceJsonTextInterpolation('widgetData'),
        localized.kotlinReadExpr('widgetData'),
      );
      expect(
        localized.swiftGlanceJsonTextInterpolation('entry.data'),
        localized.swiftReadExpr('entry.data'),
      );
      expect(localized.defaultValue, isNull);
    });

    test('kotlin glance text throws for an icon leaf with a default', () {
      const iconJson = HWJson(
        'payload',
        HWIconData.resolved(
          'mood',
          entries: [HWIconEntry('wbSunny', 0xE88A)],
          iconFont: HWIconFont(family: 'MaterialIcons'),
          defaultValue: 0xE88A,
        ),
      );
      expect(
        () => iconJson.kotlinGlanceJsonTextInterpolation('widgetData'),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('HWIconData cannot be rendered as text'),
          ),
        ),
      );
    });

    test('swift glance text throws for an icon leaf, with or without a default',
        () {
      const withDefault = HWJson(
        'payload',
        HWIconData.resolved(
          'mood',
          entries: [HWIconEntry('wbSunny', 0xE88A)],
          iconFont: HWIconFont(family: 'MaterialIcons'),
          defaultValue: 0xE88A,
        ),
      );
      const withoutDefault = HWJson(
        'payload',
        HWIconData.resolved(
          'mood',
          entries: [HWIconEntry('wbSunny', 0xE88A)],
          iconFont: HWIconFont(family: 'MaterialIcons'),
        ),
      );
      for (final json in [withDefault, withoutDefault]) {
        expect(
          () => json.swiftGlanceJsonTextInterpolation('entry.data'),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.toString(),
              'message',
              contains('HWIconData cannot be rendered as text'),
            ),
          ),
        );
      }
    });

    test('kotlin and swift glance text throw for an image leaf', () {
      const imageJson = HWJson('payload', HWImageData('avatar'));
      final throwsImageError = throwsA(
        isA<GeneratorError>().having(
          (e) => e.toString(),
          'message',
          contains('HWImageData cannot be rendered as text'),
        ),
      );
      expect(
        () => imageJson.kotlinGlanceJsonTextInterpolation('widgetData'),
        throwsImageError,
      );
      expect(
        () => imageJson.swiftGlanceJsonTextInterpolation('entry.data'),
        throwsImageError,
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

  group('HWLocalizedString timed read values', () {
    const translations = {'en': 'Hello', 'de': 'Hallo'};

    test('resolve out of the active timed entry', () {
      const localized = HWLocalizedString(
        'greeting',
        defaultTranslations: translations,
      );
      expect(
        localized.androidTimedReadValue(valuesExpr: 'timedValues'),
        'hwReadTimedLocalized(timedValues, "greeting", locales, '
        'mapOf("en" to "Hello", "de" to "Hallo"), "en")',
      );
      expect(
        localized.iosTimedReadValue(valuesExpr: 'timedValues'),
        'hwReadTimedLocalized(timedValues, "greeting", '
        '["en": "Hello", "de": "Hallo"], baseLocale: "en")',
      );
    });

    test('fall back to the stamped default locale', () {
      const localized = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: translations,
        isConstant: false,
        defaultLocale: 'de',
      );
      expect(
        localized.androidTimedReadValue(valuesExpr: 'entry'),
        'hwReadTimedLocalized(entry, "greeting", locales, '
        'mapOf("en" to "Hello", "de" to "Hallo"), "de")',
      );
      expect(
        localized.iosTimedReadValue(valuesExpr: 'entry'),
        'hwReadTimedLocalized(entry, "greeting", '
        '["en": "Hello", "de": "Hallo"], baseLocale: "de")',
      );
    });

    test('escape special characters in the translation map', () {
      const localized = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': r'a"b\c$d'},
      );
      expect(
        localized.androidTimedReadValue(valuesExpr: 'timedValues'),
        contains(r'mapOf("en" to "a\"b\\c\$d")'),
      );
      expect(
        localized.iosTimedReadValue(valuesExpr: 'timedValues'),
        contains(r'["en": "a\"b\\c$d"]'),
      );
    });
  });

  group('HWImageData', () {
    test('runtime image returns correct types and no default value', () {
      const type = HWImageData('avatar');
      expect(type.key, 'avatar');
      expect(type.assetPath, isNull);
      expect(type.isAsset, isFalse);
      expect(type.dartType, 'String');
      expect(type.kotlinType, 'String');
      expect(type.swiftType, 'String');
      expect(type.defaultValue, isNull);
    });

    test('asset image derives its key from the asset path', () {
      const type = HWImageData.asset('assets/images/logo.png');
      expect(type.key, 'assetsImagesLogoPng');
      expect(type.assetPath, 'assets/images/logo.png');
      expect(type.isAsset, isTrue);
      expect(type.defaultValue, isNull);
    });

    group('package assets', () {
      test('effectiveAssetKey is null for runtime images', () {
        expect(const HWImageData('avatar').effectiveAssetKey, isNull);
      });

      test('effectiveAssetKey is the raw path without a package', () {
        const type = HWImageData.asset('assets/logo.png');
        expect(type.package, isNull);
        expect(type.effectiveAssetKey, 'assets/logo.png');
      });

      test('effectiveAssetKey prefixes the package', () {
        const type = HWImageData.asset('assets/logo.png', package: 'my_icons');
        expect(type.package, 'my_icons');
        expect(type.assetPath, 'assets/logo.png');
        expect(type.effectiveAssetKey, 'packages/my_icons/assets/logo.png');
      });

      test('the derived key includes the package prefix', () {
        expect(
          const HWImageData.asset('assets/logo.png', package: 'my_icons').key,
          'packagesMyIconsAssetsLogoPng',
        );
      });

      test('a manual packages/ path derives the same key', () {
        expect(
          const HWImageData.asset('packages/my_icons/assets/logo.png').key,
          const HWImageData.asset('assets/logo.png', package: 'my_icons').key,
        );
      });

      test('a bare packages/ path without a package stays valid', () {
        const type = HWImageData.asset('packages/my_icons/assets/logo.png');
        expect(type.effectiveAssetKey, 'packages/my_icons/assets/logo.png');
        expect(type.key, 'packagesMyIconsAssetsLogoPng');
      });

      test('throws when a packages/ path is combined with a package', () {
        const type = HWImageData.asset(
          'packages/my_icons/logo.png',
          package: 'my_icons',
        );
        expect(
          () => type.effectiveAssetKey,
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('packages/my_icons/packages/my_icons/logo.png'),
                contains('Drop the package parameter'),
              ),
            ),
          ),
        );
        expect(() => type.key, throwsA(isA<GeneratorError>()));
      });

      test('the package participates in equality', () {
        expect(
          const HWImageData.asset('assets/logo.png', package: 'my_icons'),
          const HWImageData.asset('assets/logo.png', package: 'my_icons'),
        );
        expect(
          const HWImageData.asset('assets/logo.png', package: 'my_icons')
              .hashCode,
          const HWImageData.asset('assets/logo.png', package: 'my_icons')
              .hashCode,
        );
        expect(
          const HWImageData.asset('assets/logo.png', package: 'my_icons'),
          isNot(const HWImageData.asset('assets/logo.png', package: 'other')),
        );
        expect(
          const HWImageData.asset('assets/logo.png', package: 'my_icons'),
          isNot(const HWImageData.asset('assets/logo.png')),
        );
        // Same derived key, different spelling of the same asset.
        expect(
          const HWImageData.asset('assets/logo.png', package: 'my_icons'),
          isNot(const HWImageData.asset('packages/my_icons/assets/logo.png')),
        );
      });
    });

    group('deriveKeyFromAssetPath', () {
      test('joins path segments in lower camel case', () {
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/logo.png'),
          'assetsLogoPng',
        );
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/images/dark/logo.png'),
          'assetsImagesDarkLogoPng',
        );
      });

      test('collapses runs of disallowed characters', () {
        expect(
          HWImageData.deriveKeyFromAssetPath('assets//my-logo_v2.png'),
          'assetsMyLogoV2Png',
        );
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/my logo (final).png'),
          'assetsMyLogoFinalPng',
        );
      });

      test('drops non-ASCII characters', () {
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/logö.png'),
          'assetsLogPng',
        );
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/日本/logo.png'),
          'assetsLogoPng',
        );
      });

      test('prefixes keys that would start with a digit', () {
        expect(
          HWImageData.deriveKeyFromAssetPath('2x/logo.png'),
          'image2xLogoPng',
        );
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/logo.png'),
          isNot(startsWith('image')),
        );
      });

      test('preserves existing camel case in segments', () {
        expect(
          HWImageData.deriveKeyFromAssetPath('assets/myLogo.png'),
          'assetsMyLogoPng',
        );
      });

      test('keeps distinct paths distinct', () {
        final keys = <String>{
          HWImageData.deriveKeyFromAssetPath('assets/a/logo.png'),
          HWImageData.deriveKeyFromAssetPath('assets/b/logo.png'),
          HWImageData.deriveKeyFromAssetPath('assets/logo.png'),
        };
        expect(keys, hasLength(3));
      });

      test('throws when the path has no ASCII letters or digits', () {
        expect(
          () => HWImageData.deriveKeyFromAssetPath('///'),
          throwsA(isA<GeneratorError>()),
        );
        expect(
          () => const HWImageData.asset('').key,
          throwsA(isA<GeneratorError>()),
        );
      });
    });

    test('read values are nullable with no default', () {
      const type = HWImageData('avatar');
      expect(
        type.androidReadValue(store: 'prefs', key: 'full.avatar'),
        'prefs.getString("full.avatar", null)',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'full.avatar'),
        'defaults?.string(forKey: "full.avatar")',
      );
    });

    test('access and read expressions use the key', () {
      const type = HWImageData('avatar');
      expect(type.swiftAccess('data'), 'data.avatar');
      expect(type.kotlinAccess('data'), 'data.avatar');
      expect(type.swiftReadExpr('data'), 'data.avatar');
      expect(type.kotlinReadExpr('data'), 'data.avatar');
      expect(
        const HWImageData.asset('assets/logo.png').swiftAccess('data'),
        'data.assetsLogoPng',
      );
    });

    test('has no codegen default literal', () {
      const type = HWImageData('avatar');
      expect(type.codegenKotlinDefaultLiteral(), isNull);
      expect(type.codegenSwiftDefaultLiteral(), isNull);
    });

    test('cannot be stringified for text widgets', () {
      const type = HWImageData('avatar');
      expect(
        () => type.androidToString(outerValue: 'd.a', innerValue: 'd.a'),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('HWImageData cannot be rendered as text'),
          ),
        ),
      );
      expect(
        () => type.iosToString(outerValue: 'd.a', innerValue: 'd.a'),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.toString(),
            'message',
            contains('HWImageData cannot be rendered as text'),
          ),
        ),
      );
    });

    test('equality is by key and asset path', () {
      expect(const HWImageData('a'), const HWImageData('a'));
      expect(
        const HWImageData('a').hashCode,
        const HWImageData('a').hashCode,
      );
      expect(const HWImageData('a'), isNot(const HWImageData('b')));
      expect(
        const HWImageData.asset('assets/logo.png'),
        const HWImageData.asset('assets/logo.png'),
      );
      expect(
        const HWImageData.asset('assets/logo.png'),
        isNot(const HWImageData.asset('assets/other.png')),
      );
      // Same derived key, different asset path.
      expect(
        const HWImageData.asset('assets/logo.png'),
        isNot(const HWImageData('assetsLogoPng')),
      );
      expect(const HWImageData('a'), isNot(const HWString('a')));
    });

    test('deduplicates in a data dependency set', () {
      const a = HWImage.asset('assets/logo.png');
      const b = HWImage.asset('assets/logo.png');
      final deps = <HWDataType<dynamic>>{
        ...a.dataDependencies,
        ...b.dataDependencies,
      };
      expect(deps, hasLength(1));
    });
  });

  group('HWItemData', () {
    const localized = HWLocalizedString.resolved(
      'title',
      defaultTranslations: {'en': 'Event', 'de': 'Termin'},
      isConstant: false,
      defaultLocale: 'en',
    );
    const icon = HWIconData.resolved(
      'condition',
      entries: [HWIconEntry('wbSunny', 0xE430)],
      iconFont: HWIconFont(family: 'MaterialIcons'),
    );

    test('delegates to the wrapped data type', () {
      const wrapped =
          HWString('label', defaultValue: 'Sunny', previewValue: 'Rain');
      const type = HWItemData(wrapped);

      expect(type.key, 'label');
      expect(type.defaultValue, 'Sunny');
      expect(type.previewValue, 'Rain');
      expect(type.dartType, 'String');
      expect(type.kotlinType, 'String');
      expect(type.swiftType, 'String');
      expect(type.codegenDartDefaultLiteral(), "'Sunny'");
      expect(type.codegenKotlinDefaultLiteral(), '"Sunny"');
      expect(type.codegenSwiftDefaultLiteral(), '"Sunny"');
      expect(type.codegenKotlinPreviewLiteral(), '"Rain"');
      expect(type.codegenSwiftPreviewLiteral(), '"Rain"');
      for (final preview in [false, true]) {
        expect(
          type.androidReadValue(store: 'prefs', key: 'k', preview: preview),
          wrapped.androidReadValue(store: 'prefs', key: 'k', preview: preview),
        );
        expect(
          type.iosReadValue(store: 'defaults', key: 'k', preview: preview),
          wrapped.iosReadValue(store: 'defaults', key: 'k', preview: preview),
        );
        expect(
          type.codegenKotlinFallbackLiteral(preview: preview),
          wrapped.codegenKotlinFallbackLiteral(preview: preview),
        );
        expect(
          type.codegenSwiftFallbackLiteral(preview: preview),
          wrapped.codegenSwiftFallbackLiteral(preview: preview),
        );
      }
      expect(
        type.androidToString(outerValue: 'hwItem.label', innerValue: 'x'),
        'hwItem.label ?: ""',
      );
      expect(
        type.iosToString(outerValue: 'hwItem.label', innerValue: 'x'),
        'hwItem.label ?? ""',
      );
    });

    test('hands the generated Dart API the types of the wrapped field', () {
      const type = HWItemData(icon);

      expect(type.dartApiType('Weather'), 'WeatherConditionIcon');
      expect(type.dartGetDataType('Weather'), 'WeatherConditionIcon');
      expect(
        type.dartDecode('raw', 'Weather'),
        'WeatherConditionIcon.fromCodePoint(raw)',
      );
      expect(type.dartEncode('value', 'Weather'), 'value.codePoint');
    });

    test('reads its field off the item, whatever the data expression', () {
      const type = HWItemData(HWInt('temperature'));

      expect(type.swiftAccess('entry.data'), 'hwItem.temperature');
      expect(type.kotlinAccess('widgetData'), 'hwItem.temperature');
      expect(type.swiftReadExpr('entry.data'), 'hwItem.temperature');
      expect(type.kotlinReadExpr('widgetData'), 'hwItem.temperature');
      expect(
        const HWTimedData(type).kotlinAccess('widgetData'),
        'hwItem.temperature',
      );
    });

    test('names the variables of the loop it is read in', () {
      expect(HWListLoop.item, 'hwItem');
      expect(HWListLoop.index, 'hwIndex');
      expect(HWListLoop.items, 'hwItems');
      expect(HWListLoop.ascents, 'hwAscents');
    });

    test('stays itself when unwrapped, also inside HWTimedData', () {
      const type = HWItemData(HWString('label'));

      expect(type.unwrapped, same(type));
      expect(const HWTimedData(type).unwrapped, same(type));
    });

    test('resolves a localized field an item stores no text for', () {
      const type = HWItemData(localized);

      expect(
        type.androidToString(outerValue: 'hwItem.title', innerValue: 'x'),
        '(hwItem.title ?: hwResolveLocalized(hwLocales, '
        'mapOf("en" to "Event", "de" to "Termin"), "en") ?: "Event")',
      );
      expect(
        type.iosToString(outerValue: 'hwItem.title', innerValue: 'x'),
        '((hwItem.title) ?? hwResolveLocalized(hwCurrentLocales(), '
        '["en": "Event", "de": "Termin"], baseLocale: "en") ?? "Event")',
      );
    });

    test('reads and renders through the helpers of a JSON leaf', () {
      const date = HWItemData(HWDateTime('day'));
      const previewed = HWLocalizedString.resolved(
        'title',
        defaultTranslations: {'en': 'Event'},
        previewTranslations: {'en': 'Party'},
        isConstant: false,
        defaultLocale: 'en',
      );
      const resolvers = {
        HWNativeHelper.hwCurrentLocales,
        HWNativeHelper.hwResolveLocalized,
      };

      expect(date.nativeHelpers, [HWNativeHelper.hwParseIsoDate]);
      expect(date.timedNativeHelpers, [HWNativeHelper.hwParseIsoDate]);
      expect(date.renderHelpers, isEmpty);
      expect(const HWItemData(localized).nativeHelpers, isEmpty);
      expect(const HWItemData(localized).renderHelpers, resolvers);
      expect(const HWItemData(previewed).nativeHelpers, resolvers.toList());
      expect(const HWTimedData(HWItemData(localized)).nativeHelpers, isEmpty);
      expect(
        const HWTimedData(HWItemData(localized)).renderHelpers,
        resolvers,
      );
    });

    test('finds the leaf through every wrapper', () {
      const number = HWInt('n');
      const wrapped = <HWDataType<dynamic>>[
        number,
        HWTimedData(number),
        HWJson('group', HWJson('inner', number)),
        HWTimedData(HWJson('group', number)),
        HWItemData(number),
        HWTimedData(HWItemData(number)),
      ];

      for (final type in wrapped) {
        expect(type.leaf, same(number), reason: '$type');
        expect(numberLeafOf(type), same(number), reason: '$type');
      }
      expect(
        imageLeafOf(const HWItemData(HWImageData('avatar'))),
        const HWImageData('avatar'),
      );
      expect(iconLeafOf(const HWTimedData(HWItemData(icon))), icon);
      expect(
        dateTimeLeafOf(const HWItemData(HWDateTime('day'))),
        const HWDateTime('day'),
      );
      const text = HWItemData(HWString('a'));
      expect(imageLeafOf(text), isNull);
      expect(iconLeafOf(text), isNull);
      expect(numberLeafOf(text), isNull);
      expect(dateTimeLeafOf(text), isNull);
    });

    test('equality and hashCode cover the field and its previewValues', () {
      const read = HWItemData(HWInt('t'), previewValues: [1, 2]);
      final twin = HWItemData(const HWInt('t'), previewValues: [1, 2]);

      expect(read, twin);
      expect(read.hashCode, twin.hashCode);
      expect(read, isNot(const HWItemData(HWInt('t'), previewValues: [1, 3])));
      expect(read, isNot(const HWItemData(HWInt('t'))));
      expect(const HWItemData(HWInt('t')), isNot(read));
      expect(const HWItemData(HWInt('t')), const HWItemData(HWInt('t')));
      expect(read, isNot(const HWItemData(HWInt('u'), previewValues: [1, 2])));
      expect(const HWItemData(HWInt('t')), isNot(const HWInt('t')));
      expect(
        const HWItemData(HWInt('t')),
        isNot(const HWTimedData(HWInt('t'))),
      );
    });

    test('hashCode matches == across type arguments', () {
      const HWDataType<dynamic> dynamicallyTyped =
          HWItemData<dynamic>(HWInt('t'));
      const HWDataType<dynamic> numberTyped = HWItemData<num>(HWInt('t'));

      expect(dynamicallyTyped, numberTyped);
      expect(dynamicallyTyped.hashCode, numberTyped.hashCode);
    });

    test('merges with a compatible read, a value set on one side carried over',
        () {
      const bare = HWItemData(HWInt('t', defaultValue: 0));
      const previewed =
          HWItemData(HWInt('t', previewValue: 3), previewValues: [1, 2]);
      const merged = HWItemData(
        HWInt('t', defaultValue: 0, previewValue: 3),
        previewValues: [1, 2],
      );

      expect(bare.isCompatibleWith(previewed), isTrue);
      expect(bare.mergedWith(previewed), merged);
      expect(previewed.mergedWith(bare), merged);
      expect(
        previewed.isCompatibleWith(
          const HWItemData(HWInt('t'), previewValues: [1, 2]),
        ),
        isTrue,
      );
    });

    test('conflicts with a read of another field or other previewValues', () {
      const read = HWItemData(HWInt('t'), previewValues: [1, 2]);

      expect(
        read.isCompatibleWith(
          const HWItemData(HWInt('t'), previewValues: [2, 1]),
        ),
        isFalse,
      );
      expect(read.isCompatibleWith(const HWItemData(HWDouble('t'))), isFalse);
      expect(read.isCompatibleWith(const HWInt('t')), isFalse);
      expect(
        read.isCompatibleWith(const HWTimedData(HWItemData(HWInt('t')))),
        isFalse,
      );
      expect(
        () => read.mergedWith(const HWItemData(HWDouble('t'))),
        throwsA(isA<GeneratorError>()),
      );
    });
  });
}
