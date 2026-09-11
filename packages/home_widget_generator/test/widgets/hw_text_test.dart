import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWText', () {
    group('model', () {
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

      test('localized constructor holds the raw locale map', () {
        const text = HWText.localized({'en': 'Hello', 'de': 'Hallo'});
        expect(text, isA<HWWidget>());
        expect(text.fixedContent, isNull);
        // The map cannot be wrapped by a const constructor, so it stays raw.
        expect(text.dataType, isNull);
        expect(text.localizedContent, {'en': 'Hello', 'de': 'Hallo'});
      });

      test('an unparsed localized map contributes no data dependency', () {
        // The raw map is inert; the parser is what turns it into a bound
        // HWLocalizedString, and only then does it become a dependency.
        const text = HWText.localized({'en': 'Hello', 'de': 'Hallo'});
        expect(text.dataDependencies, isEmpty);
      });

      test('the bound data type is the data dependency', () {
        const text = HWText(HWString('key'));
        expect(text.dataDependencies, {const HWString('key')});
      });

      test('fixed text has no data dependency', () {
        const text = HWText.fixed('Hello');
        expect(text.dataType, isNull);
        expect(text.dataDependencies, isEmpty);
      });
    });

    group('nested JSON data', () {
      const text = HWText(HWJson('payload', HWInt('count', defaultValue: 3)));

      test('Kotlin applies the leaf default before formatting', () {
        expect(
          text.toKotlin(0, dataExpr: 'widgetData'),
          'Text(text = hwFormatDecimal('
          '(widgetData.payload?.count ?: 3L), null, null, true, '
          'hwFormatLocale(context)))',
        );
      });

      test('Swift formats the resolved value', () {
        expect(
          text.toSwift(0, dataExpr: 'entry.data'),
          'Text(hwFormatDecimal(NSNumber(value: entry.data.payload?.count ?? 3), '
          'minFraction: nil, maxFraction: nil, grouping: true))',
        );
      });

      group('with a string leaf', () {
        const label =
            HWText(HWJson('payload', HWString('label', defaultValue: 'x')));

        test('Kotlin reads the leaf with its default', () {
          expect(
            label.toKotlin(0, dataExpr: 'widgetData'),
            'Text(text = (widgetData.payload?.label ?: "x"))',
          );
        });

        test('Swift reads the leaf with its default', () {
          expect(
            label.toSwift(0, dataExpr: 'entry.data'),
            'Text((((entry.data.payload?.label) ?? ("x"))))',
          );
        });
      });
    });

    group('iOS (SwiftUI)', () {
      test('emits fixed text', () {
        final node = HWText.fixed('Hello');
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, 'Text("Hello")');
      });

      test('emits string data ref', () {
        final node = HWText(HWString('label'));
        final result = node.toSwift(
          0,
          dataExpr: 'data',
        );
        expect(result, 'Text(data.label ?? "")');
      });

      test('emits int data ref in the default decimal format', () {
        final node = HWText(HWInt('count'));
        final result = node.toSwift(
          0,
          dataExpr: 'data',
        );
        expect(
          result,
          'Text(hwFormatDecimal(NSNumber(value: data.count ?? 0), minFraction: nil, '
          'maxFraction: nil, grouping: true))',
        );
      });

      test('emits bool data ref', () {
        final node = HWText(HWBool('flag'));
        final result = node.toSwift(
          0,
          dataExpr: 'data',
        );
        expect(result, 'Text(data.flag != nil ? "\\(data.flag!)" : "false")');
      });

      test('emits double data ref in the default decimal format', () {
        final node = HWText(HWDouble('ratio'));
        final result = node.toSwift(
          0,
          dataExpr: 'data',
        );
        expect(
          result,
          'Text(hwFormatDecimal(NSNumber(value: data.ratio ?? 0.0), minFraction: nil, '
          'maxFraction: nil, grouping: true))',
        );
      });

      test('escapes strings', () {
        final node = HWText.fixed('He said "Hi"');
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, 'Text("He said \\"Hi\\"")');
      });

      test('respects indent', () {
        final node = HWText.fixed('Hello');
        final result = node.toSwift(1, dataExpr: 'data');
        expect(result, '    Text("Hello")');
      });

      test('swiftViewModifiers: empty without style', () {
        expect(HWText.fixed('x').swiftViewModifiers, isEmpty);
      });

      test(
          'swiftViewModifiers: empty for role text (font chain is in toSwift only)',
          () {
        final node = HWText.fixed('a', style: HWRoleTextStyle.headline());
        expect(node.swiftViewModifiers, isEmpty);
      });

      test(
        'swiftViewModifiers: include colorScheme when color is HWThemedColor',
        () {
          final node = HWText.fixed(
            'Hi',
            style: const HWTextStyle(
              color: HWThemedColor(
                light: HWFixedColor(0xFF000000),
                dark: HWFixedColor(0xFFFFFFFF),
              ),
            ),
          );
          expect(
            node.swiftViewModifiers,
            contains('@Environment(\\.colorScheme) var colorScheme'),
          );
        },
      );

      test('with style, Text uses view modifiers in output', () {
        final node = HWText.fixed(
          'Styled',
          style: HWTextStyle(
            fontSize: 24,
            fontWeight: HWFontWeight.bold,
            italic: true,
            underline: true,
            color: HWFixedColor(0xFFFF0000),
          ),
          textAlign: HWTextAlign.center,
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('Text("Styled")'));
        expect(result, contains('.font(.system(size: 24.0, weight: .bold))'));
        expect(
          result,
          contains(
            '.foregroundColor(Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))',
          ),
        );
        expect(result, contains('.italic()'));
        expect(result, contains('.underline(true)'));
        expect(result, contains('.multilineTextAlignment(.center)'));
      });

      test('textAlign justify maps to leading in Swift (LTR fallback)', () {
        const node = HWText.fixed('J', textAlign: HWTextAlign.justify);
        final r = node.toSwift(0, dataExpr: 'd');
        expect(r, contains('.multilineTextAlignment(.leading)'));
      });

      test('strikethrough in Swift from lineThrough', () {
        final node = HWText.fixed(
          'S',
          style: const HWTextStyle(lineThrough: true),
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('.strikethrough(true)'));
      });

      test('HWRoleTextStyle adds fontWeight when set with role', () {
        final node = HWText.fixed(
          'R',
          style: HWRoleTextStyle.headline(
            fontWeight: HWFontWeight.w700,
          ),
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('.font(.headline)'));
        expect(r, contains('.fontWeight(.bold)'));
      });

      test('only fontWeight without size or role in Swift', () {
        const node = HWText.fixed(
          'W',
          style: HWTextStyle(fontWeight: HWFontWeight.w500),
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('.fontWeight(.medium)'));
        expect(r, isNot(contains('.font(')));
      });

      test('HWRoleTextStyle body, callout, caption, captionSmall in Swift', () {
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.body())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.body)'),
        );
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.callout())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.callout)'),
        );
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.caption())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.caption)'),
        );
        expect(
          HWText.fixed('X', style: HWRoleTextStyle.captionSmall())
              .toSwift(0, dataExpr: 'data'),
          contains('.font(.caption2)'),
        );
      });

      test('HWRoleTextStyle emits semantic font', () {
        final node = HWText.fixed('Role', style: HWRoleTextStyle.headline());
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.font(.headline)'));
      });

      test('HWRoleTextStyle overridden by explicit size', () {
        final node = HWText.fixed(
          'Role Override',
          style: HWRoleTextStyle.headline(fontSize: 30),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.font(.system(size: 30.0))'));
      });

      test('HWTextStyle baseStyle resolution', () {
        final node = HWText.fixed(
          'Base Base',
          style: HWTextStyle(
            color: HWFixedColor(0xFF00FF00),
            baseStyle: HWRoleTextStyle.title(
              italic: true,
            ),
          ),
        );
        final result = node.toSwift(0, dataExpr: 'data');
        expect(result, contains('.font(.title)'));
        expect(result, contains('.italic()'));
        expect(result, contains('green: 1.0'));
      });
    });

    group('Android (Glance)', () {
      test('HWTextStyle kotlinImports add sp, FontWeight, or TextDecoration',
          () {
        expect(
          const HWTextStyle(fontSize: 12).kotlinImports,
          contains('import androidx.compose.ui.unit.sp'),
        );
        expect(
          const HWTextStyle(fontWeight: HWFontWeight.w500).kotlinImports,
          contains('import androidx.glance.text.FontWeight'),
        );
        expect(
          const HWTextStyle(underline: true).kotlinImports,
          contains('import androidx.glance.text.TextDecoration'),
        );
      });

      test('kotlinImports include TextAlign when textAlign is set', () {
        final w = HWText.fixed('x', textAlign: HWTextAlign.end);
        expect(
          w.kotlinImports,
          contains('import androidx.glance.text.TextAlign'),
        );
      });

      test(
          'textAlign only, no style: style is TextStyle with only align in Kotlin',
          () {
        const node = HWText.fixed('Hi', textAlign: HWTextAlign.end);
        final r = node.toKotlin(0, dataExpr: 'd');
        expect(
          r,
          contains(
            'Text(text = "Hi", style = TextStyle(textAlign = TextAlign.End))',
          ),
        );
      });

      test('textAlign justify uses Start in Kotlin (fallback)', () {
        const node = HWText.fixed('J', textAlign: HWTextAlign.justify);
        final r = node.toKotlin(0, dataExpr: 'd');
        expect(
          r,
          contains('TextStyle(textAlign = TextAlign.Start)'),
        );
      });

      test('kotlinImports include Text', () {
        final w = HWText.fixed('x');
        expect(w.kotlinImports, contains('import androidx.glance.text.Text'));
        expect(
          w.kotlinImports,
          contains('import androidx.glance.text.TextStyle'),
        );
      });

      test('emits fixed text', () {
        final node = HWText.fixed('Hello');
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, 'Text(text = "Hello")');
      });

      test('emits string data ref', () {
        final node = HWText(HWString('label'));
        final result = node.toKotlin(
          0,
          dataExpr: 'data',
        );
        expect(result, 'Text(text = data.label ?: "")');
      });

      test('emits int data ref in the default decimal format', () {
        final node = HWText(HWInt('count'));
        final result = node.toKotlin(
          0,
          dataExpr: 'data',
        );
        expect(
          result,
          'Text(text = hwFormatDecimal((data.count ?: 0L), '
          'null, null, true, hwFormatLocale(context)))',
        );
      });

      test('emits bool data ref', () {
        final node = HWText(HWBool('flag'));
        final result = node.toKotlin(
          0,
          dataExpr: 'data',
        );
        expect(result, 'Text(text = (data.flag?.toString() ?: "false"))');
      });

      test('emits double data ref in the default decimal format', () {
        final node = HWText(HWDouble('ratio'));
        final result = node.toKotlin(
          0,
          dataExpr: 'data',
        );
        expect(
          result,
          'Text(text = hwFormatDecimal((data.ratio ?: 0.0), '
          'null, null, true, hwFormatLocale(context)))',
        );
      });

      test('escapes strings', () {
        final node = HWText.fixed('Price: \$5');
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, 'Text(text = "Price: \\\$5")');
      });

      test('respects indent', () {
        final node = HWText.fixed('Hello');
        final result = node.toKotlin(1, dataExpr: 'data');
        expect(result, '    Text(text = "Hello")');
      });

      test('style and textAlign in Glance output', () {
        final node = HWText.fixed(
          'Styled',
          style: HWTextStyle(
            fontSize: 24,
            fontWeight: HWFontWeight.bold,
            italic: true,
            underline: true,
            color: HWFixedColor(0xFFFF0000),
          ),
          textAlign: HWTextAlign.center,
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('fontSize = 24.sp'));
        expect(result, contains('fontWeight = FontWeight.Bold'));
        expect(result, contains('fontStyle = FontStyle.Italic'));
        expect(result, contains('textDecoration = TextDecoration.Underline'));
        expect(result, contains('textAlign = TextAlign.Center'));
      });

      test('strikethrough in Kotlin from lineThrough only', () {
        const node = HWText.fixed(
          'S',
          style: HWTextStyle(lineThrough: true),
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('textDecoration = TextDecoration.LineThrough'),
        );
      });

      test('combines Underline and LineThrough in Kotlin', () {
        const node = HWText.fixed(
          'B',
          style: HWTextStyle(
            underline: true,
            lineThrough: true,
            color: HWFixedColor(0xFF0000FF),
          ),
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          allOf(
            contains('TextDecoration.combine'),
            contains('TextDecoration.Underline'),
            contains('TextDecoration.LineThrough'),
          ),
        );
      });

      test('HWRoleTextStyle body, callout, caption, captionSmall in Glance',
          () {
        for (final entry in <(int, HWRoleTextStyle)>[
          (16, HWRoleTextStyle.body()),
          (14, HWRoleTextStyle.callout()),
          (12, HWRoleTextStyle.caption()),
          (11, HWRoleTextStyle.captionSmall()),
        ]) {
          final r =
              HWText.fixed('X', style: entry.$2).toKotlin(0, dataExpr: 'data');
          expect(
            r,
            contains('fontSize = ${entry.$1}.sp'),
            reason: 'fontSize ${entry.$1}',
          );
        }
      });

      test('HWRoleTextStyle emits default metrics when unprovided', () {
        final node = HWText.fixed('Role', style: HWRoleTextStyle.headline());
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('fontSize = 18.sp'));
        expect(result, contains('fontWeight = FontWeight.Medium'));
      });

      test('HWTextStyle baseStyle resolution', () {
        final node = HWText.fixed(
          'Base Base',
          style: HWTextStyle(
            color: HWFixedColor(0xFF00FF00),
            baseStyle: HWRoleTextStyle.title(
              italic: true,
            ),
          ),
        );
        final result = node.toKotlin(0, dataExpr: 'data');
        expect(result, contains('fontSize = 22.sp'));
        expect(result, contains('fontStyle = FontStyle.Italic'));
        expect(result, contains('0xFF00FF00'));
      });
    });
  });

  group('HWText.number', () {
    test('model: carries the format and the bound data', () {
      const text = HWText.number(
        HWInt('steps'),
        format: HWNumberFormat.compact(),
      );
      expect(text.dataType, const HWInt('steps'));
      expect(text.numberFormat, const HWNumberFormat.compact());
      expect(text.dateFormat, isNull);
      expect(text.fixedNumber, isNull);
      expect(text.formatsNumber, isTrue);
      expect(text.formatsDate, isFalse);
      expect(text.dataDependencies, {const HWInt('steps')});
    });

    test('a plain number text also formats', () {
      expect(const HWText(HWInt('c')).formatsNumber, isTrue);
      expect(const HWText(HWDouble('c')).formatsNumber, isTrue);
      expect(const HWText(HWTimedData(HWInt('c'))).formatsNumber, isTrue);
      expect(const HWText(HWJson('p', HWDouble('c'))).formatsNumber, isTrue);
      expect(const HWText(HWString('c')).formatsNumber, isFalse);
      expect(const HWText.fixed('c').formatsNumber, isFalse);
    });

    test('decimal with explicit digits and grouping off', () {
      const text = HWText.number(
        HWDouble('v'),
        format: HWNumberFormat.decimal(
          minimumFractionDigits: 1,
          maximumFractionDigits: 2,
          useGrouping: false,
        ),
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatDecimal(NSNumber(value: entry.data.v ?? 0.0), minFraction: 1, '
        'maxFraction: 2, grouping: false))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatDecimal((widgetData.v ?: 0.0), 1, 2, false, '
        'hwFormatLocale(context)))',
      );
    });

    test('percent', () {
      const text = HWText.number(
        HWDouble('progress'),
        format: HWNumberFormat.percent(maximumFractionDigits: 0),
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatPercent(NSNumber(value: entry.data.progress ?? 0.0), minFraction: nil, '
        'maxFraction: 0))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatPercent((widgetData.progress ?: 0.0), null, 0, '
        'hwFormatLocale(context)))',
      );
    });

    test('compact converts an int to a double first', () {
      const text = HWText.number(
        HWInt('steps'),
        format: HWNumberFormat.compact(),
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatCompact(NSNumber(value: entry.data.steps ?? 0)))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatCompact((widgetData.steps ?: 0L), '
        'hwFormatLocale(context)))',
      );
    });

    test('pattern', () {
      const text = HWText.number(
        HWDouble('v'),
        format: HWNumberFormat.pattern('#,##0.00'),
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatNumberPattern(NSNumber(value: entry.data.v ?? 0.0), "#,##0.00"))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatNumberPattern((widgetData.v ?: 0.0), '
        '"#,##0.00", hwFormatLocale(context)))',
      );
    });

    test('currency with a fixed code', () {
      const text = HWText.number(
        HWDouble('price'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.code('EUR'),
          decimalDigits: 2,
        ),
      );
      expect(text.dataDependencies, {const HWDouble('price')});
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatCurrency(NSNumber(value: entry.data.price ?? 0.0), code: "EUR", '
        'decimals: 2))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatCurrency((widgetData.price ?: 0.0), "EUR", 2, '
        'hwFormatLocale(context)))',
      );
    });

    test('currency read from a data field, which becomes a dependency', () {
      const text = HWText.number(
        HWDouble('price'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWString('cur')),
        ),
      );
      expect(
        text.dataDependencies,
        {const HWDouble('price'), const HWString('cur')},
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatCurrency(NSNumber(value: entry.data.price ?? 0.0), '
        'code: entry.data.cur ?? "", decimals: nil))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatCurrency((widgetData.price ?: 0.0), '
        'widgetData.cur ?: "", null, hwFormatLocale(context)))',
      );
    });

    test('a JSON-nested currency field reads through its path', () {
      const text = HWText.number(
        HWDouble('price'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWJson('cfg', HWString('cur'))),
        ),
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        contains('code: entry.data.cfg?.cur ?? ""'),
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        contains('hwFormatCurrency((widgetData.price ?: 0.0), '
            'widgetData.cfg?.cur ?: "", null, '),
      );
    });

    test('a timed or JSON-wrapped number formats through its own path', () {
      expect(
        const HWText.number(
          HWTimedData(HWInt('steps')),
          format: HWNumberFormat.compact(),
        ).toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatCompact(NSNumber(value: entry.data.steps ?? 0)))',
      );
      expect(
        const HWText.number(
          HWJson('payload', HWDouble('v')),
          format: HWNumberFormat.compact(),
        ).toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatCompact((widgetData.payload?.v ?: 0.0), '
        'hwFormatLocale(context)))',
      );
    });

    test('style and alignment still apply', () {
      const text = HWText.number(
        HWInt('c'),
        style: HWTextStyle(fontSize: 12),
        textAlign: HWTextAlign.center,
      );
      expect(
        text.toSwift(0, dataExpr: 'd'),
        contains('.multilineTextAlignment(.center)'),
      );
      expect(text.toKotlin(0, dataExpr: 'd'), contains('fontSize = 12.sp'));
    });
  });

  group('HWText.fixedNumber', () {
    test('model: carries the value and no data dependency', () {
      const text = HWText.fixedNumber(1234);
      expect(text.fixedNumber, 1234);
      expect(text.dataType, isNull);
      expect(text.dataDependencies, isEmpty);
      expect(text.formatsNumber, isTrue);
    });

    test('an int is emitted as a floating point literal on both platforms', () {
      const text = HWText.fixedNumber(1234);
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(hwFormatDecimal(NSNumber(value: 1234.0), minFraction: nil, '
        'maxFraction: nil, grouping: true))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = hwFormatDecimal(1234.0, null, null, true, '
        'hwFormatLocale(context)))',
      );
    });

    test('a double keeps its own literal', () {
      const text = HWText.fixedNumber(12.5, format: HWNumberFormat.compact());
      expect(
        text.toSwift(0, dataExpr: 'd'),
        'Text(hwFormatCompact(NSNumber(value: 12.5)))',
      );
      expect(
        text.toKotlin(0, dataExpr: 'd'),
        'Text(text = hwFormatCompact(12.5, hwFormatLocale(context)))',
      );
    });

    test('a data-bound currency is still a dependency', () {
      const text = HWText.fixedNumber(
        9.99,
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWString('cur')),
        ),
      );
      expect(text.dataDependencies, {const HWString('cur')});
    });
  });

  group('HWText.dateTime', () {
    test('model: carries the format and defaults to the device zone', () {
      const text = HWText.dateTime(HWDateTime('when'));
      expect(text.dataType, const HWDateTime('when'));
      expect(text.dateFormat, HWDateFormat.defaultFormat);
      expect(text.timeZone, HWTimeZone.local);
      expect(text.formatsDate, isTrue);
      expect(text.formatsNumber, isFalse);
      expect(text.dataDependencies, {const HWDateTime('when')});
    });

    test('a plain HWText on a date equals the default format', () {
      const plain = HWText(HWDateTime('when'));
      const explicit = HWText.dateTime(HWDateTime('when'));
      expect(
        plain.toSwift(0, dataExpr: 'entry.data'),
        explicit.toSwift(0, dataExpr: 'entry.data'),
      );
      expect(
        plain.toKotlin(0, dataExpr: 'widgetData'),
        explicit.toKotlin(0, dataExpr: 'widgetData'),
      );
      expect(plain.formatsDate, isTrue);
    });

    test('styled default format, empty when there is no date', () {
      const text = HWText.dateTime(HWDateTime('when'));
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(entry.data.when.map { hwFormatDateStyled(\$0, '
        'dateStyle: .medium, timeStyle: .short) } ?? "")',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = widgetData.when?.let { hwFormatDateStyled(it, '
        'java.text.DateFormat.MEDIUM, java.text.DateFormat.SHORT, '
        'hwFormatLocale(context)) } ?: "")',
      );
    });

    test('a skeleton constant', () {
      const text = HWText.dateTime(
        HWDateTime('when'),
        format: HWDateFormat.yMMMd,
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(entry.data.when.map { hwFormatDateSkeleton(\$0, "yMMMd") } '
        '?? "")',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = widgetData.when?.let { hwFormatDateSkeleton(it, '
        '"yMMMd", hwFormatLocale(context)) } ?: "")',
      );
    });

    test('an explicit pattern', () {
      const text = HWText.dateTime(
        HWDateTime('when'),
        format: HWDateFormat.pattern('dd.MM.yyyy HH:mm'),
      );
      expect(
        text.toSwift(0, dataExpr: 'd'),
        contains('hwFormatDatePattern(\$0, "dd.MM.yyyy HH:mm")'),
      );
      expect(
        text.toKotlin(0, dataExpr: 'd'),
        contains('hwFormatDatePattern(it, "dd.MM.yyyy HH:mm", '),
      );
    });

    test('a styled format may leave one half out', () {
      const text = HWText.dateTime(
        HWDateTime('when'),
        format: HWDateFormat.styled(date: HWFormatStyle.full),
      );
      expect(
        text.toSwift(0, dataExpr: 'd'),
        contains('dateStyle: .full, timeStyle: .none'),
      );
      expect(
        text.toKotlin(0, dataExpr: 'd'),
        contains('hwFormatDateStyled(it, java.text.DateFormat.FULL, null, '),
      );
    });

    test('a date inside JSON formats through its path', () {
      const text = HWText.dateTime(HWJson('payload', HWDateTime('when')));
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(entry.data.payload?.when.map { hwFormatDateStyled(\$0, '
        'dateStyle: .medium, timeStyle: .short) } ?? "")',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = widgetData.payload?.when?.let { hwFormatDateStyled(it, '
        'java.text.DateFormat.MEDIUM, java.text.DateFormat.SHORT, '
        'hwFormatLocale(context)) } ?: "")',
      );
    });
  });

  group('HWText.dateTime time zones', () {
    test('local omits the argument', () {
      const text = HWText.dateTime(HWDateTime('when'));
      expect(text.toSwift(0, dataExpr: 'd'), isNot(contains('timeZone')));
      expect(
        text.toKotlin(0, dataExpr: 'd'),
        contains('hwFormatLocale(context)) } ?: ""'),
      );
    });

    test('utc passes the UTC id', () {
      const text =
          HWText.dateTime(HWDateTime('when'), timeZone: HWTimeZone.utc);
      expect(text.toSwift(0, dataExpr: 'd'), contains('timeZone: "UTC"'));
      expect(
        text.toKotlin(0, dataExpr: 'd'),
        contains('hwFormatLocale(context), "UTC")'),
      );
    });

    test('a named zone passes its IANA id', () {
      const text = HWText.dateTime(
        HWDateTime('when'),
        timeZone: HWTimeZone.named('Europe/Berlin'),
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        'Text(entry.data.when.map { hwFormatDateStyled(\$0, '
        'dateStyle: .medium, timeStyle: .short, timeZone: "Europe/Berlin") } '
        '?? "")',
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        'Text(text = widgetData.when?.let { hwFormatDateStyled(it, '
        'java.text.DateFormat.MEDIUM, java.text.DateFormat.SHORT, '
        'hwFormatLocale(context), "Europe/Berlin") } ?: "")',
      );
    });

    test('a data zone passes the nullable field and becomes a dependency', () {
      const text = HWText.dateTime(
        HWDateTime('when'),
        timeZone: HWTimeZone.data(HWString('tz')),
      );
      expect(
        text.dataDependencies,
        {const HWDateTime('when'), const HWString('tz')},
      );
      expect(
        text.toSwift(0, dataExpr: 'entry.data'),
        contains('timeZone: entry.data.tz)'),
      );
      expect(
        text.toKotlin(0, dataExpr: 'widgetData'),
        contains('hwFormatLocale(context), widgetData.tz)'),
      );
    });

    test('a timed zone field reads through the unwrapped access', () {
      const text = HWText.dateTime(
        HWDateTime('when'),
        timeZone: HWTimeZone.data(HWTimedData(HWString('tz'))),
      );
      expect(text.toSwift(0, dataExpr: 'd'), contains('timeZone: d.tz)'));
      expect(
        text.toKotlin(0, dataExpr: 'd'),
        contains('hwFormatLocale(context), d.tz)'),
      );
    });
  });

  group('HWText multi-line content', () {
    // Regression: the escapers used to leave newlines raw, which produced an
    // unterminated string literal in both languages.
    const text = HWText.fixed('line1\nline2\ttabbed');

    test('escapes newlines and tabs in Kotlin', () {
      final kotlin = text.toKotlin(0, dataExpr: 'null');
      expect(kotlin.split('\n'), hasLength(1));
      expect(kotlin, contains(r'line1\nline2\ttabbed'));
    });

    test('escapes newlines and tabs in Swift', () {
      final swift = text.toSwift(0, dataExpr: 'null');
      expect(swift.split('\n'), hasLength(1));
      expect(swift, contains(r'line1\nline2\ttabbed'));
    });
  });

  group('typed data parameters', () {
    test('HWText.number takes a number however it is wrapped', () {
      const plain = HWText.number(HWInt('steps'));
      const timed = HWText.number(HWTimedData(HWDouble('steps')));
      const nested = HWText.number(HWJson('stats', HWInt('steps')));
      const both = HWText.number(HWTimedData(HWJson('stats', HWInt('steps'))));

      for (final text in [plain, timed, nested, both]) {
        expect(text.formatsNumber, isTrue);
        expect(text.toSwift(0, dataExpr: 'entry.data'), startsWith('Text('));
        expect(text.toKotlin(0, dataExpr: 'widgetData'), startsWith('Text('));
      }
      expect(
        plain.toSwift(0, dataExpr: 'entry.data'),
        contains('NSNumber(value: entry.data.steps ?? 0)'),
      );
      expect(
        nested.toKotlin(0, dataExpr: 'widgetData'),
        contains('(widgetData.stats?.steps ?: 0L)'),
      );
    });

    test('HWText.dateTime takes a date however it is wrapped', () {
      const plain = HWText.dateTime(HWDateTime('when'));
      const timed = HWText.dateTime(HWTimedData(HWDateTime('when')));
      const nested = HWText.dateTime(HWJson('event', HWDateTime('when')));
      const both =
          HWText.dateTime(HWTimedData(HWJson('event', HWDateTime('when'))));

      for (final text in [plain, timed, nested, both]) {
        expect(text.formatsDate, isTrue);
        expect(text.toSwift(0, dataExpr: 'entry.data'), startsWith('Text('));
        expect(text.toKotlin(0, dataExpr: 'widgetData'), startsWith('Text('));
      }
      expect(
        plain.toSwift(0, dataExpr: 'entry.data'),
        contains('entry.data.when.map {'),
      );
      expect(
        nested.toKotlin(0, dataExpr: 'widgetData'),
        contains('widgetData.event?.when?.let {'),
      );
    });

    test('a currency code field is a dependency however it is wrapped', () {
      const plain = HWText.number(
        HWDouble('total'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWString('cur')),
        ),
      );
      const timed = HWText.number(
        HWDouble('total'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWTimedData(HWString('cur'))),
        ),
      );
      const nested = HWText.number(
        HWDouble('total'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWJson('cfg', HWString('cur'))),
        ),
      );

      expect(plain.dataDependencies, {
        const HWDouble('total'),
        const HWString('cur'),
      });
      expect(timed.dataDependencies, {
        const HWDouble('total'),
        const HWTimedData(HWString('cur')),
      });
      expect(
        nested.toSwift(0, dataExpr: 'entry.data'),
        contains('code: entry.data.cfg?.cur ?? ""'),
      );
    });

    test('a time zone field is a dependency however it is wrapped', () {
      const plain = HWText.dateTime(
        HWDateTime('when'),
        timeZone: HWTimeZone.data(HWString('tz')),
      );
      const timed = HWText.dateTime(
        HWDateTime('when'),
        timeZone: HWTimeZone.data(HWTimedData(HWString('tz'))),
      );
      const nested = HWText.dateTime(
        HWDateTime('when'),
        timeZone: HWTimeZone.data(HWJson('cfg', HWString('tz'))),
      );

      expect(plain.dataDependencies, {
        const HWDateTime('when'),
        const HWString('tz'),
      });
      expect(timed.dataDependencies, {
        const HWDateTime('when'),
        const HWTimedData(HWString('tz')),
      });
      expect(
        nested.toKotlin(0, dataExpr: 'widgetData'),
        contains('hwFormatLocale(context), widgetData.cfg?.tz)'),
      );
    });
  });

  group('nativeHelpers', () {
    Set<String> namesOf(HWWidget widget) =>
        widget.nativeHelpers.map((h) => h.name).toSet();

    test('a text with no formatting needs none', () {
      expect(namesOf(const HWText.fixed('hi')), isEmpty);
      expect(namesOf(const HWText(HWString('label'))), isEmpty);
    });

    test('a plain number renders in the default decimal format', () {
      const text = HWText(HWInt('steps'));
      expect(text.effectiveNumberFormat, HWNumberFormat.defaultFormat);
      expect(namesOf(text), {'hwFormatDecimal'});
      expect(namesOf(const HWText(HWDouble('ratio'))), {'hwFormatDecimal'});
      expect(
        namesOf(const HWText(HWJson('payload', HWInt('count')))),
        {'hwFormatDecimal'},
      );
    });

    test('an explicit format names its own helper', () {
      expect(
        namesOf(
          const HWText.number(
            HWInt('steps'),
            format: HWNumberFormat.compact(),
          ),
        ),
        {'hwFormatCompact'},
      );
      expect(
        namesOf(const HWText.fixedNumber(1, format: HWNumberFormat.percent())),
        {'hwFormatPercent'},
      );
    });

    test('a date names the parser and the format helper', () {
      const text = HWText(HWDateTime('when'));
      expect(text.effectiveDateFormat, HWDateFormat.defaultFormat);
      expect(namesOf(text), {'hwParseIsoDate', 'hwFormatDateStyled'});
      expect(
        namesOf(
          const HWText.dateTime(HWDateTime('when'), format: HWDateFormat.yMMMd),
        ),
        {'hwParseIsoDate', 'hwFormatDateSkeleton'},
      );
    });

    test('a display zone adds the zone resolver', () {
      expect(
        namesOf(
          const HWText.dateTime(
            HWDateTime('when'),
            timeZone: HWTimeZone.named('Europe/Berlin'),
          ),
        ),
        {'hwParseIsoDate', 'hwFormatDateStyled', 'hwResolveTimeZone'},
      );
    });

    test('a localized JSON leaf is resolved where the text renders it', () {
      const leaf = HWLocalizedString(
        'name',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      );
      const resolvers = {'hwCurrentLocales', 'hwResolveLocalized'};
      expect(namesOf(const HWText(HWJson('profile', leaf))), resolvers);
      expect(
        namesOf(const HWText(HWTimedData(HWJson('profile', leaf)))),
        resolvers,
      );
      // A keyed string is resolved as it is read instead.
      expect(namesOf(const HWText(leaf)), {'hwReadLocalized'});
    });

    test('a date nobody displays still needs the parser', () {
      const tree = HWDataExists(
        data: HWDateTime('when'),
        whenPresent: HWText.fixed('yes'),
        whenAbsent: HWText.fixed('no'),
      );
      expect(namesOf(tree), {'hwParseIsoDate'});
    });

    test('a container collects from its whole subtree', () {
      const tree = HWColumn(
        children: [
          HWText(HWInt('steps')),
          HWText.dateTime(
            HWDateTime('when'),
            format: HWDateFormat.pattern('dd.MM.yyyy'),
          ),
        ],
      );
      expect(namesOf(tree), {
        'hwFormatDecimal',
        'hwParseIsoDate',
        'hwFormatDatePattern',
      });
    });
  });
}
