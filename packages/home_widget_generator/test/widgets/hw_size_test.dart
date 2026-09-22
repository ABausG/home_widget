import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWSize', () {
    test('cells applies the 70n - 30 cell formula per axis', () {
      expect(const HWSize.cells(2, 2), const HWSize(110, 110));
      expect(const HWSize.cells(4, 2), const HWSize(250, 110));
      expect(const HWSize.cells(4, 4), const HWSize(250, 250));
      expect(const HWSize.cells(8, 4), const HWSize(530, 250));
      expect(const HWSize.cells(4, 8), const HWSize(250, 530));
    });

    test('cells is const enough for an androidSizes entry', () {
      const sizes = {HWWidgetFamily.systemMedium: HWSize.cells(3, 2)};
      expect(sizes[HWWidgetFamily.systemMedium], const HWSize(180, 110));
    });

    test('cellExtent is the per-axis half of cells', () {
      expect(HWSize.cellExtent(2), 110);
      expect(HWSize.cellExtent(8), 530);
    });

    test('toKotlin is the DpSize the generated widget compares against', () {
      expect(const HWSize(250, 110).toKotlin(), 'DpSize(250.dp, 110.dp)');
      expect(const HWSize(112.5, 110).toKotlin(), 'DpSize(112.5.dp, 110.dp)');
    });

    test('equality and hashCode compare both axes', () {
      expect(const HWSize(250, 110), const HWSize(250.0, 110.0));
      expect(const HWSize(250, 110).hashCode, const HWSize(250, 110).hashCode);
      expect(const HWSize(250, 110), isNot(const HWSize(110, 250)));
      expect(const HWSize(250, 110), isNot(const HWSize(250, 111)));
    });

    test('toString drops the trailing .0 of a whole number', () {
      expect(const HWSize(250, 110).toString(), 'HWSize(250, 110)');
      expect(const HWSize(112.5, 110).toString(), 'HWSize(112.5, 110)');
    });
  });
}
