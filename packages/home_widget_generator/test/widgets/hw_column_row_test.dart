import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWColumn', () {
    test('const constructor', () {
      const col = HWColumn(children: [HWText.fixed('a'), HWText.fixed('b')]);
      expect(col, isA<HWColumn>());
      expect(col, isA<HWWidget>());
      expect(col.children, hasLength(2));
    });

    test('empty children', () {
      const col = HWColumn(children: []);
      expect(col.children, isEmpty);
    });
  });

  group('HWRow', () {
    test('const constructor', () {
      const row = HWRow(children: [HWText.fixed('x')]);
      expect(row, isA<HWRow>());
      expect(row, isA<HWWidget>());
      expect(row.children, hasLength(1));
    });
  });

  group('nesting', () {
    test('Column in Row', () {
      const widget = HWRow(children: [
        HWColumn(children: [HWText.fixed('nested')]),
      ]);
      expect(widget.children.first, isA<HWColumn>());
    });

    test('Row in Column', () {
      const widget = HWColumn(children: [
        HWRow(children: [HWText.fixed('x')]),
      ]);
      expect(widget.children.first, isA<HWRow>());
    });

    test('deep nesting (3+ levels)', () {
      const widget = HWColumn(children: [
        HWRow(children: [
          HWColumn(children: [HWText.fixed('deep')]),
        ]),
      ]);
      final row = widget.children.first as HWRow;
      final innerCol = row.children.first as HWColumn;
      expect(innerCol.children.first, isA<HWText>());
    });

    test('mixed children types', () {
      const widget = HWRow(children: [
        HWText.fixed('a'),
        HWColumn(children: [HWText.fixed('b')]),
      ]);
      expect(widget.children[0], isA<HWText>());
      expect(widget.children[1], isA<HWColumn>());
    });

    test('data ref in nested tree', () {
      const widget = HWColumn(children: [
        HWText(HWString('key')),
      ]);
      expect(widget.children.first, isA<HWText>());
    });
  });
}
