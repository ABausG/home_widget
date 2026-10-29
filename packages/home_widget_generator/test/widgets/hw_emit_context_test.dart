import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWKotlinRoom', () {
    test('asks for nothing by default', () {
      const room = HWKotlinRoom();
      expect(room.modifiers, isEmpty);
      expect(room.kotlinImports, isEmpty);
    });

    test('a weight needs no import', () {
      const room = HWKotlinRoom(weight: true);
      expect(room.modifiers, ['defaultWeight()']);
      expect(room.kotlinImports, isEmpty);
    });

    test('fills one axis or both', () {
      const width = HWKotlinRoom(fillsWidth: true);
      expect(width.modifiers, ['fillMaxWidth()']);
      expect(
        width.kotlinImports,
        {'import androidx.glance.layout.fillMaxWidth'},
      );

      const height = HWKotlinRoom(fillsHeight: true);
      expect(height.modifiers, ['fillMaxHeight()']);
      expect(
        height.kotlinImports,
        {'import androidx.glance.layout.fillMaxHeight'},
      );

      const both = HWKotlinRoom(fillsWidth: true, fillsHeight: true);
      expect(both.modifiers, ['fillMaxSize()']);
      expect(both.kotlinImports, {'import androidx.glance.layout.fillMaxSize'});
    });

    test('chains the weight before a fill', () {
      const room = HWKotlinRoom(weight: true, fillsWidth: true);
      expect(room.modifiers, ['defaultWeight()', 'fillMaxWidth()']);
    });
  });

  group('HWEmitContext', () {
    const families = {HWWidgetFamily.systemSmall};
    const sizes = {HWWidgetFamily.systemSmall: HWSize(110, 110)};

    test('is outside every list item by default', () {
      expect(const HWEmitContext().itemList, isNull);
    });

    test('enters the item of a builder, keeping everything else', () {
      const context = HWEmitContext(
        reachableFamilies: families,
        androidSizeTable: sizes,
        enclosingLinearAxis: HWAxis.vertical,
      );
      final item = context.inItemOf('forecast');

      expect(item.itemList, 'forecast');
      expect(item.reachableFamilies, families);
      expect(item.androidSizeTable, sizes);
      expect(item.enclosingLinearAxis, HWAxis.vertical);
    });

    test('keeps the list across the layouts inside the item', () {
      final item = const HWEmitContext(reachableFamilies: families)
          .inItemOf('forecast')
          .inLinear(HWAxis.horizontal);

      expect(item.itemList, 'forecast');
      expect(item.enclosingLinearAxis, HWAxis.horizontal);
      expect(item.reachableFamilies, families);
      expect(item.inLinear(null).itemList, 'forecast');
    });
  });
}
