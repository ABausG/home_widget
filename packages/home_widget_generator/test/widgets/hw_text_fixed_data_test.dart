import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

/// The `style` argument a Glance `Text` carries when nothing sets a color.
const _defaultStyleArg =
    'style = TextStyle(color = GlanceTheme.colors.onSurface)';

/// Expects [text] to emit [swift] and [kotlin], and to call [helpers] and
/// nothing else.
void _expectEmit(
  HWText text, {
  required String swift,
  required String kotlin,
  Set<HWNativeHelper> helpers = const {},
}) {
  expect(text.toSwift(0, dataExpr: 'entry.data'), swift);
  expect(text.toKotlin(0, dataExpr: 'data'), kotlin);
  expect(text.nativeHelpers, helpers);
  expect(text.renderHelpers, helpers);
}

void main() {
  group('HWText with a fixed value', () {
    group('emits the literal', () {
      test('HWString.fixed', () {
        _expectEmit(
          const HWText(HWString.fixed('Hi')),
          swift: 'Text("Hi")',
          kotlin: 'Text(text = "Hi", $_defaultStyleArg)',
        );
      });

      test('HWString.fixed, escaped for each platform', () {
        _expectEmit(
          const HWText(HWString.fixed('He said "Hi" for \$5')),
          swift: r'Text("He said \"Hi\" for $5")',
          kotlin: 'Text(text = "He said \\"Hi\\" for \\\$5", '
              '$_defaultStyleArg)',
        );
      });

      test('HWString.fixed with the style and alignment of the widget', () {
        const text = HWText(
          HWString.fixed('Hi'),
          style: HWTextStyle(fontSize: 20, fontWeight: HWFontWeight.bold),
          textAlign: HWTextAlign.center,
        );

        expect(text.toSwift(1, dataExpr: 'entry.data'), '''
    Text("Hi")
        .font(.system(size: 20.0, weight: .bold))
        .multilineTextAlignment(.center)''');
        expect(
          text.toKotlin(1, dataExpr: 'data'),
          '    Text(text = "Hi", style = TextStyle('
          'color = GlanceTheme.colors.onSurface, fontSize = 20.sp, '
          'fontWeight = FontWeight.Bold, textAlign = TextAlign.Center))',
        );
      });

      test('HWInt.fixed in the default format', () {
        _expectEmit(
          const HWText.number(HWInt.fixed(1234)),
          swift: 'Text(hwFormatDecimal(NSNumber(value: 1234.0), '
              'minFraction: nil, maxFraction: nil, grouping: true))',
          kotlin: 'Text(text = hwFormatDecimal(1234.0, null, null, true, '
              'hwFormatLocale(context)), $_defaultStyleArg)',
          helpers: {HWNativeHelper.hwFormatDecimal},
        );
      });

      test('HWInt.fixed with a format', () {
        _expectEmit(
          const HWText.number(
            HWInt.fixed(3),
            format: HWNumberFormat.currency(currency: HWCurrency.code('EUR')),
          ),
          swift: 'Text(hwFormatCurrency(NSNumber(value: 3.0), code: "EUR", '
              'decimals: nil))',
          kotlin: 'Text(text = hwFormatCurrency(3.0, "EUR", null, '
              'hwFormatLocale(context)), $_defaultStyleArg)',
          helpers: {HWNativeHelper.hwFormatCurrency},
        );
      });

      test('a negative HWInt.fixed', () {
        _expectEmit(
          const HWText.number(HWInt.fixed(-3)),
          swift: 'Text(hwFormatDecimal(NSNumber(value: -3.0), '
              'minFraction: nil, maxFraction: nil, grouping: true))',
          kotlin: 'Text(text = hwFormatDecimal(-3.0, null, null, true, '
              'hwFormatLocale(context)), $_defaultStyleArg)',
          helpers: {HWNativeHelper.hwFormatDecimal},
        );
      });

      test('HWDouble.fixed with a format', () {
        _expectEmit(
          const HWText.number(
            HWDouble.fixed(2.5),
            format: HWNumberFormat.percent(),
          ),
          swift: 'Text(hwFormatPercent(NSNumber(value: 2.5), '
              'minFraction: nil, maxFraction: nil))',
          kotlin: 'Text(text = hwFormatPercent(2.5, null, null, '
              'hwFormatLocale(context)), $_defaultStyleArg)',
          helpers: {HWNativeHelper.hwFormatPercent},
        );
      });

      test('HWString.localizedFixed, read out of its string resource', () {
        const text = HWText(
          HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'}),
        );

        _expectEmit(
          text,
          swift: 'Text(NSLocalizedString("home_widget_t_50bb5ce3", '
              'comment: ""))',
          kotlin: 'Text(text = context.getString('
              'R.string.home_widget_t_50bb5ce3), $_defaultStyleArg)',
        );
        expect(text.dataDependencies, {text.dataType});
      });
    });

    group('renders what the stored value would', () {
      test('a fixed date goes through the date format with no storage read',
          () {
        const text = HWText.dateTime(
          HWDateTime.fixed('2026-09-22T10:00:00Z'),
          format: HWDateFormat.yMMMd,
        );
        const stored = HWText.dateTime(
          HWDateTime('at'),
          format: HWDateFormat.yMMMd,
        );

        final swift = text.toSwift(0, dataExpr: 'entry.data');
        final kotlin = text.toKotlin(0, dataExpr: 'data');
        expect(
          swift,
          stored.toSwift(0, dataExpr: 'entry.data').replaceFirst(
                'entry.data.at',
                'hwParseIsoDate("2026-09-22T10:00:00.000Z")',
              ),
        );
        expect(
          kotlin,
          stored.toKotlin(0, dataExpr: 'data').replaceFirst(
                'data.at',
                'hwParseIsoDate("2026-09-22T10:00:00.000Z")',
              ),
        );
        expect(swift, isNot(contains('entry.data')));
        expect(kotlin, isNot(contains('data.')));
        expect(text.nativeHelpers, stored.nativeHelpers);
        expect(text.nativeHelpers, contains(HWNativeHelper.hwParseIsoDate));
      });

      test('a fixed date in a plain HWText uses the default date format', () {
        const text = HWText(HWDateTime.fixed('2026-09-22T10:00:00Z'));

        expect(
          text.toSwift(0, dataExpr: 'entry.data'),
          'Text(hwParseIsoDate("2026-09-22T10:00:00.000Z").map { '
          'hwFormatDateStyled(\$0, dateStyle: .medium, timeStyle: .short) } '
          '?? "")',
        );
        expect(
          text.toKotlin(0, dataExpr: 'data'),
          'Text(text = hwParseIsoDate("2026-09-22T10:00:00.000Z")?.let { '
          'hwFormatDateStyled(it, java.text.DateFormat.MEDIUM, '
          'java.text.DateFormat.SHORT, hwFormatLocale(context)) } ?: "", '
          '$_defaultStyleArg)',
        );
      });

      test('a fixed number in a plain HWText uses the default number format',
          () {
        const whole = HWText(HWInt.fixed(3));
        const fraction = HWText(HWDouble.fixed(2.5));

        expect(
          whole.toSwift(0, dataExpr: 'entry.data'),
          'Text(hwFormatDecimal(NSNumber(value: 3.0), minFraction: nil, '
          'maxFraction: nil, grouping: true))',
        );
        expect(
          whole.toKotlin(0, dataExpr: 'data'),
          'Text(text = hwFormatDecimal(3.0, null, null, true, '
          'hwFormatLocale(context)), $_defaultStyleArg)',
        );
        expect(
          fraction.toSwift(0, dataExpr: 'entry.data'),
          'Text(hwFormatDecimal(NSNumber(value: 2.5), minFraction: nil, '
          'maxFraction: nil, grouping: true))',
        );
        expect(
          fraction.toKotlin(0, dataExpr: 'data'),
          'Text(text = hwFormatDecimal(2.5, null, null, true, '
          'hwFormatLocale(context)), $_defaultStyleArg)',
        );
      });

      test('a fixed flag renders as its text', () {
        const on = HWText(HWBool.fixed(true));
        const off = HWText(HWBool.fixed(false));

        expect(on.toSwift(0, dataExpr: 'entry.data'), 'Text("true")');
        expect(
          on.toKotlin(0, dataExpr: 'data'),
          'Text(text = "true", $_defaultStyleArg)',
        );
        expect(off.toSwift(0, dataExpr: 'entry.data'), 'Text("false")');
        expect(
          off.toKotlin(0, dataExpr: 'data'),
          'Text(text = "false", $_defaultStyleArg)',
        );
      });

      test('a fixed icon is no more text than a stored one', () {
        const text = HWText(
          HWIconData.resolvedFixed(
            0xe87d,
            iconFont: HWIconFont(family: 'MaterialIcons'),
          ),
        );

        expect(
          () => text.toSwift(0, dataExpr: 'entry.data'),
          throwsA(isA<GeneratorError>()),
        );
        expect(
          () => text.toKotlin(0, dataExpr: 'data'),
          throwsA(isA<GeneratorError>()),
        );
      });
    });

    test('does not name a plain fixed value as a data dependency', () {
      const texts = [
        HWText(HWString.fixed('Hi')),
        HWText.number(HWInt.fixed(3)),
        HWText.number(HWDouble.fixed(2.5)),
        HWText(HWBool.fixed(true)),
        HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00Z')),
      ];

      for (final text in texts) {
        expect(text.dataDependencies, isEmpty, reason: '${text.dataType}');
      }
    });
  });
}
