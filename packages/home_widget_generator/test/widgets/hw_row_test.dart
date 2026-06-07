import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWRow', () {
    group('model', () {
      test('merges data dependencies from children', () {
        const row = HWRow(
          children: [
            HWText(HWString('a')),
            HWText(HWInt('b')),
          ],
        );
        expect(row.dataDependencies, hasLength(2));
        expect(
          row.dataDependencies,
          containsAll(<Object>[const HWString('a'), const HWInt('b')]),
        );
      });

      test('unions swiftViewModifiers from themed child', () {
        const row = HWRow(
          children: [
            HWText.fixed(
              'x',
              style: HWTextStyle(
                color: HWThemedColor(
                  light: HWFixedColor(0xFF000000),
                  dark: HWFixedColor(0xFFFFFFFF),
                ),
              ),
            ),
            HWText.fixed('y'),
          ],
        );
        expect(
          row.swiftViewModifiers.any(
            (e) => e.contains('colorScheme'),
          ),
          isTrue,
        );
      });

      test('const constructor', () {
        const row = HWRow(children: [HWText.fixed('x')]);
        expect(row, isA<HWRow>());
        expect(row, isA<HWWidget>());
        expect(row.children, hasLength(1));
      });

      test('Column in Row', () {
        const widget = HWRow(
          children: [
            HWColumn(children: [HWText.fixed('nested')]),
          ],
        );
        expect(widget.children.first, isA<HWColumn>());
      });

      test('mixed children (text and column)', () {
        const widget = HWRow(
          children: [
            HWText.fixed('a'),
            HWColumn(children: [HWText.fixed('b')]),
          ],
        );
        expect(widget.children[0], isA<HWText>());
        expect(widget.children[1], isA<HWColumn>());
      });
    });

    group('iOS (SwiftUI)', () {
      test('HStack with children', () {
        final node = HWRow(children: [HWText.fixed('x')]);
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack {'));
        expect(r, contains('Text("x")'));
      });

      test('crossAxis .center → center', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center) {'));
      });

      test('crossAxis .end → bottom', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .bottom) {'));
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack {'));
        expect(r, contains('Text("a")'));
        expect(r, contains('Spacer()'));
        expect(r, contains('Text("b")'));
        expect('Spacer()'.allMatches(r).length, 1);
      });

      test('mainAxis .center wraps with Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.center,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 2);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });

      test('mainAxis .end leads with Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.end,
          children: [HWText.fixed('a')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 1);
        expect(r, contains('Text("a")'));
      });

      test('mainAxis .spaceEvenly has Spacer between and around', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 3);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });
    });

    group('Android (Glance)', () {
      test('kotlinImports add Alignment and Spacer when set', () {
        final w = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
          mainAxisAlignment: HWMainAxisAlignment.end,
        );
        expect(w.kotlinImports, contains('import androidx.glance.layout.Row'));
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Alignment'),
        );
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Spacer'),
        );
      });

      test('kotlinImports include Row', () {
        final w = HWRow(children: [HWText.fixed('a')]);
        expect(w.kotlinImports, contains('import androidx.glance.layout.Row'));
      });

      test('Row with child', () {
        final node = HWRow(children: [HWText.fixed('x')]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row {'));
        expect(r, contains('Text(text = "x")'));
      });

      test('crossAxis .start → Top', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row(verticalAlignment = Alignment.Top) {'));
      });

      test('crossAxis .center → CenterVertically', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Row(verticalAlignment = Alignment.CenterVertically) {'),
        );
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row {'));
        expect(r, contains('Text(text = "a")'));
        expect(r, contains('Text(text = "b")'));
        expect(
          r,
          contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
        );
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          1,
        );
      });

      test('mainAxis .center wraps with weighted Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.center,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          2,
        );
        expect(r, contains('Text(text = "a")'));
        expect(r, contains('Text(text = "b")'));
      });

      test('mainAxis .end leads with weighted Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.end,
          children: [HWText.fixed('a')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          1,
        );
        expect(r, contains('Text(text = "a")'));
      });

      test('mainAxis .spaceEvenly with weighted Spacers', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          3,
        );
        expect(r, contains('Text(text = "a")'));
        expect(r, contains('Text(text = "b")'));
      });
    });
  });
}
