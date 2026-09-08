import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

String swiftOf(HWNativeHelper helper) => helper.toSwift(0, dataExpr: 'd');

String kotlinOf(HWNativeHelper helper) => helper.toKotlin(0, dataExpr: 'd');

/// The name a Kotlin import line makes available: the alias when it has one,
/// otherwise the last segment of the imported path.
String importedName(String line) {
  final parts = line.split(' ');
  if (parts.length > 2 && parts[parts.length - 2] == 'as') return parts.last;
  return parts.last.split('.').last;
}

void main() {
  group('every helper', () {
    test('declares a function under its own name on both platforms', () {
      for (final helper in HWNativeHelper.values) {
        expect(
          swiftOf(helper),
          contains('func ${helper.name}('),
          reason: '${helper.name} Swift body',
        );
        expect(
          kotlinOf(helper),
          contains('private fun ${helper.name}('),
          reason: '${helper.name} Kotlin body',
        );
      }
    });

    test('is Swift file scope and Kotlin private top level', () {
      for (final helper in HWNativeHelper.values) {
        expect(
          swiftOf(helper).trimLeft(),
          startsWith('func '),
          reason: '${helper.name} Swift body',
        );
        expect(
          kotlinOf(helper).trimLeft(),
          startsWith('private fun '),
          reason: '${helper.name} Kotlin body',
        );
      }
    });

    test('ignores the arguments toSwift and toKotlin are handed', () {
      for (final helper in HWNativeHelper.values) {
        expect(
          helper.toSwift(3, dataExpr: 'entry.data'),
          swiftOf(helper),
          reason: '${helper.name} Swift body',
        );
        expect(
          helper.toKotlin(3, dataExpr: 'widgetData'),
          kotlinOf(helper),
          reason: '${helper.name} Kotlin body',
        );
      }
    });

    test('needs no Swift view modifiers', () {
      for (final helper in HWNativeHelper.values) {
        expect(helper.swiftViewModifiers, isEmpty, reason: helper.name);
      }
    });

    test('imports every Kotlin type its body names', () {
      final imported = {
        for (final helper in HWNativeHelper.values)
          helper: helper.kotlinImports.map(importedName).toSet(),
      };
      const shortNames = [
        'Build',
        'CompactDecimalFormat',
        'ConfigurationCompat',
        'Context',
        'Currency',
        'DateFormat',
        'DecimalFormat',
        'DecimalFormatSymbols',
        'NumberFormat',
        'SimpleDateFormat',
        'TimeZone',
      ];
      for (final helper in HWNativeHelper.values) {
        final kotlin = kotlinOf(helper);
        for (final name in shortNames) {
          if (!RegExp('\\b$name\\b').hasMatch(kotlin)) continue;
          expect(
            imported[helper],
            contains(name),
            reason: '${helper.name} uses $name without importing it',
          );
        }
      }
    });

    test('declares no import its Kotlin body does not use', () {
      for (final helper in HWNativeHelper.values) {
        final kotlin = kotlinOf(helper);
        for (final line in helper.kotlinImports) {
          final name = importedName(line);
          expect(
            RegExp('\\b$name\\b').hasMatch(kotlin),
            isTrue,
            reason: '${helper.name} imports $name and never uses it',
          );
        }
      }
    });

    test('calls only helpers it declares as dependencies', () {
      for (final helper in HWNativeHelper.values) {
        for (final other in HWNativeHelper.values) {
          if (other == helper) continue;
          if (helper.dependencies.contains(other)) continue;
          expect(
            swiftOf(helper),
            isNot(contains('${other.name}(')),
            reason: '${helper.name} calls ${other.name} undeclared (Swift)',
          );
          expect(
            kotlinOf(helper),
            isNot(contains('${other.name}(')),
            reason: '${helper.name} calls ${other.name} undeclared (Kotlin)',
          );
        }
      }
    });

    test('reaches its dependencies without a cycle', () {
      for (final helper in HWNativeHelper.values) {
        final seen = <HWNativeHelper>{};
        final path = <HWNativeHelper>[];
        void walk(HWNativeHelper current) {
          expect(
            path,
            isNot(contains(current)),
            reason: 'cycle through ${[...path, current].map((h) => h.name)}',
          );
          if (!seen.add(current)) return;
          path.add(current);
          current.dependencies.forEach(walk);
          path.removeLast();
        }

        walk(helper);
      }
    });

    test('renders locale-dependently unless it only reads a value back', () {
      const localeIndependent = {
        HWNativeHelper.hwParseIsoDate,
        HWNativeHelper.hwResolveTimeZone,
      };
      for (final helper in HWNativeHelper.values) {
        expect(
          helper.localeDependent,
          !localeIndependent.contains(helper),
          reason: helper.name,
        );
      }
      for (final helper in HWNativeHelper.values) {
        if (!helper.name.startsWith('hwFormat')) continue;
        expect(helper.localeDependent, isTrue, reason: helper.name);
      }
    });

    test('avoids APIs the platforms will not take', () {
      for (final helper in HWNativeHelper.values) {
        expect(
          swiftOf(helper),
          isNot(contains('Locale.isoCurrencyCodes')),
          reason: '${helper.name} uses a deprecated Swift API',
        );
        expect(
          kotlinOf(helper),
          isNot(contains('java.time')),
          reason: '${helper.name} needs desugaring on API 23',
        );
        expect(
          helper.kotlinImports,
          isNot(contains(startsWith('import java.time'))),
          reason: '${helper.name} needs desugaring on API 23',
        );
      }
    });
  });

  group('hwFormatLocale', () {
    const helper = HWNativeHelper.hwFormatLocale;

    test('reads the device locale on both platforms', () {
      expect(swiftOf(helper), contains('Locale.current'));
      expect(kotlinOf(helper), contains('ConfigurationCompat.getLocales('));
      expect(kotlinOf(helper), contains('Locale.getDefault()'));
      expect(
        helper.kotlinImports,
        containsAll([
          'import android.content.Context',
          'import androidx.core.os.ConfigurationCompat',
          'import java.util.Locale',
        ]),
      );
    });

    test('depends on nothing', () {
      expect(helper.dependencies, isEmpty);
    });
  });

  group('hwResolveTimeZone', () {
    const helper = HWNativeHelper.hwResolveTimeZone;

    test('falls back to the device zone on an unusable id', () {
      expect(swiftOf(helper), contains('TimeZone(identifier:'));
      expect(swiftOf(helper), contains('TimeZone.current'));
      expect(kotlinOf(helper), contains('TimeZone.getTimeZone(normalized)'));
      expect(kotlinOf(helper), contains('Regex("^(UTC|UT)(?=[+-])")'));
      expect(kotlinOf(helper), contains('zone.id == "GMT"'));
      expect(kotlinOf(helper), contains('TimeZone.getDefault()'));
      expect(helper.kotlinImports, ['import java.util.TimeZone']);
    });

    test('depends on nothing', () {
      expect(helper.dependencies, isEmpty);
    });
  });

  group('hwParseIsoDate', () {
    const helper = HWNativeHelper.hwParseIsoDate;

    test('parses ISO 8601 with the platform parsers', () {
      expect(swiftOf(helper), contains('ISO8601DateFormatter()'));
      expect(swiftOf(helper), contains('.withFractionalSeconds'));
      expect(swiftOf(helper), contains('.withInternetDateTime'));
      expect(
        kotlinOf(helper),
        contains('SimpleDateFormat("yyyy-MM-dd\'T\'HH:mm:ss.SSSZ"'),
      );
    });

    test('never throws at render time', () {
      expect(swiftOf(helper), contains('-> Date?'));
      expect(kotlinOf(helper), contains('catch'));
    });

    test('depends on nothing', () {
      expect(helper.dependencies, isEmpty);
    });
  });

  group('hwFormatDecimal', () {
    const helper = HWNativeHelper.hwFormatDecimal;

    test('formats through the platform number formatters', () {
      expect(swiftOf(helper), contains('NumberFormatter()'));
      expect(swiftOf(helper), contains('.decimal'));
      expect(
        kotlinOf(helper),
        contains('NumberFormat.getNumberInstance(locale)'),
      );
    });

    test('depends on the locale helper', () {
      expect(helper.dependencies, [HWNativeHelper.hwFormatLocale]);
    });
  });

  group('hwFormatPercent', () {
    const helper = HWNativeHelper.hwFormatPercent;

    test('formats through the platform percent formatters', () {
      expect(swiftOf(helper), contains('numberStyle = .percent'));
      expect(
        kotlinOf(helper),
        contains('NumberFormat.getPercentInstance(locale)'),
      );
    });

    test('depends on the locale helper', () {
      expect(helper.dependencies, [HWNativeHelper.hwFormatLocale]);
    });
  });

  group('hwFormatCurrency', () {
    const helper = HWNativeHelper.hwFormatCurrency;

    test('checks the code behind an availability guard on Swift', () {
      expect(swiftOf(helper), contains('#available(iOS 16.0'));
      expect(swiftOf(helper), contains('Locale.Currency.isoCurrencies'));
    });

    test('degrades to decimals on an unusable code', () {
      expect(swiftOf(helper), contains('isCode ? .currency : .decimal'));
      expect(kotlinOf(helper), contains('catch (_: IllegalArgumentException)'));
      expect(
        kotlinOf(helper),
        contains('NumberFormat.getNumberInstance(locale)'),
      );
    });

    test('takes the fraction digits from the currency, not the locale', () {
      final kotlin = kotlinOf(helper);
      expect(kotlin, contains('resolved.defaultFractionDigits'));
      expect(kotlin, contains('if (defaults >= 0)'));
      expect(kotlin, contains('minimumFractionDigits = defaults'));
      expect(kotlin, contains('maximumFractionDigits = defaults'));
      expect(swiftOf(helper), contains('formatter.currencyCode = isoCode'));
    });

    test('matches a lower-case code the way ISO 4217 spells it', () {
      expect(swiftOf(helper), contains('code.uppercased()'));
      expect(
        kotlinOf(helper),
        contains('Currency.getInstance(code.uppercase(Locale.ROOT))'),
      );
    });

    test('depends on the locale helper', () {
      expect(helper.dependencies, [HWNativeHelper.hwFormatLocale]);
    });
  });

  group('hwFormatCompact', () {
    const helper = HWNativeHelper.hwFormatCompact;

    test('guards the Android compact formatter by API level', () {
      final kotlin = kotlinOf(helper);
      final guard = kotlin.indexOf('Build.VERSION.SDK_INT >=');
      expect(guard, greaterThanOrEqualTo(0));
      expect(kotlin.indexOf('CompactDecimalFormat'), greaterThan(guard));
      expect(kotlin, contains('NumberFormat.getNumberInstance(locale)'));
      expect(
        helper.kotlinImports,
        contains('import android.icu.text.CompactDecimalFormat'),
      );
    });

    test('guards the iOS compact notation by availability', () {
      final swift = swiftOf(helper);
      final guard = swift.indexOf('#available(iOS 15.0');
      expect(guard, greaterThanOrEqualTo(0));
      expect(
        swift.indexOf('.number.notation(.compactName)'),
        greaterThan(guard),
      );
      expect(swift, contains('formatter.numberStyle = .decimal'));
    });

    test('depends on the locale helper', () {
      expect(helper.dependencies, [HWNativeHelper.hwFormatLocale]);
    });
  });

  group('hwFormatNumberPattern', () {
    const helper = HWNativeHelper.hwFormatNumberPattern;

    test('applies the pattern with the locale symbols', () {
      expect(swiftOf(helper), contains('positiveFormat'));
      expect(swiftOf(helper), contains('negativeFormat'));
      expect(
        kotlinOf(helper),
        contains(
          'DecimalFormat(pattern, DecimalFormatSymbols.getInstance(locale))',
        ),
      );
    });

    test('falls back to the plain decimal format on a bad pattern', () {
      final kotlin = kotlinOf(helper);
      expect(kotlin, contains('catch (_: IllegalArgumentException)'));
      expect(kotlin, contains('NumberFormat.getNumberInstance(locale)'));
    });

    test('depends on the locale helper', () {
      expect(helper.dependencies, [HWNativeHelper.hwFormatLocale]);
    });
  });

  group('hwFormatDateSkeleton', () {
    const helper = HWNativeHelper.hwFormatDateSkeleton;

    test('resolves the skeleton to a locale pattern', () {
      expect(
        swiftOf(helper),
        contains('DateFormatter.dateFormat(fromTemplate:'),
      );
      expect(
        kotlinOf(helper),
        contains('AndroidDateFormat.getBestDateTimePattern('),
      );
    });

    test('aliases the Android formatter the styled helper would shadow', () {
      expect(
        helper.kotlinImports,
        contains('import android.text.format.DateFormat as AndroidDateFormat'),
      );
      expect(
        HWNativeHelper.hwFormatDateStyled.kotlinImports,
        contains('import java.text.DateFormat'),
      );
    });

    test('depends on the locale and time zone helpers', () {
      expect(helper.dependencies, [
        HWNativeHelper.hwFormatLocale,
        HWNativeHelper.hwResolveTimeZone,
      ]);
    });
  });

  group('hwFormatDatePattern', () {
    const helper = HWNativeHelper.hwFormatDatePattern;

    test('applies the pattern verbatim', () {
      expect(swiftOf(helper), contains('formatter.dateFormat = '));
      expect(kotlinOf(helper), contains('SimpleDateFormat(pattern, locale)'));
    });

    test('falls back to the locale default on a bad pattern', () {
      final kotlin = kotlinOf(helper);
      expect(kotlin, contains('catch (_: IllegalArgumentException)'));
      expect(kotlin, contains('DateFormat.getDateTimeInstance('));
      expect(helper.kotlinImports, contains('import java.text.DateFormat'));
    });

    test('depends on the locale and time zone helpers', () {
      expect(helper.dependencies, [
        HWNativeHelper.hwFormatLocale,
        HWNativeHelper.hwResolveTimeZone,
      ]);
    });
  });

  group('hwFormatDateStyled', () {
    const helper = HWNativeHelper.hwFormatDateStyled;

    test('takes the platform style types, with no enum of its own', () {
      expect(swiftOf(helper), contains('dateStyle: DateFormatter.Style'));
      expect(swiftOf(helper), contains('timeStyle: DateFormatter.Style'));
      expect(kotlinOf(helper), contains('dateStyle: Int?'));
      expect(kotlinOf(helper), contains('timeStyle: Int?'));
      expect(kotlinOf(helper), contains('DateFormat.getDateTimeInstance('));
    });

    test('depends on the locale and time zone helpers', () {
      expect(helper.dependencies, [
        HWNativeHelper.hwFormatLocale,
        HWNativeHelper.hwResolveTimeZone,
      ]);
    });
  });
}
