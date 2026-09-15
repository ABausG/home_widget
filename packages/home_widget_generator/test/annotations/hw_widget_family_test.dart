import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidgetFamily', () {
    test(
        'systemExtraLargePortrait sits between the landscape and accessory '
        'families', () {
      expect(HWWidgetFamily.values.map((family) => family.name), [
        'systemSmall',
        'systemMedium',
        'systemLarge',
        'systemExtraLarge',
        'systemExtraLargePortrait',
        'accessoryCircular',
        'accessoryRectangular',
        'accessoryInline',
      ]);
    });

    test('isAccessory is the three Lock Screen families', () {
      expect(
        HWWidgetFamily.values.where((family) => family.isAccessory),
        [
          HWWidgetFamily.accessoryCircular,
          HWWidgetFamily.accessoryRectangular,
          HWWidgetFamily.accessoryInline,
        ],
      );
    });

    test('slotName is the HWSizeAdaptive parameter carrying the family', () {
      expect(HWWidgetFamily.values.map((family) => family.slotName), [
        'small',
        'medium',
        'large',
        'extraLarge',
        'extraLargePortrait',
        'accessoryCircular',
        'accessoryRectangular',
        'accessoryInline',
      ]);
    });

    test('only the portrait extra-large needs a compiler gate', () {
      expect(
        HWWidgetFamily.systemExtraLargePortrait.swiftCompilerGate,
        '6.4',
      );
      expect(
        HWWidgetFamily.values
            .where((family) => family.swiftCompilerGate != null),
        [HWWidgetFamily.systemExtraLargePortrait],
      );
    });

    test('fallbackChain only ever goes down', () {
      expect(HWWidgetFamily.systemSmall.fallbackChain, isEmpty);
      expect(HWWidgetFamily.systemMedium.fallbackChain, [
        HWWidgetFamily.systemSmall,
      ]);
      expect(HWWidgetFamily.systemLarge.fallbackChain, [
        HWWidgetFamily.systemMedium,
        HWWidgetFamily.systemSmall,
      ]);
      expect(HWWidgetFamily.systemExtraLarge.fallbackChain, [
        HWWidgetFamily.systemLarge,
        HWWidgetFamily.systemMedium,
        HWWidgetFamily.systemSmall,
      ]);
    });

    test('systemExtraLargePortrait skips the landscape extra-large', () {
      expect(HWWidgetFamily.systemExtraLargePortrait.fallbackChain, [
        HWWidgetFamily.systemLarge,
        HWWidgetFamily.systemMedium,
        HWWidgetFamily.systemSmall,
      ]);
    });

    test('accessory families fall back to nothing', () {
      for (final family in HWWidgetFamily.values.where((f) => f.isAccessory)) {
        expect(family.fallbackChain, isEmpty, reason: family.name);
      }
    });

    test('androidCells mirror the iOS tile grid', () {
      expect(HWWidgetFamily.systemSmall.androidCells, (columns: 2, rows: 2));
      expect(HWWidgetFamily.systemMedium.androidCells, (columns: 4, rows: 2));
      expect(HWWidgetFamily.systemLarge.androidCells, (columns: 4, rows: 4));
      expect(
        HWWidgetFamily.systemExtraLarge.androidCells,
        (columns: 8, rows: 4),
      );
      expect(
        HWWidgetFamily.systemExtraLargePortrait.androidCells,
        (columns: 4, rows: 8),
      );
    });

    test('accessory families have no Android footprint', () {
      for (final family in HWWidgetFamily.values.where((f) => f.isAccessory)) {
        expect(family.androidCells, isNull, reason: family.name);
        expect(family.androidSize, isNull, reason: family.name);
      }
    });

    test('androidSize derives from the cell footprint', () {
      expect(HWWidgetFamily.systemSmall.androidSize, const HWSize(110, 110));
      expect(HWWidgetFamily.systemMedium.androidSize, const HWSize(250, 110));
      expect(HWWidgetFamily.systemLarge.androidSize, const HWSize(250, 250));
      expect(
        HWWidgetFamily.systemExtraLarge.androidSize,
        const HWSize(530, 250),
      );
      expect(
        HWWidgetFamily.systemExtraLargePortrait.androidSize,
        const HWSize(250, 530),
      );
    });

    test('androidSizeTable holds the five system families', () {
      expect(HWWidgetFamily.androidSizeTable(), {
        HWWidgetFamily.systemSmall: const HWSize(110, 110),
        HWWidgetFamily.systemMedium: const HWSize(250, 110),
        HWWidgetFamily.systemLarge: const HWSize(250, 250),
        HWWidgetFamily.systemExtraLarge: const HWSize(530, 250),
        HWWidgetFamily.systemExtraLargePortrait: const HWSize(250, 530),
      });
    });

    test('androidSizeTable replaces only the overridden entries', () {
      final table = HWWidgetFamily.androidSizeTable({
        HWWidgetFamily.systemMedium: const HWSize(200, 100),
      });
      expect(table[HWWidgetFamily.systemMedium], const HWSize(200, 100));
      expect(table[HWWidgetFamily.systemSmall], const HWSize(110, 110));
      expect(table[HWWidgetFamily.systemLarge], const HWSize(250, 250));
      expect(table.length, 5);
    });
  });
}
