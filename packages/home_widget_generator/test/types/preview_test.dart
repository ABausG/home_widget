import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';
import 'package:test/test.dart';

void main() {
  group('previewValue', () {
    test('is carried by every value type', () {
      expect(const HWString('k', previewValue: 'p').previewValue, 'p');
      expect(const HWInt('k', previewValue: 7).previewValue, 7);
      expect(const HWDouble('k', previewValue: 1.5).previewValue, 1.5);
      expect(const HWBool('k', previewValue: true).previewValue, true);
      expect(const HWString('k').previewValue, isNull);
    });

    test('is independent of defaultValue', () {
      const type = HWInt('k', defaultValue: 1, previewValue: 2);
      expect(type.defaultValue, 1);
      expect(type.previewValue, 2);
    });

    test('participates in equality and hashCode', () {
      expect(
        const HWString('k', previewValue: 'p'),
        equals(const HWString('k', previewValue: 'p')),
      );
      expect(
        const HWString('k', previewValue: 'p').hashCode,
        const HWString('k', previewValue: 'p').hashCode,
      );
      expect(
        const HWString('k', previewValue: 'p'),
        isNot(equals(const HWString('k'))),
      );
      expect(
        const HWInt('k', previewValue: 1),
        isNot(equals(const HWInt('k', previewValue: 2))),
      );
      expect(
        const HWBool('k', defaultValue: true),
        isNot(equals(const HWBool('k', previewValue: true))),
      );
    });

    test('HWJson reports the preview of its leaf, however deeply nested', () {
      expect(const HWJson('root', HWInt('n', previewValue: 5)).previewValue, 5);
      expect(
        const HWJson('root', HWJson('mid', HWString('s', previewValue: 'p')))
            .previewValue,
        'p',
      );
      expect(const HWJson('root', HWInt('n')).previewValue, isNull);
    });

    test('HWTimedData reports the preview of the wrapped type', () {
      expect(
        const HWTimedData(HWBool('b', previewValue: true)).previewValue,
        isTrue,
      );
      expect(const HWTimedData(HWBool('b')).previewValue, isNull);
    });

    test('an image previews through its asset, not through a value', () {
      expect(
        const HWImageData('avatar', previewAsset: 'assets/sample.png')
            .previewValue,
        isNull,
      );
    });
  });

  group('codegen preview literals', () {
    test('HWString emits a quoted, escaped literal or null', () {
      expect(const HWString('k').codegenKotlinPreviewLiteral(), isNull);
      expect(const HWString('k').codegenSwiftPreviewLiteral(), isNull);
      expect(
        const HWString('k', previewValue: 'hi').codegenKotlinPreviewLiteral(),
        '"hi"',
      );
      const tricky = HWString('k', previewValue: r'a"b$c');
      expect(tricky.codegenKotlinPreviewLiteral(), r'"a\"b\$c"');
      expect(tricky.codegenSwiftPreviewLiteral(), r'"a\"b$c"');
    });

    test('HWInt, HWDouble and HWBool emit bare literals', () {
      expect(
        const HWInt('k', previewValue: 42).codegenKotlinPreviewLiteral(),
        '42L',
      );
      expect(
        const HWInt('k', previewValue: 42).codegenSwiftPreviewLiteral(),
        '42',
      );
      expect(
        const HWDouble('k', previewValue: 1.5).codegenKotlinPreviewLiteral(),
        '1.5',
      );
      expect(
        const HWDouble('k', previewValue: 1.5).codegenSwiftPreviewLiteral(),
        '1.5',
      );
      // Zero and false are real previews, not absent ones.
      expect(
        const HWInt('k', previewValue: 0).codegenKotlinPreviewLiteral(),
        '0L',
      );
      expect(
        const HWBool('k', previewValue: false).codegenSwiftPreviewLiteral(),
        'false',
      );
      expect(const HWBool('k').codegenKotlinPreviewLiteral(), isNull);
    });

    test('HWJson reports the literal of its leaf', () {
      expect(
        const HWJson('root', HWInt('n', previewValue: 7))
            .codegenKotlinPreviewLiteral(),
        '7L',
      );
      expect(
        const HWJson('root', HWJson('mid', HWString('s', previewValue: 'x')))
            .codegenSwiftPreviewLiteral(),
        '"x"',
      );
      expect(
        const HWJson('root', HWInt('n')).codegenKotlinPreviewLiteral(),
        isNull,
      );
    });

    test('an image has no preview literal', () {
      const image = HWImageData('avatar', previewAsset: 'assets/sample.png');
      expect(image.codegenKotlinPreviewLiteral(), isNull);
      expect(image.codegenSwiftPreviewLiteral(), isNull);
    });
  });

  group('codegen fallback literals', () {
    test('prefer the preview literal and fall back to the default one', () {
      const both = HWString('k', defaultValue: 'd', previewValue: 'p');
      expect(both.codegenKotlinFallbackLiteral(), '"d"');
      expect(both.codegenSwiftFallbackLiteral(), '"d"');
      expect(both.codegenKotlinFallbackLiteral(preview: true), '"p"');
      expect(both.codegenSwiftFallbackLiteral(preview: true), '"p"');

      const defaultOnly = HWInt('k', defaultValue: 1);
      expect(defaultOnly.codegenKotlinFallbackLiteral(preview: true), '1L');
      expect(defaultOnly.codegenSwiftFallbackLiteral(preview: true), '1');

      const neither = HWBool('k');
      expect(neither.codegenKotlinFallbackLiteral(preview: true), isNull);
      expect(neither.codegenSwiftFallbackLiteral(preview: true), isNull);
    });

    test('an image falls back to its preview asset', () {
      const image = HWImageData('avatar', previewAsset: 'assets/sample.png');
      expect(image.codegenKotlinFallbackLiteral(), isNull);
      expect(image.codegenSwiftFallbackLiteral(), isNull);
      expect(
        image.codegenKotlinFallbackLiteral(preview: true),
        '"assets/sample.png"',
      );
      expect(
        image.codegenSwiftFallbackLiteral(preview: true),
        '"assets/sample.png"',
      );

      // Nothing to stand in for: an asset image already names its own asset.
      expect(
        const HWImageData.asset('assets/logo.png')
            .codegenKotlinFallbackLiteral(preview: true),
        isNull,
      );
      expect(
        const HWImageData('avatar').codegenSwiftFallbackLiteral(preview: true),
        isNull,
      );
    });

    test('a localized string falls back to its preview base text', () {
      const localized = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: false,
        defaultLocale: 'de',
        previewTranslations: {'en': 'Sample', 'de': 'Beispiel'},
      );
      expect(localized.codegenKotlinFallbackLiteral(), '"Hallo"');
      expect(
        localized.codegenSwiftFallbackLiteral(preview: true),
        '"Beispiel"',
      );
    });

    test('the JSON and timed wrappers report their leaf', () {
      const json = HWJson('root', HWInt('n', defaultValue: 1, previewValue: 9));
      expect(json.codegenKotlinFallbackLiteral(), '1L');
      expect(json.codegenKotlinFallbackLiteral(preview: true), '9L');
      expect(json.codegenSwiftFallbackLiteral(preview: true), '9');

      const timed = HWTimedData(HWString('k', previewValue: 'p'));
      expect(timed.codegenKotlinFallbackLiteral(preview: true), '"p"');
      expect(timed.codegenSwiftFallbackLiteral(preview: true), '"p"');
      expect(
        const HWTimedData(HWImageData('a', previewAsset: 'assets/s.png'))
            .codegenSwiftFallbackLiteral(preview: true),
        '"assets/s.png"',
      );
    });
  });

  group('preview read expressions', () {
    test('a string reads its preview before its default', () {
      const type = HWString('k', defaultValue: 'd', previewValue: 'p');
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        'prefs.getString("w.k", "p")',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        '(defaults?.string(forKey: "w.k") ?? "p")',
      );
      // No preview of its own: the default stands in as it always did.
      const defaultOnly = HWString('k', defaultValue: 'd');
      expect(
        defaultOnly.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        'prefs.getString("w.k", "d")',
      );
      expect(
        const HWString('k')
            .iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        'defaults?.string(forKey: "w.k")',
      );
    });

    test('a preview string literal is escaped per platform', () {
      const type = HWString('k', previewValue: r'a"b$c');
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        r'prefs.getString("w.k", "a\"b\$c")',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        r'(defaults?.string(forKey: "w.k") ?? "a\"b$c")',
      );
    });

    test('an int reads its preview before its default', () {
      const type = HWInt('k', defaultValue: 1, previewValue: 2);
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        'if (prefs.contains("w.k")) '
        '(try { prefs.getInt("w.k", 0).toLong() } '
        'catch (_: ClassCastException) { prefs.getLong("w.k", 0L) }) '
        'else 2L',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        '(defaults?.object(forKey: "w.k") as? Int ?? 2)',
      );
    });

    test('a double reads its preview before its default', () {
      const type = HWDouble('k', defaultValue: 1.5, previewValue: 2.5);
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        'if (prefs.contains("w.k")) '
        'java.lang.Double.longBitsToDouble(prefs.getLong("w.k", 0L)) '
        'else 2.5',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        '(defaults?.object(forKey: "w.k") as? Double ?? 2.5)',
      );
    });

    test('a bool reads its preview before its default', () {
      const type = HWBool('k', defaultValue: false, previewValue: true);
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        'if (prefs.contains("w.k")) prefs.getBoolean("w.k", false) else true',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        '(defaults?.object(forKey: "w.k") as? Bool ?? true)',
      );
    });

    test('a date parses the preview instant it was written with', () {
      const type = HWDateTime('when', previewValue: '2021-01-01T00:00:00Z');
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.when', preview: true),
        'hwParseIsoDate(prefs.getString("w.when", null) '
        '?: "2021-01-01T00:00:00Z")',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.when', preview: true),
        'hwParseIsoDate(defaults?.string(forKey: "w.when") '
        '?? "2021-01-01T00:00:00Z")',
      );
    });

    test('a date previews the same instant on every read path', () {
      const type = HWDateTime('start', previewValue: '2021-01-01T00:00:00Z');
      expect(
        type.androidJsonReadValue(
          objExpr: 'values',
          key: 'start',
          preview: true,
        ),
        'hwParseIsoDate(if (values.has("start") && !values.isNull("start")) '
        'values.optString("start") else "2021-01-01T00:00:00Z")',
      );
      expect(
        type.iosJsonReadValue(objExpr: 'values', key: 'start', preview: true),
        'hwParseIsoDate((values["start"] as? String) '
        '?? "2021-01-01T00:00:00Z")',
      );
      expect(
        type.androidTimedReadValue(valuesExpr: 'timedValues', preview: true),
        type.androidJsonReadValue(
          objExpr: 'timedValues',
          key: 'start',
          preview: true,
        ),
      );
      expect(
        type.iosTimedReadValue(valuesExpr: 'timedValues', preview: true),
        type.iosJsonReadValue(
          objExpr: 'timedValues',
          key: 'start',
          preview: true,
        ),
      );
    });

    test('a date without a preview keeps reading as no date', () {
      const type = HWDateTime('when');
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.when', preview: true),
        type.androidReadValue(store: 'prefs', key: 'w.when'),
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.when', preview: true),
        type.iosReadValue(store: 'defaults', key: 'w.when'),
      );
    });

    test('an image falls back to its preview asset', () {
      const type = HWImageData('avatar', previewAsset: 'assets/sample.png');
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.avatar', preview: true),
        'prefs.getString("w.avatar", "assets/sample.png")',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.avatar', preview: true),
        '(defaults?.string(forKey: "w.avatar") ?? "assets/sample.png")',
      );
      // Without one there is nothing to show, exactly as at runtime.
      const plain = HWImageData('avatar');
      expect(
        plain.androidReadValue(store: 'prefs', key: 'w.avatar', preview: true),
        'prefs.getString("w.avatar", null)',
      );
      expect(
        plain.iosReadValue(store: 'defaults', key: 'w.avatar', preview: true),
        'defaults?.string(forKey: "w.avatar")',
      );
    });

    test('a localized string resolves the preview translations', () {
      const type = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: false,
        defaultLocale: 'de',
        previewTranslations: {'en': 'Sample', 'de': 'Beispiel'},
      );
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.greeting', preview: true),
        'hwReadLocalized(prefs, "w.greeting", locales, '
        'mapOf("en" to "Sample", "de" to "Beispiel"), "de")',
      );
      expect(
        type.iosReadValue(
          store: 'defaults',
          key: 'w.greeting',
          preview: true,
        ),
        'hwReadLocalized(defaults, "w.greeting", '
        '["en": "Sample", "de": "Beispiel"], baseLocale: "de")',
      );
      expect(
        type.androidTimedReadValue(valuesExpr: 'timedValues', preview: true),
        'hwReadTimedLocalized(timedValues, "greeting", locales, '
        'mapOf("en" to "Sample", "de" to "Beispiel"), "de")',
      );
      expect(
        type.iosTimedReadValue(valuesExpr: 'timedValues', preview: true),
        'hwReadTimedLocalized(timedValues, "greeting", '
        '["en": "Sample", "de": "Beispiel"], baseLocale: "de")',
      );
    });

    test('a localized preview anchors on the first entry it has', () {
      const type = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: false,
        defaultLocale: 'de',
        previewTranslations: {'en': 'Sample'},
      );
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.greeting', preview: true),
        'hwReadLocalized(prefs, "w.greeting", locales, '
        'mapOf("en" to "Sample"), "en")',
      );
    });

    test('a localized string without previews reads unchanged', () {
      const type = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: false,
        defaultLocale: 'de',
      );
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.greeting', preview: true),
        type.androidReadValue(store: 'prefs', key: 'w.greeting'),
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.greeting', preview: true),
        type.iosReadValue(store: 'defaults', key: 'w.greeting'),
      );
      expect(
        type.androidTimedReadValue(valuesExpr: 'v', preview: true),
        type.androidTimedReadValue(valuesExpr: 'v'),
      );
      expect(
        type.iosTimedReadValue(valuesExpr: 'v', preview: true),
        type.iosTimedReadValue(valuesExpr: 'v'),
      );
    });

    test('a JSON group still reads the encoded string it is stored as', () {
      const type = HWJson('root', HWInt('n', previewValue: 9));
      expect(
        type.androidReadValue(store: 'prefs', key: 'w.root', preview: true),
        'prefs.getString("w.root", null)',
      );
      expect(
        type.iosReadValue(store: 'defaults', key: 'w.root', preview: true),
        'defaults?.string(forKey: "w.root")',
      );
    });

    test('a timed field reads exactly like the field it wraps', () {
      const wrapped = HWString('k', defaultValue: 'd', previewValue: 'p');
      const timed = HWTimedData(wrapped);
      expect(
        timed.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
        wrapped.androidReadValue(store: 'prefs', key: 'w.k', preview: true),
      );
      expect(
        timed.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
        wrapped.iosReadValue(store: 'defaults', key: 'w.k', preview: true),
      );
    });

    test('preview: false is the expression the widget itself reads', () {
      const types = <HWDataType<dynamic>>[
        HWString('k', defaultValue: 'd', previewValue: 'p'),
        HWInt('k', defaultValue: 1, previewValue: 2),
        HWDouble('k', defaultValue: 1.5, previewValue: 2.5),
        HWBool('k', defaultValue: false, previewValue: true),
        HWDateTime('k', previewValue: '2021-01-01T00:00:00Z'),
        HWImageData('k', previewAsset: 'assets/sample.png'),
        HWJson('root', HWInt('n', previewValue: 9)),
        HWTimedData(HWString('k', previewValue: 'p')),
        HWLocalizedString.resolved(
          'k',
          defaultTranslations: {'en': 'Hello'},
          isConstant: false,
          defaultLocale: 'en',
          previewTranslations: {'en': 'Sample'},
        ),
      ];
      for (final type in types) {
        expect(
          type.androidReadValue(store: 'prefs', key: 'w.k', preview: false),
          type.androidReadValue(store: 'prefs', key: 'w.k'),
          reason: '${type.runtimeType}',
        );
        expect(
          type.iosReadValue(store: 'defaults', key: 'w.k', preview: false),
          type.iosReadValue(store: 'defaults', key: 'w.k'),
          reason: '${type.runtimeType}',
        );
      }
    });
  });

  group('HWDateTime preview', () {
    const iso = '2021-01-01T00:00:00Z';
    const type = HWDateTime('when', previewValue: iso);

    test('keeps the ISO string and parses it', () {
      expect(type.previewIso, iso);
      expect(type.previewDateTime, DateTime.utc(2021));
      expect(type.previewValue, DateTime.utc(2021));
      expect(const HWDateTime('when').previewDateTime, isNull);
    });

    test('an unparseable string reads as no date', () {
      const bad = HWDateTime('when', previewValue: 'tomorrow');
      expect(bad.previewIso, 'tomorrow');
      expect(bad.previewDateTime, isNull);
      expect(bad.previewValue, isNull);
    });

    test('equality is on the written text, not the parsed instant', () {
      expect(type, equals(const HWDateTime('when', previewValue: iso)));
      expect(
        type.hashCode,
        const HWDateTime('when', previewValue: iso).hashCode,
      );
      expect(type, isNot(equals(const HWDateTime('when'))));
      expect(
        const HWDateTime('when', previewValue: 'tomorrow'),
        isNot(equals(const HWDateTime('when', previewValue: 'yesterday'))),
      );
    });

    test('survives the JSON and timed wrappers', () {
      expect(
        const HWJson('event', HWDateTime('start', previewValue: iso))
            .previewValue,
        DateTime.utc(2021),
      );
      expect(
        const HWTimedData(HWDateTime('next', previewValue: iso)).previewValue,
        DateTime.utc(2021),
      );
    });
  });

  group('HWLocalizedString preview translations', () {
    const preview = {'en': 'Sample', 'de': 'Beispiel'};
    const localized = HWLocalizedString.resolved(
      'greeting',
      defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      isConstant: false,
      defaultLocale: 'de',
      previewTranslations: preview,
      resourcePrefix: 'home_widget_test',
    );

    test('the public constructor and the factory take them', () {
      const viaFactory = HWString.localized(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
        previewTranslations: {'en': 'Sample'},
      );
      expect(
        (viaFactory as HWLocalizedString).previewTranslations,
        {'en': 'Sample'},
      );
      expect(
        const HWLocalizedString(
          'greeting',
          defaultTranslations: {'en': 'Hello'},
        ).previewTranslations,
        isNull,
      );
    });

    test('the preview base value follows the stamped default locale', () {
      expect(localized.previewBaseLocaleTag, 'de');
      expect(localized.previewBaseValue, 'Beispiel');
      expect(localized.codegenKotlinPreviewLiteral(), '"Beispiel"');
      expect(localized.codegenSwiftPreviewLiteral(), '"Beispiel"');
    });

    test('falls back to the first preview entry without that locale', () {
      const partial = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: false,
        defaultLocale: 'de',
        previewTranslations: {'en': 'Sample'},
      );
      expect(partial.previewBaseLocaleTag, 'en');
      expect(partial.previewBaseValue, 'Sample');
    });

    test('without previews there is no base value or literal', () {
      const plain = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
      );
      expect(plain.previewBaseLocaleTag, isNull);
      expect(plain.previewBaseValue, isNull);
      expect(plain.codegenKotlinPreviewLiteral(), isNull);
      expect(plain.codegenSwiftPreviewLiteral(), isNull);
      expect(plain.kotlinPreviewMapLiteral, isNull);
      expect(plain.swiftPreviewMapLiteral, isNull);
    });

    test('the preview map literals mirror the default ones', () {
      expect(
        localized.kotlinPreviewMapLiteral,
        'mapOf("en" to "Sample", "de" to "Beispiel")',
      );
      expect(
        localized.swiftPreviewMapLiteral,
        '["en": "Sample", "de": "Beispiel"]',
      );
      const escaped = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
        previewTranslations: {'en': r'a"b$c'},
      );
      expect(escaped.kotlinPreviewMapLiteral, r'mapOf("en" to "a\"b\$c")');
      expect(escaped.swiftPreviewMapLiteral, r'["en": "a\"b$c"]');
    });

    test('previews participate in equality and hashCode', () {
      const a = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
        previewTranslations: {'en': 'Sample'},
      );
      const b = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
        previewTranslations: {'en': 'Sample'},
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          equals(
            const HWLocalizedString(
              'greeting',
              defaultTranslations: {'en': 'Hello'},
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            const HWLocalizedString(
              'greeting',
              defaultTranslations: {'en': 'Hello'},
              previewTranslations: {'en': 'Other'},
            ),
          ),
        ),
      );
    });
  });

  group('HWImageData preview asset', () {
    test('a runtime image takes one, an asset image does not', () {
      const runtime = HWImageData('avatar', previewAsset: 'assets/sample.png');
      expect(runtime.previewAsset, 'assets/sample.png');
      expect(const HWImageData('avatar').previewAsset, isNull);
      expect(const HWImageData.asset('assets/logo.png').previewAsset, isNull);
    });

    test('a packages/ prefix reaches the generated code as written', () {
      const type = HWImageData(
        'avatar',
        previewAsset: 'packages/my_icons/assets/sample.png',
      );
      expect(
        type.codegenKotlinFallbackLiteral(preview: true),
        '"packages/my_icons/assets/sample.png"',
      );
      expect(
        type.codegenSwiftFallbackLiteral(preview: true),
        '"packages/my_icons/assets/sample.png"',
      );
    });

    test('the preview asset participates in equality and hashCode', () {
      expect(
        const HWImageData('avatar', previewAsset: 'assets/sample.png'),
        equals(const HWImageData('avatar', previewAsset: 'assets/sample.png')),
      );
      expect(
        const HWImageData('avatar', previewAsset: 'assets/sample.png').hashCode,
        const HWImageData('avatar', previewAsset: 'assets/sample.png').hashCode,
      );
      expect(
        const HWImageData('avatar', previewAsset: 'assets/sample.png'),
        isNot(equals(const HWImageData('avatar'))),
      );
      expect(
        const HWImageData('avatar', previewAsset: 'assets/sample.png'),
        isNot(
          equals(const HWImageData('avatar', previewAsset: 'assets/b.png')),
        ),
      );
    });
  });

  group('isCompatibleWith and mergedWith', () {
    test('an unset value is taken from the other declaration', () {
      const withDefault = HWString('k', defaultValue: 'd');
      const withPreview = HWString('k', previewValue: 'p');
      const both = HWString('k', defaultValue: 'd', previewValue: 'p');

      expect(withDefault.isCompatibleWith(withPreview), isTrue);
      expect(withDefault.mergedWith(withPreview), both);
      expect(withPreview.mergedWith(withDefault), both);
      expect(both.mergedWith(withDefault), both);
    });

    test('identical declarations merge to themselves', () {
      for (final type in <HWDataType<dynamic>>[
        const HWString('k', defaultValue: 'd', previewValue: 'p'),
        const HWInt('k', defaultValue: 1, previewValue: 2),
        const HWDouble('k', defaultValue: 1.5, previewValue: 2.5),
        const HWBool('k', defaultValue: false, previewValue: true),
        const HWDateTime('k', previewValue: '2021-01-01T00:00:00Z'),
        const HWImageData('k', previewAsset: 'assets/sample.png'),
      ]) {
        expect(type.isCompatibleWith(type), isTrue);
        expect(type.mergedWith(type), equals(type));
      }
    });

    test('numbers and booleans merge each half', () {
      expect(
        const HWInt('k', defaultValue: 1).mergedWith(
          const HWInt('k', previewValue: 2),
        ),
        const HWInt('k', defaultValue: 1, previewValue: 2),
      );
      expect(
        const HWDouble('k', previewValue: 2.5).mergedWith(
          const HWDouble('k', defaultValue: 1.5),
        ),
        const HWDouble('k', defaultValue: 1.5, previewValue: 2.5),
      );
      expect(
        const HWBool('k', defaultValue: false).mergedWith(
          const HWBool('k', previewValue: true),
        ),
        const HWBool('k', defaultValue: false, previewValue: true),
      );
    });

    test('two set values must agree', () {
      const a = HWString('k', defaultValue: 'a');
      const b = HWString('k', defaultValue: 'b');
      expect(a.isCompatibleWith(b), isFalse);
      expect(
        () => a.mergedWith(b),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('Conflicting declarations for data key "k"'),
          ),
        ),
      );
      expect(
        const HWString('k', previewValue: 'a')
            .isCompatibleWith(const HWString('k', previewValue: 'b')),
        isFalse,
      );
    });

    test('a different key or a different kind of field never merges', () {
      expect(
        const HWString('a').isCompatibleWith(const HWString('b')),
        isFalse,
      );

      const HWDataType<dynamic> string = HWString('k');
      const HWDataType<dynamic> number = HWInt('k');
      expect(string.isCompatibleWith(number), isFalse);
      expect(() => string.mergedWith(number), throwsA(isA<GeneratorError>()));

      const HWDataType<dynamic> localized = HWLocalizedString(
        'k',
        defaultTranslations: {'en': 'Hello'},
      );
      expect(string.isCompatibleWith(localized), isFalse);
      expect(localized.isCompatibleWith(string), isFalse);
    });

    test('HWDateTime merges the ISO string it was written with', () {
      const iso = '2021-01-01T00:00:00Z';
      expect(
        const HWDateTime('when').mergedWith(
          const HWDateTime('when', previewValue: iso),
        ),
        const HWDateTime('when', previewValue: iso),
      );
      expect(
        const HWDateTime('when', previewValue: 'tomorrow')
            .isCompatibleWith(const HWDateTime('when', previewValue: 'later')),
        isFalse,
      );
    });

    test('HWJson merges its child, recursing into nested groups', () {
      const withDefault =
          HWJson('root', HWJson('mid', HWInt('n', defaultValue: 1)));
      const withPreview = HWJson(
        'root',
        HWJson('mid', HWInt('n', defaultValue: 1, previewValue: 9)),
      );

      expect(withDefault.isCompatibleWith(withPreview), isTrue);
      expect(
        withDefault.mergedWith(withPreview),
        const HWJson(
          'root',
          HWJson('mid', HWInt('n', defaultValue: 1, previewValue: 9)),
        ),
      );
    });

    test('HWJson paths must lead to the same leaf', () {
      expect(
        const HWJson('root', HWInt('a'))
            .isCompatibleWith(const HWJson('root', HWInt('b'))),
        isFalse,
      );
      expect(
        const HWJson('root', HWInt('a'))
            .isCompatibleWith(const HWJson('other', HWInt('a'))),
        isFalse,
      );
      expect(
        const HWJson('root', HWInt('a')).isCompatibleWith(
          const HWJson('root', HWJson('mid', HWInt('a'))),
        ),
        isFalse,
      );
      expect(
        const HWJson('root', HWInt('a', defaultValue: 1)).isCompatibleWith(
          const HWJson('root', HWInt('a', defaultValue: 2)),
        ),
        isFalse,
      );
    });

    test(
        'HWJson requires the leaf defaultValue to match exactly, since render '
        'sites inline it', () {
      expect(
        const HWJson('root', HWInt('a', defaultValue: 1))
            .isCompatibleWith(const HWJson('root', HWInt('a'))),
        isFalse,
      );
      expect(
        () => const HWJson('root', HWInt('a', defaultValue: 1)).mergedWith(
          const HWJson('root', HWInt('a')),
        ),
        throwsA(isA<GeneratorError>()),
      );
      // The exactness reaches the leaf through nesting too.
      expect(
        const HWJson('root', HWJson('mid', HWInt('a', defaultValue: 1)))
            .isCompatibleWith(
          const HWJson('root', HWJson('mid', HWInt('a'))),
        ),
        isFalse,
      );
    });

    test('HWTimedData merges the data it wraps', () {
      const withDefault = HWTimedData(HWString('k', defaultValue: 'd'));
      const withPreview = HWTimedData(HWString('k', previewValue: 'p'));

      expect(withDefault.isCompatibleWith(withPreview), isTrue);
      expect(
        withDefault.mergedWith(withPreview),
        const HWTimedData(HWString('k', defaultValue: 'd', previewValue: 'p')),
      );
      expect(
        const HWTimedData(HWJson('root', HWInt('n', defaultValue: 1)))
            .mergedWith(
          const HWTimedData(
            HWJson('root', HWInt('n', defaultValue: 1, previewValue: 9)),
          ),
        ),
        const HWTimedData(
          HWJson('root', HWInt('n', defaultValue: 1, previewValue: 9)),
        ),
      );
    });

    test('a timed and an untimed declaration are different fields', () {
      const timed = HWTimedData(HWString('k'));
      const untimed = HWString('k');
      expect(timed.isCompatibleWith(untimed), isFalse);
      expect(untimed.isCompatibleWith(timed), isFalse);
    });

    test('localized strings merge only their previews', () {
      const plain = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
      );
      const withPreview = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
        previewTranslations: {'en': 'Sample'},
      );

      expect(plain.isCompatibleWith(withPreview), isTrue);
      expect(plain.mergedWith(withPreview), withPreview);
      expect(withPreview.mergedWith(plain), withPreview);

      // defaultTranslations stay an exact match.
      expect(
        plain.isCompatibleWith(
          const HWLocalizedString(
            'greeting',
            defaultTranslations: {'en': 'Hi'},
          ),
        ),
        isFalse,
      );
      expect(
        withPreview.isCompatibleWith(
          const HWLocalizedString(
            'greeting',
            defaultTranslations: {'en': 'Hello'},
            previewTranslations: {'en': 'Other'},
          ),
        ),
        isFalse,
      );
    });

    test('merging a localized string keeps what the parser stamped on', () {
      const resolved = HWLocalizedString.resolved(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: false,
        defaultLocale: 'de',
        resourcePrefix: 'home_widget_test',
      );
      final merged = resolved.mergedWith(
        const HWLocalizedString(
          'greeting',
          defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
          previewTranslations: {'en': 'Sample'},
        ),
      ) as HWLocalizedString;

      expect(merged.defaultLocale, 'de');
      expect(merged.resourcePrefix, 'home_widget_test');
      expect(merged.isConstant, isFalse);
      expect(merged.previewTranslations, {'en': 'Sample'});
    });

    test('images match on the resolved asset, however it was spelled', () {
      expect(
        const HWImageData.asset('assets/logo.png', package: 'my_icons')
            .isCompatibleWith(
          const HWImageData.asset('packages/my_icons/assets/logo.png'),
        ),
        isTrue,
      );
      expect(
        const HWImageData.asset('assets/logo.png')
            .isCompatibleWith(const HWImageData.asset('assets/other.png')),
        isFalse,
      );
      expect(
        const HWImageData('avatar')
            .isCompatibleWith(const HWImageData.asset('assets/logo.png')),
        isFalse,
      );
    });

    test('images merge their preview asset', () {
      const withPreview = HWImageData(
        'avatar',
        previewAsset: 'assets/sample.png',
      );
      expect(const HWImageData('avatar').mergedWith(withPreview), withPreview);
      expect(withPreview.mergedWith(const HWImageData('avatar')), withPreview);
      expect(
        withPreview.isCompatibleWith(
          const HWImageData('avatar', previewAsset: 'assets/other.png'),
        ),
        isFalse,
      );
    });

    test('an asset image merges to itself', () {
      const asset = HWImageData.asset('assets/logo.png', package: 'my_icons');
      expect(
        asset.mergedWith(
          const HWImageData.asset('packages/my_icons/assets/logo.png'),
        ),
        same(asset),
      );
    });
  });
}
