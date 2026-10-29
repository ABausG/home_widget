import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWNumberFormat calls', () {
    test('decimal', () {
      const format = HWNumberFormat.decimal();
      expect(format.helper, HWNativeHelper.hwFormatDecimal);
      expect(
        format.swiftCall('x', dataExpr: 'entry.data'),
        'hwFormatDecimal(x, minFraction: nil, maxFraction: nil, '
        'grouping: true)',
      );
      expect(
        format.kotlinCall('x', dataExpr: 'widgetData'),
        'hwFormatDecimal(x, null, null, true, hwFormatLocale(context))',
      );
      const bounded = HWNumberFormat.decimal(
        minimumFractionDigits: 2,
        maximumFractionDigits: 4,
        useGrouping: false,
      );
      expect(
        bounded.swiftCall('x', dataExpr: 'd'),
        'hwFormatDecimal(x, minFraction: 2, maxFraction: 4, grouping: false)',
      );
      expect(
        bounded.kotlinCall('x', dataExpr: 'd'),
        'hwFormatDecimal(x, 2, 4, false, hwFormatLocale(context))',
      );
    });

    test('percent', () {
      const format = HWNumberFormat.percent(maximumFractionDigits: 1);
      expect(format.helper, HWNativeHelper.hwFormatPercent);
      expect(
        format.swiftCall('x', dataExpr: 'd'),
        'hwFormatPercent(x, minFraction: nil, maxFraction: 1)',
      );
      expect(
        format.kotlinCall('x', dataExpr: 'd'),
        'hwFormatPercent(x, null, 1, hwFormatLocale(context))',
      );
    });

    test('currency, fixed and data-bound', () {
      const fixed = HWNumberFormat.currency(
        currency: HWCurrency.code('EUR'),
        decimalDigits: 0,
      );
      expect(fixed.helper, HWNativeHelper.hwFormatCurrency);
      expect(
        fixed.swiftCall('x', dataExpr: 'entry.data'),
        'hwFormatCurrency(x, code: "EUR", decimals: 0)',
      );
      expect(
        fixed.kotlinCall('x', dataExpr: 'widgetData'),
        'hwFormatCurrency(x, "EUR", 0, hwFormatLocale(context))',
      );
      expect(fixed.dataField, isNull);

      const bound = HWNumberFormat.currency(
        currency: HWCurrency.data(HWString('cur')),
      );
      expect(
        bound.swiftCall('x', dataExpr: 'entry.data'),
        'hwFormatCurrency(x, code: entry.data.cur ?? "", decimals: nil)',
      );
      expect(
        bound.kotlinCall('x', dataExpr: 'widgetData'),
        'hwFormatCurrency(x, widgetData.cur ?: "", null, '
        'hwFormatLocale(context))',
      );
      expect(bound.dataField, const HWString('cur'));
    });

    test('compact and pattern', () {
      const compact = HWNumberFormat.compact();
      expect(compact.helper, HWNativeHelper.hwFormatCompact);
      expect(compact.swiftCall('x', dataExpr: 'd'), 'hwFormatCompact(x)');
      expect(
        compact.kotlinCall('x', dataExpr: 'd'),
        'hwFormatCompact(x, hwFormatLocale(context))',
      );

      const pattern = HWNumberFormat.pattern('0.###');
      expect(pattern.helper, HWNativeHelper.hwFormatNumberPattern);
      expect(
        pattern.swiftCall('x', dataExpr: 'd'),
        'hwFormatNumberPattern(x, "0.###")',
      );
      expect(
        pattern.kotlinCall('x', dataExpr: 'd'),
        'hwFormatNumberPattern(x, "0.###", hwFormatLocale(context))',
      );
    });

    test('the default format is a plain decimal', () {
      expect(HWNumberFormat.defaultFormat, const HWNumberFormat.decimal());
    });

    test('a pattern with quotes is escaped for both languages', () {
      const format = HWNumberFormat.pattern('"#"0');
      expect(
        format.swiftCall('x', dataExpr: 'd'),
        r'hwFormatNumberPattern(x, "\"#\"0")',
      );
      expect(
        format.kotlinCall('x', dataExpr: 'd'),
        r'hwFormatNumberPattern(x, "\"#\"0", hwFormatLocale(context))',
      );
    });
  });

  group('HWDateFormat calls', () {
    test('skeleton, pattern and styled', () {
      expect(HWDateFormat.yMMMd.helper, HWNativeHelper.hwFormatDateSkeleton);
      expect(
        HWDateFormat.yMMMd.swiftCall('date', dataExpr: 'entry.data'),
        'hwFormatDateSkeleton(date, "yMMMd")',
      );
      expect(
        HWDateFormat.yMMMd.kotlinCall('date', dataExpr: 'widgetData'),
        'hwFormatDateSkeleton(date, "yMMMd", hwFormatLocale(context))',
      );

      const pattern = HWDateFormat.pattern('dd.MM.yyyy');
      expect(pattern.helper, HWNativeHelper.hwFormatDatePattern);
      expect(
        pattern.swiftCall('date', dataExpr: 'd'),
        'hwFormatDatePattern(date, "dd.MM.yyyy")',
      );
      expect(
        pattern.kotlinCall('date', dataExpr: 'd'),
        'hwFormatDatePattern(date, "dd.MM.yyyy", hwFormatLocale(context))',
      );

      expect(
        HWDateFormat.defaultFormat.helper,
        HWNativeHelper.hwFormatDateStyled,
      );
      expect(
        HWDateFormat.defaultFormat.swiftCall('date', dataExpr: 'd'),
        'hwFormatDateStyled(date, dateStyle: .medium, timeStyle: .short)',
      );
      expect(
        HWDateFormat.defaultFormat.kotlinCall('date', dataExpr: 'd'),
        'hwFormatDateStyled(date, java.text.DateFormat.MEDIUM, '
        'java.text.DateFormat.SHORT, hwFormatLocale(context))',
      );
    });

    test('a styled format may omit either half', () {
      expect(
        const HWDateFormat.styled(time: HWFormatStyle.long)
            .swiftCall('date', dataExpr: 'd'),
        'hwFormatDateStyled(date, dateStyle: .none, timeStyle: .long)',
      );
      expect(
        const HWDateFormat.styled(date: HWFormatStyle.full)
            .kotlinCall('date', dataExpr: 'd'),
        'hwFormatDateStyled(date, java.text.DateFormat.FULL, null, '
        'hwFormatLocale(context))',
      );
    });

    test('every named constant is a skeleton with its own name', () {
      const expected = {
        'yMd': HWDateFormat.yMd,
        'yMMMd': HWDateFormat.yMMMd,
        'yMMMMd': HWDateFormat.yMMMMd,
        'yMMMEd': HWDateFormat.yMMMEd,
        'yMMMMEEEEd': HWDateFormat.yMMMMEEEEd,
        'yM': HWDateFormat.yM,
        'yMMM': HWDateFormat.yMMM,
        'yMMMM': HWDateFormat.yMMMM,
        'MMMd': HWDateFormat.MMMd,
        'MMMEd': HWDateFormat.MMMEd,
        'MMMMd': HWDateFormat.MMMMd,
        'Md': HWDateFormat.Md,
        'Ed': HWDateFormat.Ed,
        'd': HWDateFormat.d,
        'y': HWDateFormat.y,
        'jm': HWDateFormat.jm,
        'jms': HWDateFormat.jms,
        'Hm': HWDateFormat.Hm,
        'Hms': HWDateFormat.Hms,
        'j': HWDateFormat.j,
        'H': HWDateFormat.H,
        'yMdjm': HWDateFormat.yMdjm,
        'yMMMdjm': HWDateFormat.yMMMdjm,
        'yMMMMdjm': HWDateFormat.yMMMMdjm,
      };
      for (final entry in expected.entries) {
        expect(entry.value, isA<HWSkeletonDateFormat>());
        expect((entry.value as HWSkeletonDateFormat).skeleton, entry.key);
      }
    });

    test('the call carries the locale and an optional zone', () {
      expect(
        HWDateFormat.yMd.swiftCall('date', dataExpr: 'd'),
        'hwFormatDateSkeleton(date, "yMd")',
      );
      expect(
        HWDateFormat.yMd.swiftCall(
          'date',
          timeZone: HWTimeZone.utc,
          dataExpr: 'd',
        ),
        'hwFormatDateSkeleton(date, "yMd", timeZone: "UTC")',
      );
      expect(
        HWDateFormat.yMd.kotlinCall('date', dataExpr: 'd'),
        'hwFormatDateSkeleton(date, "yMd", hwFormatLocale(context))',
      );
      expect(
        HWDateFormat.yMd.kotlinCall(
          'date',
          timeZone: HWTimeZone.utc,
          dataExpr: 'd',
        ),
        'hwFormatDateSkeleton(date, "yMd", hwFormatLocale(context), "UTC")',
      );
      expect(
        HWDateFormat.yMd.kotlinCall(
          'date',
          timeZone: const HWTimeZone.data(HWString('tz')),
          dataExpr: 'widgetData',
        ),
        'hwFormatDateSkeleton(date, "yMd", hwFormatLocale(context), '
        'widgetData.tz)',
      );
    });
  });

  group('HWTimeZone', () {
    test('local is the helper default and contributes nothing', () {
      const zone = HWTimeZone.local;
      expect(zone.dataField, isNull);
      expect(zone.helpers, isEmpty);
      expect(zone.toSwift(0, dataExpr: 'entry.data'), 'nil');
      expect(zone.toKotlin(0, dataExpr: 'widgetData'), 'null');
      expect(zone.kotlinImports, isEmpty);
      expect(zone.swiftViewModifiers, isEmpty);
    });

    test('utc is the named UTC zone', () {
      expect(HWTimeZone.utc, const HWTimeZone.named('UTC'));
      expect(HWTimeZone.utc.toSwift(0, dataExpr: 'd'), '"UTC"');
      expect(HWTimeZone.utc.toKotlin(0, dataExpr: 'd'), '"UTC"');
    });

    test('named passes its id as a literal', () {
      const zone = HWTimeZone.named('Europe/Berlin');
      expect(zone.toSwift(0, dataExpr: 'd'), '"Europe/Berlin"');
      expect(zone.toKotlin(0, dataExpr: 'd'), '"Europe/Berlin"');
      expect(zone.dataField, isNull);
      expect(zone.helpers, [HWNativeHelper.hwResolveTimeZone]);
    });

    test('data passes the nullable field through', () {
      const zone = HWTimeZone.data(HWString('tz'));
      expect(zone.dataField, const HWString('tz'));
      expect(zone.helpers, [HWNativeHelper.hwResolveTimeZone]);
      expect(zone.toSwift(0, dataExpr: 'entry.data'), 'entry.data.tz');
      expect(zone.toKotlin(0, dataExpr: 'widgetData'), 'widgetData.tz');
    });

    test('every spelling of a zone field is accepted', () {
      const timed = HWTimeZone.data(HWTimedData(HWString('tz')));
      expect(timed.toSwift(0, dataExpr: 'entry.data'), 'entry.data.tz');
      expect(timed.toKotlin(0, dataExpr: 'widgetData'), 'widgetData.tz');

      const nested = HWTimeZone.data(HWJson('cfg', HWString('tz')));
      expect(nested.toSwift(0, dataExpr: 'entry.data'), 'entry.data.cfg?.tz');
      expect(nested.toKotlin(0, dataExpr: 'widgetData'), 'widgetData.cfg?.tz');
    });
  });

  group('HWCurrency', () {
    test('a fixed code is a literal and reads no field', () {
      const currency = HWCurrency.code('EUR');
      expect(currency.dataField, isNull);
      expect(currency.toSwift(0, dataExpr: 'd'), '"EUR"');
      expect(currency.toKotlin(0, dataExpr: 'd'), '"EUR"');
      expect(currency.kotlinImports, isEmpty);
      expect(currency.swiftViewModifiers, isEmpty);
    });

    test('every spelling of a code field is accepted', () {
      const plain = HWCurrency.data(HWString('cur'));
      expect(plain.toSwift(0, dataExpr: 'entry.data'), 'entry.data.cur ?? ""');
      expect(plain.toKotlin(0, dataExpr: 'widgetData'), 'widgetData.cur ?: ""');

      const timed = HWCurrency.data(HWTimedData(HWString('cur')));
      expect(timed.toSwift(0, dataExpr: 'entry.data'), 'entry.data.cur ?? ""');
      expect(timed.toKotlin(0, dataExpr: 'widgetData'), 'widgetData.cur ?: ""');

      const nested = HWCurrency.data(HWJson('cfg', HWString('cur')));
      expect(
        nested.toSwift(0, dataExpr: 'entry.data'),
        'entry.data.cfg?.cur ?? ""',
      );
      expect(
        nested.toKotlin(0, dataExpr: 'widgetData'),
        'widgetData.cfg?.cur ?: ""',
      );
    });
  });

  group('HWFormatStyle', () {
    test('maps to the platform style spellings', () {
      expect(HWFormatStyle.short.swiftStyle, '.short');
      expect(HWFormatStyle.medium.kotlinStyle, 'java.text.DateFormat.MEDIUM');
      expect(HWFormatStyle.long.swiftStyle, '.long');
      expect(HWFormatStyle.full.kotlinStyle, 'java.text.DateFormat.FULL');
    });
  });

  group('toString', () {
    test('names the variant it came from', () {
      expect(
        const HWNumberFormat.decimal().toString(),
        'HWNumberFormat.decimal(minimumFractionDigits: null, '
        'maximumFractionDigits: null, useGrouping: true)',
      );
      expect(
        const HWNumberFormat.percent().toString(),
        'HWNumberFormat.percent(minimumFractionDigits: null, '
        'maximumFractionDigits: null)',
      );
      expect(
        const HWNumberFormat.currency(currency: HWCurrency.code('EUR'))
            .toString(),
        'HWNumberFormat.currency(currency: HWCurrency.code(EUR), '
        'decimalDigits: null)',
      );
      expect(
        const HWNumberFormat.compact().toString(),
        'HWNumberFormat.compact()',
      );
      expect(
        const HWNumberFormat.pattern('0.#').toString(),
        'HWNumberFormat.pattern(0.#)',
      );
      expect(HWDateFormat.yMd.toString(), 'HWDateFormat.skeleton(yMd)');
      expect(
        const HWDateFormat.pattern('dd').toString(),
        'HWDateFormat.pattern(dd)',
      );
      expect(
        HWDateFormat.defaultFormat.toString(),
        'HWDateFormat.styled(date: HWFormatStyle.medium, '
        'time: HWFormatStyle.short)',
      );
      expect(HWTimeZone.local.toString(), 'HWTimeZone.local');
      expect(
        const HWTimeZone.named('UTC').toString(),
        'HWTimeZone.named(UTC)',
      );
      expect(
        const HWTimeZone.data(HWString('tz')).toString(),
        'HWTimeZone.data(tz)',
      );
      expect(
        const HWCurrency.data(HWString('cur')).toString(),
        'HWCurrency.data(cur)',
      );
    });
  });
}
