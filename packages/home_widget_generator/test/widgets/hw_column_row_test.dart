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
      const widget = HWRow(
        children: [
          HWColumn(children: [HWText.fixed('nested')]),
        ],
      );
      expect(widget.children.first, isA<HWColumn>());
    });

    test('Row in Column', () {
      const widget = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      expect(widget.children.first, isA<HWRow>());
    });

    test('deep nesting (3+ levels)', () {
      const widget = HWColumn(
        children: [
          HWRow(
            children: [
              HWColumn(children: [HWText.fixed('deep')]),
            ],
          ),
        ],
      );
      final row = widget.children.first as HWRow;
      final innerCol = row.children.first as HWColumn;
      expect(innerCol.children.first, isA<HWText>());
    });

    test('mixed children types', () {
      const widget = HWRow(
        children: [
          HWText.fixed('a'),
          HWColumn(children: [HWText.fixed('b')]),
        ],
      );
      expect(widget.children[0], isA<HWText>());
      expect(widget.children[1], isA<HWColumn>());
    });

    test('data ref in nested tree', () {
      const widget = HWColumn(
        children: [
          HWText(HWString('key')),
        ],
      );
      expect(widget.children.first, isA<HWText>());
    });
  });

  group('Column and Row · Kotlin (Glance)', () {
    const kotlinColumn =
        'Column(horizontalAlignment = Alignment.CenterHorizontally) {';
    const kotlinRow = 'Row(verticalAlignment = Alignment.CenterVertically) {';

    test('Column from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains(kotlinColumn));
      expect(result, contains('Text(text = "a",'));
      expect(result, contains('Text(text = "b",'));
    });

    test('Row from HWRow', () {
      final node = HWRow(
        children: [
          HWText.fixed('x'),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains(kotlinRow));
      expect(result, contains('Text(text = "x",'));
    });

    test('nested Column/Row', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
          HWText.fixed('y'),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains(kotlinColumn));
      expect(result, contains(kotlinRow));
      expect(result, contains('Text(text = "x",'));
      expect(result, contains('Text(text = "y",'));
    });

    test('data in layout', () {
      final node = HWColumn(
        children: [
          HWText(HWString('count')),
        ],
      );
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, contains(kotlinColumn));
      expect(result, contains('Text(text = data.count ?: "",'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains(kotlinColumn));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, startsWith(kotlinColumn));
      expect(result, contains('    $kotlinRow'));
      expect(result, contains('        Text(text = "x",'));
    });

    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        contains(
          'Column(horizontalAlignment = Alignment.CenterHorizontally) {',
        ),
      );
    });

    test('Row with .start alignment', () {
      final node = HWRow(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.start,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Row(verticalAlignment = Alignment.Top) {'));
    });

    test('no alignment centers on the cross axis', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains(kotlinColumn));
    });

    test(
        'Column with .center emits Spacer before and after (mainAxisAlignment)',
        () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        contains('Column(modifier = GlanceModifier.fillMaxHeight(), '),
      );
      expect(
        result,
        contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
      );
      expect(result, contains('Text(text = "a",'));
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(result)
            .length,
        2,
      );
    });

    test('Row with .spaceBetween emits Spacer between children', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        contains('Row(modifier = GlanceModifier.fillMaxWidth(), '),
      );
      expect(result, contains('Text(text = "a",'));
      expect(
        result,
        contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
      );
      expect(result, contains('Text(text = "b",'));
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(result)
            .length,
        1,
      );
    });

    test('Column with both cross and main alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
        mainAxisAlignment: HWMainAxisAlignment.end,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        contains('horizontalAlignment = Alignment.CenterHorizontally'),
      );
      expect(
        result,
        contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
      );
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(result)
            .length,
        1,
      );
    });
  });

  group('Column and Row · Swift (SwiftUI)', () {
    const swiftColumn = 'VStack(alignment: .center, spacing: 0) {';
    const swiftRow = 'HStack(alignment: .center, spacing: 0) {';

    test('VStack from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftColumn));
      expect(result, contains('Text("a")'));
      expect(result, contains('Text("b")'));
    });

    test('HStack from HWRow', () {
      final node = HWRow(
        children: [
          HWText.fixed('x'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftRow));
      expect(result, contains('Text("x")'));
    });

    test('nested VStack/HStack', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
          HWText.fixed('y'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftColumn));
      expect(result, contains(swiftRow));
      expect(result, contains('Text("x")'));
      expect(result, contains('Text("y")'));
    });

    test('data in layout', () {
      final node = HWColumn(
        children: [
          HWText(HWString('countLabel')),
        ],
      );
      final result = node.toSwift(
        0,
        dataExpr: 'entry.widgetData',
      );
      expect(result, contains(swiftColumn));
      expect(result, contains('Text(entry.widgetData.countLabel ?? "")'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftColumn));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, startsWith(swiftColumn));
      expect(result, contains('    $swiftRow'));
      expect(result, contains('        Text("x")'));
    });

    test('Column with .start alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.start,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .leading, spacing: 0) {'));
    });

    test('Row with .end alignment', () {
      final node = HWRow(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.end,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('HStack(alignment: .bottom, spacing: 0) {'));
    });

    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .center, spacing: 0) {'));
    });

    test('no alignment centers on the cross axis', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftColumn));
    });

    test(
        'Column with .center emits Spacer before and after (mainAxisAlignment)',
        () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftColumn));
      expect(result, contains('Spacer(minLength: 0)'));
      expect(result, contains('Text("a")'));
      expect('Spacer(minLength: 0)'.allMatches(result).length, 2);
    });

    test('Column with .end emits Spacer before children', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.end,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('Spacer(minLength: 0)'));
      expect(result, contains('Text("a")'));
      expect('Spacer(minLength: 0)'.allMatches(result).length, 1);
    });

    test('Row with .spaceBetween emits Spacer between children', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains(swiftRow));
      expect(result, contains('Text("a")'));
      expect(result, contains('Spacer(minLength: 0)'));
      expect(result, contains('Text("b")'));
      expect('Spacer(minLength: 0)'.allMatches(result).length, 1);
    });

    test('Column with .spaceEvenly emits Spacer around all children', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
        mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect('Spacer(minLength: 0)'.allMatches(result).length, 3);
    });

    test('Column with .start emits no spacers', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.start,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, isNot(contains('Spacer(')));
    });

    group('fills the main axis as Glance does', () {
      const rowFrame = '.frame(maxWidth: .infinity, alignment: .leading)';
      const columnFrame = '.frame(maxHeight: .infinity, alignment: .top)';
      const a = HWText.fixed('a');
      const b = HWText.fixed('b');

      test('where spaceBetween has fewer than two children to spread', () {
        expect(
          const HWRow(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [a],
          ).toSwift(0, dataExpr: 'data'),
          '''
HStack(alignment: .center, spacing: 0) {
    Text("a")
}
$rowFrame''',
        );
        expect(
          const HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [
              HWDataOnly([HWString('id')]),
              a,
            ],
          ).toSwift(0, dataExpr: 'data'),
          endsWith('}\n$columnFrame'),
        );
        expect(
          const HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [],
          ).toSwift(0, dataExpr: 'data'),
          endsWith('}\n$columnFrame'),
        );
      });

      test('leaves a stack its spacers already stretch', () {
        for (final alignment in [
          HWMainAxisAlignment.center,
          HWMainAxisAlignment.end,
          HWMainAxisAlignment.spaceEvenly,
        ]) {
          expect(
            HWRow(mainAxisAlignment: alignment, children: const [a])
                .toSwift(0, dataExpr: 'data'),
            isNot(contains('.frame(')),
          );
        }
        expect(
          const HWRow(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [a, b],
          ).toSwift(0, dataExpr: 'data'),
          isNot(contains('.frame(')),
        );
        expect(
          const HWRow(
            mainAxisAlignment: HWMainAxisAlignment.start,
            children: [a],
          ).toSwift(0, dataExpr: 'data'),
          isNot(contains('.frame(')),
        );
      });

      test('always for a builder, whose items are only known at runtime', () {
        const days = HWRow.builder(
          'days',
          maxItems: 5,
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
          item: HWText(HWItemData(HWString('day'))),
          whenEmpty: a,
        );
        expect(days.toSwift(0, dataExpr: 'data'), endsWith('}\n$rowFrame'));
        expect(
          const HWColumn.builder(
            'days',
            mainAxisAlignment: HWMainAxisAlignment.end,
            item: HWText(HWItemData(HWString('day'))),
          ).toSwift(0, dataExpr: 'data'),
          endsWith('}\n$columnFrame'),
        );
        expect(
          const HWColumn.builder(
            'days',
            item: HWText(HWItemData(HWString('day'))),
          ).toSwift(0, dataExpr: 'data'),
          isNot(contains('.frame(')),
        );

        final column = HWColumn(
          spacing: 8,
          crossAxisAlignment: HWCrossAxisAlignment.start,
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
          children: const [HWText(HWString('city')), days],
        ).toSwift(0, dataExpr: 'data');
        expect(column, startsWith('VStack(alignment: .leading, spacing: 0) {'));
        expect(
          column,
          contains('    }\n    $rowFrame\n    .padding(.top, 8.0)'),
        );
        expect(column, endsWith('    .padding(.top, 8.0)\n}'));
      });
    });
  });

  group('spacing', () {
    const a = HWText.fixed('a');
    const b = HWText.fixed('b');
    const green = HWFixedColor(0xFF00FF00);
    const kotlinA =
        'Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))';
    const kotlinSpacer = 'Spacer(modifier = GlanceModifier.defaultWeight())';
    const swiftSpacer = 'Spacer(minLength: 0)';

    List<String> lines(String code) =>
        code.split('\n').map((line) => line.trim()).toList();

    test('defaults to 0 and emits no gap', () {
      const row = HWRow(children: [a, b]);
      expect(row.spacing, 0);
      expect(row.toSwift(0, dataExpr: 'data'), isNot(contains('.padding')));
      expect(row.toKotlin(0, dataExpr: 'data'), isNot(contains('padding')));
      expect(
        row.kotlinImports,
        isNot(contains('import androidx.glance.layout.padding')),
      );
    });

    group('with every main-axis alignment', () {
      const kotlinB =
          'Text(modifier = GlanceModifier.padding(start = 12.0.dp), '
          'text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))';
      const swiftGap = '.padding(.leading, 12.0)';
      const swiftRow = 'HStack(alignment: .center, spacing: 0) {';
      const kotlinRow = 'Row(verticalAlignment = Alignment.CenterVertically) {';
      const kotlinFilledRow = 'Row(modifier = GlanceModifier.fillMaxWidth(), '
          'verticalAlignment = Alignment.CenterVertically) {';

      final expected = <HWMainAxisAlignment?, (List<String>, List<String>)>{
        null: (
          [swiftRow, 'Text("a")', 'Text("b")', swiftGap, '}'],
          [kotlinRow, kotlinA, kotlinB, '}'],
        ),
        HWMainAxisAlignment.start: (
          [swiftRow, 'Text("a")', 'Text("b")', swiftGap, '}'],
          [kotlinRow, kotlinA, kotlinB, '}'],
        ),
        HWMainAxisAlignment.center: (
          [
            swiftRow,
            swiftSpacer,
            'Text("a")',
            'Text("b")',
            swiftGap,
            swiftSpacer,
            '}',
          ],
          [kotlinFilledRow, kotlinSpacer, kotlinA, kotlinB, kotlinSpacer, '}'],
        ),
        HWMainAxisAlignment.end: (
          [swiftRow, swiftSpacer, 'Text("a")', 'Text("b")', swiftGap, '}'],
          [kotlinFilledRow, kotlinSpacer, kotlinA, kotlinB, '}'],
        ),
        HWMainAxisAlignment.spaceBetween: (
          [swiftRow, 'Text("a")', swiftSpacer, 'Text("b")', swiftGap, '}'],
          [kotlinFilledRow, kotlinA, kotlinSpacer, kotlinB, '}'],
        ),
        HWMainAxisAlignment.spaceEvenly: (
          [
            swiftRow,
            swiftSpacer,
            'Text("a")',
            swiftSpacer,
            'Text("b")',
            swiftGap,
            swiftSpacer,
            '}',
          ],
          [
            kotlinFilledRow,
            kotlinSpacer,
            kotlinA,
            kotlinSpacer,
            kotlinB,
            kotlinSpacer,
            '}',
          ],
        ),
      };

      for (final MapEntry(key: alignment, value: (swift, kotlin))
          in expected.entries) {
        test(
            '${alignment?.name ?? 'none'} keeps its spacers apart from the gap',
            () {
          final row = HWRow(
            spacing: 12,
            mainAxisAlignment: alignment,
            children: const [a, b],
          );
          expect(lines(row.toSwift(0, dataExpr: 'data')), swift);
          expect(lines(row.toKotlin(0, dataExpr: 'data')), kotlin);
        });
      }
    });

    test('a column puts the gap above every child but the first', () {
      const column = HWColumn(spacing: 8, children: [a, b, a]);
      expect(column.toSwift(0, dataExpr: 'data'), '''
VStack(alignment: .center, spacing: 0) {
    Text("a")
    Text("b")
    .padding(.top, 8.0)
    Text("a")
    .padding(.top, 8.0)
}''');
      expect(
        lines(column.toKotlin(0, dataExpr: 'data')),
        [
          'Column(horizontalAlignment = Alignment.CenterHorizontally) {',
          kotlinA,
          'Text(modifier = GlanceModifier.padding(top = 8.0.dp), text = "b", '
              'style = TextStyle(color = GlanceTheme.colors.onSurface))',
          'Text(modifier = GlanceModifier.padding(top = 8.0.dp), text = "a", '
              'style = TextStyle(color = GlanceTheme.colors.onSurface))',
          '}',
        ],
      );
      expect(
        column.kotlinImports,
        containsAll([
          'import androidx.compose.ui.unit.dp',
          'import androidx.glance.layout.padding',
          'import androidx.glance.layout.Box',
        ]),
      );
    });

    test('a fractional spacing prints as written', () {
      const row = HWRow(spacing: 2.5, children: [a, b]);
      expect(
        row.toSwift(0, dataExpr: 'data'),
        contains('.padding(.leading, 2.5)'),
      );
      expect(
        row.toKotlin(0, dataExpr: 'data'),
        contains('padding(start = 2.5.dp)'),
      );
    });

    group('iOS (SwiftUI)', () {
      test('goes after the modifiers of the child, outside its background', () {
        const column = HWColumn(
          spacing: 8,
          children: [a, HWColoredBox(color: green, child: b)],
        );
        final r = column.toSwift(0, dataExpr: 'data');
        expect(
          r.indexOf('.background('),
          lessThan(r.indexOf('.padding(.top, 8.0)')),
        );
      });

      test('wraps a conditional child in a Group to take the gap', () {
        const row = HWRow(
          spacing: 4,
          children: [
            a,
            HWDataExists(
              data: HWString('maybe'),
              whenPresent: b,
              whenAbsent: a,
            ),
          ],
        );
        expect(row.toSwift(0, dataExpr: 'data'), '''
HStack(alignment: .center, spacing: 0) {
    Text("a")
    Group {
        if data.maybe != nil {
            Text("b")
        } else {
            Text("a")
        }
    }
    .padding(.leading, 4.0)
}''');
      });
    });

    group('Android (Glance)', () {
      test('goes on a Box around a child drawing a background', () {
        const column = HWColumn(
          spacing: 8,
          children: [a, HWColoredBox(color: green, child: b)],
        );
        expect(column.toKotlin(0, dataExpr: 'data'), '''
Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {
        Text(modifier = GlanceModifier.background(ColorProvider(day = Color(0xFF00FF00), night = Color(0xFF00FF00))), text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''');
        expect(
          column.kotlinImports,
          contains('import androidx.glance.layout.Box'),
        );
      });

      test('goes on a Box around a decoration with a color or a border', () {
        const colored = HWColumn(
          spacing: 8,
          children: [
            a,
            HWDecoratedBox(
              decoration: HWBoxDecoration(color: green),
              child: b,
            ),
          ],
        );
        expect(
          colored.toKotlin(0, dataExpr: 'data'),
          contains(
            '    Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {\n'
            '        Text(modifier = GlanceModifier.background(',
          ),
        );
        const bordered = HWColumn(
          spacing: 8,
          children: [
            a,
            HWDecoratedBox(
              decoration: HWBoxDecoration(
                border: HWBoxBorder(thickness: 1, color: green),
              ),
              child: b,
            ),
          ],
        );
        expect(
          bordered.toKotlin(0, dataExpr: 'data'),
          contains(
            '    Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {\n'
            '        Box(\n'
            '            modifier = GlanceModifier.background(',
          ),
        );
      });

      test('goes on the child itself behind a decoration drawing nothing', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWDecoratedBox(decoration: HWBoxDecoration(), child: b),
          ],
        );
        final r = column.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Text(modifier = GlanceModifier.padding(top = 8.0.dp)'),
        );
        expect(r, isNot(contains('Box')));
      });

      test('goes on a Box around an icon, whose fixed size would shrink it',
          () {
        const row = HWRow(
          spacing: 6,
          children: [
            a,
            HWIcon.resolvedGlyph(
              0xe800,
              font: HWIconFont(family: 'Icons'),
              fontResourcePrefix: 'hw_font_demo',
            ),
          ],
        );
        final r = row.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            '    Box(modifier = GlanceModifier.padding(start = 6.0.dp)) {\n'
            '        Image(modifier = GlanceModifier.size(24.dp), ',
          ),
        );
      });

      test('keeps the weight on a stack asking for the main axis', () {
        const inner = HWColumn(
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
          children: [a, b],
        );
        const column = HWColumn(spacing: 8, children: [a, inner]);
        expect(
          column.toKotlin(0, dataExpr: 'data'),
          contains(
            '    Column(modifier = GlanceModifier.padding(top = 8.0.dp)'
            '.defaultWeight(), horizontalAlignment = '
            'Alignment.CenterHorizontally) {',
          ),
        );
        expect(
          column.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('moves the weight onto the Box around a stack with a background',
          () {
        const inner = HWColoredBox(
          color: green,
          child: HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [a, b],
          ),
        );
        const column = HWColumn(spacing: 8, children: [a, inner]);
        final r = column.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            '    Box(modifier = GlanceModifier.defaultWeight()'
            '.padding(top = 8.0.dp)) {\n'
            '        Column(modifier = GlanceModifier.background(',
          ),
        );
        expect(r, isNot(contains('.defaultWeight(), horizontalAlignment')));
        expect(r, contains('.fillMaxHeight(), horizontalAlignment'));
        expect(
          column.kotlinImports,
          contains('import androidx.glance.layout.fillMaxHeight'),
        );
      });

      test('gives the Box the width a filling child with a background takes',
          () {
        const inner = HWColoredBox(
          color: green,
          child: HWRow(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [a, b],
          ),
        );
        const column = HWColumn(spacing: 8, children: [a, inner]);
        final r = column.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Box(modifier = GlanceModifier.fillMaxWidth()'
            '.padding(top = 8.0.dp)) {',
          ),
        );
        expect(r, contains('.fillMaxWidth(), verticalAlignment'));
        expect(
          column.kotlinImports,
          contains('import androidx.glance.layout.fillMaxWidth'),
        );
      });

      test('gives the Box the whole size a fill with a background takes', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWFill(child: HWColoredBox(color: green, child: b)),
          ],
        );
        final r = column.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Box(modifier = GlanceModifier.fillMaxSize()'
            '.padding(top = 8.0.dp)) {',
          ),
        );
        expect(
          column.kotlinImports,
          contains('import androidx.glance.layout.fillMaxSize'),
        );
      });

      test('injects the gap into every branch of a conditional', () {
        const row = HWRow(
          spacing: 4,
          children: [
            a,
            HWDataExists(
              data: HWString('maybe'),
              whenPresent: b,
              whenAbsent: a,
            ),
          ],
        );
        expect(
          'padding(start = 4.0.dp)'
              .allMatches(row.toKotlin(0, dataExpr: 'data'))
              .length,
          2,
        );
      });

      test('gives only the background branch of a conditional a Box', () {
        const row = HWRow(
          spacing: 4,
          children: [
            a,
            HWDataExists(
              data: HWString('maybe'),
              whenPresent: HWColoredBox(color: green, child: b),
              whenAbsent: a,
            ),
          ],
        );
        expect(row.toKotlin(0, dataExpr: 'data'), '''
Row(verticalAlignment = Alignment.CenterVertically) {
    Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    if (data.maybe != null) {
        Box(modifier = GlanceModifier.padding(start = 4.0.dp)) {
            Text(modifier = GlanceModifier.background(ColorProvider(day = Color(0xFF00FF00), night = Color(0xFF00FF00))), text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))
        }
    } else {
        Text(modifier = GlanceModifier.padding(start = 4.0.dp), text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''');
      });

      test('gives each branch of a conditional the room it asks for', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWDataExists(
              data: HWString('event'),
              whenPresent: HWRow(
                mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
                children: [a, b],
              ),
              whenAbsent: HWColoredBox(
                color: green,
                child: HWColumn(
                  mainAxisAlignment: HWMainAxisAlignment.center,
                  children: [b],
                ),
              ),
            ),
          ],
        );
        final r = column.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            '    if (data.event != null) {\n'
            '        Row(modifier = GlanceModifier.padding(top = 8.0.dp)'
            '.fillMaxWidth(), ',
          ),
        );
        expect(
          r,
          contains(
            '    } else {\n'
            '        Box(modifier = GlanceModifier.defaultWeight()'
            '.padding(top = 8.0.dp)) {\n'
            '            Column(modifier = GlanceModifier.background(',
          ),
        );
        expect(
          column.kotlinImports,
          containsAll([
            'import androidx.glance.layout.fillMaxWidth',
            'import androidx.glance.layout.fillMaxHeight',
          ]),
        );
      });

      test('gives a branch rendering nothing neither gap nor Box', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWDataExists(
              data: HWString('note'),
              whenPresent: b,
              whenAbsent: HWDataOnly([HWString('noteId')]),
            ),
            HWSizeAdaptive(
              small: HWDataOnly([HWString('hidden')]),
              medium: HWColoredBox(color: green, child: b),
            ),
          ],
        );
        expect(column.toKotlin(0, dataExpr: 'data'), '''
Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    if (data.note != null) {
        Text(modifier = GlanceModifier.padding(top = 8.0.dp), text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))
    } else {

    }
    when (LocalSize.current) {
        DpSize(250.dp, 110.dp) -> {
            Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {
                Text(modifier = GlanceModifier.background(ColorProvider(day = Color(0xFF00FF00), night = Color(0xFF00FF00))), text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))
            }
        }
        else -> {

        }
    }
}''');
        expect(
          column.kotlinImports,
          containsAll([
            'import androidx.glance.LocalSize',
            'import androidx.compose.ui.unit.DpSize',
          ]),
        );
      });

      test('gives the slot a size-adaptive renders what that slot asks for',
          () {
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWSizeAdaptive(
              small: HWColoredBox(color: green, child: b),
              accessoryRectangular: HWRow(
                mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
                children: [a, b],
              ),
            ),
          ],
        );
        final r = column.toKotlin(
          0,
          dataExpr: 'data',
          context: const HWEmitContext(
            reachableFamilies: {
              HWWidgetFamily.systemSmall,
              HWWidgetFamily.systemMedium,
            },
          ),
        );
        expect(
          r,
          contains(
            '    Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {\n'
            '        Text(modifier = GlanceModifier.background(',
          ),
        );
        expect(r, isNot(contains('fillMaxWidth')));
        expect(r, isNot(contains('LocalSize')));
      });

      test('carries a wrapper onto each branch of a conditional it wraps', () {
        const conditional = HWDataExists(
          data: HWString('event'),
          whenPresent: HWRow(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [a, b],
          ),
          whenAbsent: HWDataOnly([HWString('eventId')]),
        );
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWColoredBox(color: green, child: conditional),
            HWPadding(padding: HWEdgeInsets.all(2), child: conditional),
            HWDecoratedBox(
              decoration: HWBoxDecoration(color: green),
              child: conditional,
            ),
            HWFill(child: conditional),
          ],
        );
        final r = column.toKotlin(0, dataExpr: 'data');
        expect(
          '    if (data.event != null) {\n'
                  '        Box(modifier = GlanceModifier.fillMaxWidth()'
                  '.padding(top = 8.0.dp)) {\n'
                  '            Row(modifier = GlanceModifier.background('
              .allMatches(r)
              .length,
          2,
        );
        expect(
          r,
          contains(
            '    if (data.event != null) {\n'
            '        Row(modifier = GlanceModifier.padding(top = 8.0.dp)'
            '.padding(start = 2.0.dp, top = 2.0.dp, end = 2.0.dp, '
            'bottom = 2.0.dp).fillMaxWidth(), ',
          ),
        );
        expect(
          r,
          contains(
            '    if (data.event != null) {\n'
            '        Row(modifier = GlanceModifier.padding(top = 8.0.dp)'
            '.fillMaxSize(), ',
          ),
        );
        expect('    } else {\n\n    }'.allMatches(r).length, 4);
      });

      test('lays a bordered box around a conditional out as a whole', () {
        const column = HWColumn(
          spacing: 8,
          children: [
            a,
            HWDecoratedBox(
              decoration: HWBoxDecoration(
                border: HWBoxBorder(thickness: 1, color: green),
              ),
              child: HWDataExists(
                data: HWString('maybe'),
                whenPresent: a,
                whenAbsent: b,
              ),
            ),
          ],
        );
        expect(
          column.toKotlin(0, dataExpr: 'data'),
          contains(
            '    Box(modifier = GlanceModifier.padding(top = 8.0.dp)) {\n'
            '        Box(\n',
          ),
        );
      });

      test('injects the gap into every slot of a size-adaptive', () {
        const row = HWRow(
          spacing: 4,
          children: [a, HWSizeAdaptive(small: a, large: b)],
        );
        expect(
          'padding(start = 4.0.dp)'
              .allMatches(row.toKotlin(0, dataExpr: 'data'))
              .length,
          2,
        );
      });

      test('goes inside the check a picture is only drawn behind', () {
        const row = HWRow(
          spacing: 4,
          children: [
            a,
            HWImage(HWImageData('avatar'), width: 8),
            HWImage(HWImageData('avatar')),
            HWImage.asset('assets/logo.png', height: 8),
          ],
        );
        expect(row.toKotlin(0, dataExpr: 'data'), '''
Row(verticalAlignment = Alignment.CenterVertically) {
    Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    data.avatar?.let { path -> hwDecodeImage(context, path, 8.0, null) }
        ?.let { bitmap ->
            Box(modifier = GlanceModifier.padding(start = 4.0.dp)) {
                Image(
                    provider = ImageProvider(bitmap),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = GlanceModifier.width(8.0.dp),
                )
            }
        }
    data.avatar?.let { path -> hwDecodeImage(context, path, null, null) }
        ?.let { bitmap ->
            Image(modifier = GlanceModifier.padding(start = 4.0.dp),
                provider = ImageProvider(bitmap),
                contentDescription = null,
                contentScale = ContentScale.Fit,
            )
        }
    hwDecodeImage(context, "assets/logo.png", null, 8.0)?.let { bitmap ->
        Box(modifier = GlanceModifier.padding(start = 4.0.dp)) {
            Image(
                provider = ImageProvider(bitmap),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = GlanceModifier.height(8.0.dp),
            )
        }
    }
}''');
        expect(
          row.kotlinImports,
          containsAll([
            'import androidx.glance.layout.Box',
            'import androidx.glance.layout.padding',
          ]),
        );
      });

      test('goes inside the check an icon bound to data is only drawn behind',
          () {
        const column = HWColumn(
          spacing: 4,
          children: [
            a,
            HWIcon.resolved(
              HWIconData.resolved(
                'mood',
                entries: [HWIconEntry('happy', 0xe800)],
                iconFont: HWIconFont(family: 'Icons'),
              ),
              fontResourcePrefix: 'hw_font_demo',
            ),
          ],
        );
        expect(
          column.toKotlin(0, dataExpr: 'data'),
          contains(
            '    data.mood?.let { codePoint ->\n'
            '        Box(modifier = GlanceModifier.padding(top = 4.0.dp)) {\n'
            '            Image(modifier = GlanceModifier.size(24.dp), ',
          ),
        );
      });

      test("goes on the bare Box a top-aligned row puts around a text", () {
        const row = HWRow(
          spacing: 12,
          crossAxisAlignment: HWCrossAxisAlignment.start,
          children: [a, b],
        );
        expect(row.toKotlin(0, dataExpr: 'data'), '''
Row(verticalAlignment = Alignment.Top) {
    Box {
        Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
    Box(modifier = GlanceModifier.padding(start = 12.0.dp)) {
        Text(text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''');
      });

      test('chains the gap after the padding of a baseline Box', () {
        const row = HWRow(
          spacing: 4,
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          children: [
            HWText.fixed(
              '50',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
            HWText.fixed('Points'),
          ],
        );
        final r = row.toKotlin(0, dataExpr: 'data');
        expect(r, contains(', 1)).padding(start = 4.0.dp)) {'));
        expect(r, contains(', 0))) {'));
      });
    });
  });

  group('list builders', () {
    const label = HWText(HWItemData(HWString('label')));
    const empty = HWText.fixed('Nothing yet');
    const green = HWFixedColor(0xFF00FF00);
    const kotlinLabel = 'Text(text = hwItem.label ?: "", '
        'style = TextStyle(color = GlanceTheme.colors.onSurface))';
    const kotlinEmpty = 'Text(text = "Nothing yet", '
        'style = TextStyle(color = GlanceTheme.colors.onSurface))';
    const kotlinSpacer = 'Spacer(modifier = GlanceModifier.defaultWeight())';
    const swiftSpacer = 'Spacer(minLength: 0)';

    List<String> lines(String code) =>
        code.split('\n').map((line) => line.trim()).toList();

    group('model', () {
      test('renders its item, and whenEmpty, in place of children', () {
        const row = HWRow.builder('tags', item: label, whenEmpty: empty);
        const column = HWColumn.builder('tags', item: label);

        expect(row.isBuilder, isTrue);
        expect(row.list, 'tags');
        expect(row.children, isEmpty);
        expect(row.childWidgets, [label, empty]);
        expect(column.childWidgets, [label]);
        expect(row.descendants, [row, label, empty]);
        expect(const HWRow(children: [label]).isBuilder, isFalse);
        expect(const HWRow(children: [label]).itemReads, isEmpty);
        expect(const HWRow(children: [label]).item, isNull);
      });

      test('leaves item fields to itemReads and keeps every root read', () {
        const row = HWRow.builder(
          'forecast',
          item: HWColumn(
            children: [
              HWText(HWItemData(HWString('day'))),
              HWText(HWString('unit')),
              HWText(HWTimedData(HWItemData(HWInt('temperature')))),
              HWText(HWItemData(HWString('day'))),
            ],
          ),
          whenEmpty: HWText(HWString('hint')),
        );

        expect(
          row.dataDependencies,
          {const HWString('unit'), const HWString('hint')},
        );
        expect(row.itemReads, [
          const HWItemData(HWString('day')),
          const HWTimedData(HWItemData(HWInt('temperature'))),
        ]);
      });

      test('reports every declaration of an item field for merging', () {
        const row = HWRow.builder(
          'forecast',
          item: HWColumn(
            children: [
              HWText(HWItemData(HWString('day'), previewValues: ['Mon'])),
              HWText(HWItemData(HWString('day'))),
            ],
          ),
        );

        expect(row.itemReads, [
          const HWItemData(HWString('day'), previewValues: ['Mon']),
          const HWItemData(HWString('day')),
        ]);
      });

      test('fonts, icons, helpers and modifiers reach into the item', () {
        const icon = HWIconData.resolved(
          'condition',
          entries: [HWIconEntry('wbSunny', 0xE430)],
          iconFont: HWIconFont(family: 'MaterialIcons'),
        );
        const row = HWRow.builder(
          'forecast',
          item: HWColumn(
            children: [
              HWText.dateTime(HWItemData(HWDateTime('day'))),
              HWIcon.resolved(HWItemData(icon), fontResourcePrefix: 'hw'),
              HWText(
                HWItemData(HWString('label')),
                style: HWTextStyle(fontFamily: 'Chewy'),
              ),
            ],
          ),
          whenEmpty: HWText(
            HWString('hint'),
            style: HWTextStyle(
              color:
                  HWThemedColor(light: green, dark: HWFixedColor(0xFF000000)),
            ),
          ),
        );

        expect(row.fontVariants, {
          const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
        });
        expect(row.iconCodePoints, {
          const HWIconFont(family: 'MaterialIcons'): {0xE430},
        });
        expect(
          row.nativeHelpers,
          containsAll([
            HWNativeHelper.hwParseIsoDate,
            HWNativeHelper.hwBundledFont,
            HWNativeHelper.hwFont,
          ]),
        );
        expect(row.swiftViewModifiers, {
          '@Environment(\\.layoutDirection) var layoutDirection',
          '@Environment(\\.colorScheme) var colorScheme',
        });
      });
    });

    group('with every main-axis alignment', () {
      const swiftLoop = r'ForEach(Array((data.tags ?? []).prefix(4)'
          r'.enumerated()), id: \.offset) { hwIndex, hwItem in';
      const swiftGap = '.padding(.leading, hwIndex > 0 ? 12.0 : 0)';
      const swiftBetween = ['if hwIndex > 0 {', swiftSpacer, '}'];
      const kotlinItems = 'val hwItems = data.tags.orEmpty().take(4)';
      const kotlinLabelWithGap = 'Text(modifier = GlanceModifier.padding('
          'start = if (hwIndex > 0) 12.0.dp else 0.dp), '
          'text = hwItem.label ?: "", '
          'style = TextStyle(color = GlanceTheme.colors.onSurface))';
      const kotlinRow = 'Row(verticalAlignment = Alignment.CenterVertically) {';
      const kotlinFilledRow = 'Row(modifier = GlanceModifier.fillMaxWidth(), '
          'verticalAlignment = Alignment.CenterVertically) {';

      final expected = <HWMainAxisAlignment?, (List<String>, List<String>)>{
        null: (
          [swiftLoop, 'Text(hwItem.label ?? "")', swiftGap, '}'],
          [
            kotlinRow,
            kotlinItems,
            'hwItems.forEachIndexed { hwIndex, hwItem ->',
            kotlinLabelWithGap,
            '}',
          ],
        ),
        HWMainAxisAlignment.start: (
          [swiftLoop, 'Text(hwItem.label ?? "")', swiftGap, '}'],
          [
            kotlinRow,
            kotlinItems,
            'hwItems.forEachIndexed { hwIndex, hwItem ->',
            kotlinLabelWithGap,
            '}',
          ],
        ),
        HWMainAxisAlignment.center: (
          [
            swiftSpacer,
            swiftLoop,
            'Text(hwItem.label ?? "")',
            swiftGap,
            '}',
            swiftSpacer,
          ],
          [
            kotlinFilledRow,
            kotlinItems,
            kotlinSpacer,
            'hwItems.forEachIndexed { hwIndex, hwItem ->',
            kotlinLabelWithGap,
            '}',
            kotlinSpacer,
          ],
        ),
        HWMainAxisAlignment.end: (
          [swiftSpacer, swiftLoop, 'Text(hwItem.label ?? "")', swiftGap, '}'],
          [
            kotlinFilledRow,
            kotlinItems,
            kotlinSpacer,
            'hwItems.forEachIndexed { hwIndex, hwItem ->',
            kotlinLabelWithGap,
            '}',
          ],
        ),
        HWMainAxisAlignment.spaceBetween: (
          [
            swiftLoop,
            ...swiftBetween,
            'Text(hwItem.label ?? "")',
            swiftGap,
            '}',
          ],
          [
            kotlinFilledRow,
            kotlinItems,
            'hwItems.forEachIndexed { hwIndex, hwItem ->',
            'if (hwIndex > 0) $kotlinSpacer',
            kotlinLabelWithGap,
            '}',
          ],
        ),
        HWMainAxisAlignment.spaceEvenly: (
          [
            swiftSpacer,
            swiftLoop,
            ...swiftBetween,
            'Text(hwItem.label ?? "")',
            swiftGap,
            '}',
            swiftSpacer,
          ],
          [
            kotlinFilledRow,
            kotlinItems,
            kotlinSpacer,
            'hwItems.forEachIndexed { hwIndex, hwItem ->',
            'if (hwIndex > 0) $kotlinSpacer',
            kotlinLabelWithGap,
            '}',
            kotlinSpacer,
          ],
        ),
      };

      for (final MapEntry(key: alignment, value: (swift, kotlin))
          in expected.entries) {
        test('${alignment?.name ?? 'none'} spaces the items like children', () {
          final row = HWRow.builder(
            'tags',
            maxItems: 4,
            spacing: 12,
            mainAxisAlignment: alignment,
            item: label,
          );
          expect(lines(row.toSwift(0, dataExpr: 'data')), [
            'HStack(alignment: .center, spacing: 0) {',
            ...swift,
            '}',
            if (alignment.fillsMainAxis)
              '.frame(maxWidth: .infinity, alignment: .leading)',
          ]);
          expect(lines(row.toKotlin(0, dataExpr: 'data')), [...kotlin, '}']);
        });
      }
    });

    test('shows whenEmpty with the spacers of a single child', () {
      const column = HWColumn.builder(
        'events',
        mainAxisAlignment: HWMainAxisAlignment.center,
        item: label,
        whenEmpty: empty,
      );

      expect(column.toSwift(0, dataExpr: 'entry.data'), r'''
VStack(alignment: .center, spacing: 0) {
    if (entry.data.events ?? []).isEmpty {
        Spacer(minLength: 0)
        Text("Nothing yet")
        Spacer(minLength: 0)
    } else {
        Spacer(minLength: 0)
        ForEach(Array((entry.data.events ?? []).enumerated()), id: \.offset) { hwIndex, hwItem in
            Text(hwItem.label ?? "")
        }
        Spacer(minLength: 0)
    }
}
.frame(maxHeight: .infinity, alignment: .top)''');
      expect(column.toKotlin(0, dataExpr: 'widgetData'), '''
Column(modifier = GlanceModifier.fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally) {
    if (widgetData.events.isNullOrEmpty()) {
        $kotlinSpacer
        $kotlinEmpty
        $kotlinSpacer
    } else {
        val hwItems = widgetData.events.orEmpty()
        $kotlinSpacer
        hwItems.forEachIndexed { _, hwItem ->
            $kotlinLabel
        }
        $kotlinSpacer
    }
}''');
    });

    test('takes no gap before whenEmpty and leaves out what renders nothing',
        () {
      const row = HWRow.builder(
        'ids',
        spacing: 8,
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        item: HWDataOnly([HWItemData(HWString('id'))]),
        whenEmpty: empty,
      );

      expect(row.toSwift(0, dataExpr: 'data'), '''
HStack(alignment: .center, spacing: 0) {
    if (data.ids ?? []).isEmpty {
        Text("Nothing yet")
    } else {
    }
}
.frame(maxWidth: .infinity, alignment: .leading)''');
      expect(row.toKotlin(0, dataExpr: 'data'), '''
Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
    if (data.ids.isNullOrEmpty()) {
        $kotlinEmpty
    } else {
    }
}''');
      expect(
        row.kotlinImports,
        isNot(contains('import androidx.glance.layout.padding')),
      );
      expect(row.itemReads, [const HWItemData(HWString('id'))]);
    });

    test('names a loop parameter nothing reads _', () {
      String header(HWWidget stack) => lines(
            stack.toKotlin(0, dataExpr: 'data'),
          ).firstWhere((line) => line.startsWith('hwItems.forEachIndexed'));

      expect(
        header(const HWRow.builder('tags', item: HWText.fixed('tag'))),
        'hwItems.forEachIndexed { _, _ ->',
      );
      expect(
        header(
          const HWRow.builder(
            'tags',
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            item: HWText.fixed('tag'),
          ),
        ),
        'hwItems.forEachIndexed { hwIndex, _ ->',
      );
      expect(
        header(const HWRow.builder('tags', spacing: 4, item: label)),
        'hwItems.forEachIndexed { hwIndex, hwItem ->',
      );
      expect(
        header(const HWRow.builder('tags', item: label)),
        'hwItems.forEachIndexed { _, hwItem ->',
      );
      expect(
        const HWRow.builder('tags', item: HWText.fixed('tag'))
            .toSwift(0, dataExpr: 'data'),
        contains('{ hwIndex, hwItem in'),
      );
    });

    test('declares its items in a whenEmpty builder of its own', () {
      const row = HWRow.builder(
        'days',
        item: label,
        whenEmpty: HWColumn.builder('hints', item: label),
      );

      expect(row.toKotlin(0, dataExpr: 'data'), '''
Row(verticalAlignment = Alignment.CenterVertically) {
    if (data.days.isNullOrEmpty()) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            val hwItems = data.hints.orEmpty()
            hwItems.forEachIndexed { _, hwItem ->
                $kotlinLabel
            }
        }
    } else {
        val hwItems = data.days.orEmpty()
        hwItems.forEachIndexed { _, hwItem ->
            $kotlinLabel
        }
    }
}''');
    });

    group('Android (Glance) items', () {
      test('put the gap on a Box around an item drawing a background', () {
        const column = HWColumn.builder(
          'cards',
          spacing: 8,
          item: HWColoredBox(color: green, child: label),
        );

        expect(
          column.toKotlin(0, dataExpr: 'data'),
          contains(
            '        Box(modifier = GlanceModifier.padding(top = if (hwIndex > 0) '
            '8.0.dp else 0.dp)) {\n'
            '            Text(modifier = GlanceModifier.background(',
          ),
        );
        expect(
          column.kotlinImports,
          containsAll([
            'import androidx.compose.ui.unit.dp',
            'import androidx.glance.layout.padding',
            'import androidx.glance.layout.Box',
          ]),
        );
      });

      test('put the gap on a Box around an icon', () {
        const row = HWRow.builder(
          'icons',
          spacing: 6,
          item: HWIcon.resolvedGlyph(
            0xe800,
            font: HWIconFont(family: 'Icons'),
            fontResourcePrefix: 'hw_font_demo',
          ),
        );

        expect(
          row.toKotlin(0, dataExpr: 'data'),
          contains(
            '        Box(modifier = GlanceModifier.padding(start = if (hwIndex > 0) '
            '6.0.dp else 0.dp)) {\n'
            '            Image(modifier = GlanceModifier.size(24.dp), ',
          ),
        );
      });

      for (final alignment in [
        HWCrossAxisAlignment.start,
        HWCrossAxisAlignment.end,
      ]) {
        test('a ${alignment.name}-aligned row puts every text in a bare Box',
            () {
          final row = HWRow.builder(
            'tags',
            crossAxisAlignment: alignment,
            item: label,
            whenEmpty: empty,
          );

          expect(lines(row.toKotlin(0, dataExpr: 'data')), [
            startsWith('Row(verticalAlignment = Alignment.'),
            'if (data.tags.isNullOrEmpty()) {',
            'Box {',
            kotlinEmpty,
            '}',
            '} else {',
            'val hwItems = data.tags.orEmpty()',
            'hwItems.forEachIndexed { _, hwItem ->',
            'Box {',
            kotlinLabel,
            '}',
            '}',
            '}',
            '}',
          ]);
          expect(
            row.kotlinImports,
            contains('import androidx.glance.layout.Box'),
          );
        });
      }

      test('a centred row leaves its texts unwrapped', () {
        const row = HWRow.builder('tags', item: label, whenEmpty: empty);

        expect(row.toKotlin(0, dataExpr: 'data'), isNot(contains('Box')));
        expect(
          row.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
        );
      });

      test('chains the gap onto the bare Box of a top-aligned row', () {
        const row = HWRow.builder(
          'tags',
          spacing: 4,
          crossAxisAlignment: HWCrossAxisAlignment.start,
          item: label,
        );

        expect(
          row.toKotlin(0, dataExpr: 'data'),
          contains(
            'Box(modifier = GlanceModifier.padding(start = if (hwIndex > 0) '
            '4.0.dp else 0.dp)) {',
          ),
        );
      });

      test('an item asking for the main axis takes a weight', () {
        const column = HWColumn.builder(
          'rows',
          spacing: 8,
          item: HWRow(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [label, HWText.fixed('x')],
          ),
        );
        const row = HWRow.builder(
          'columns',
          item: HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            children: [label, HWText.fixed('x')],
          ),
        );
        const weighted = HWColumn.builder(
          'rows',
          item: HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.center,
            children: [label],
          ),
        );

        expect(
          column.toKotlin(0, dataExpr: 'data'),
          contains(
            'Row(modifier = GlanceModifier.padding(top = if (hwIndex > 0) '
            '8.0.dp else 0.dp).fillMaxWidth(), ',
          ),
        );
        expect(
          row.toKotlin(0, dataExpr: 'data'),
          contains('Column(modifier = GlanceModifier.fillMaxHeight(), '),
        );
        expect(
          weighted.toKotlin(0, dataExpr: 'data'),
          contains('Column(modifier = GlanceModifier.defaultWeight(), '),
        );
        expect(
          weighted.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('an item behind a background moves its weight onto the Box', () {
        const column = HWColumn.builder(
          'rows',
          spacing: 8,
          item: HWColoredBox(
            color: green,
            child: HWColumn(
              mainAxisAlignment: HWMainAxisAlignment.center,
              children: [label],
            ),
          ),
        );

        expect(
          column.toKotlin(0, dataExpr: 'data'),
          contains(
            'Box(modifier = GlanceModifier.defaultWeight().padding(top = '
            'if (hwIndex > 0) 8.0.dp else 0.dp)) {',
          ),
        );
      });

      test('are emitted in the context the stack was handed', () {
        const row = HWRow.builder(
          'tags',
          item: HWSizeAdaptive(small: label, large: HWText.fixed('large')),
        );
        const context =
            HWEmitContext(reachableFamilies: {HWWidgetFamily.systemSmall});

        expect(
          row.toKotlin(0, dataExpr: 'data', context: context),
          isNot(contains('"large"')),
        );
        expect(
          row.toSwift(0, dataExpr: 'data', context: context),
          isNot(contains('"large"')),
        );
      });
    });

    group('iOS (SwiftUI) items', () {
      test('wrap a conditional item in a Group to take the gap', () {
        const column = HWColumn.builder(
          'notes',
          spacing: 4,
          item: HWDataExists(
            data: HWItemData(HWString('note')),
            whenPresent: label,
            whenAbsent: empty,
          ),
        );

        expect(column.toSwift(0, dataExpr: 'data'), r'''
VStack(alignment: .center, spacing: 0) {
    ForEach(Array((data.notes ?? []).enumerated()), id: \.offset) { hwIndex, hwItem in
        Group {
            if hwItem.note != nil {
                Text(hwItem.label ?? "")
            } else {
                Text("Nothing yet")
            }
        }
        .padding(.top, hwIndex > 0 ? 4.0 : 0)
    }
}''');
      });

      test('put the gap outside the background of an item', () {
        const column = HWColumn.builder(
          'cards',
          spacing: 8,
          item: HWColoredBox(color: green, child: label),
        );
        final swift = column.toSwift(0, dataExpr: 'data');

        expect(
          swift.indexOf('.background('),
          lessThan(swift.indexOf('.padding(.top, hwIndex > 0 ? 8.0 : 0)')),
        );
      });
    });
  });

  group('HWDataOnly in a stack', () {
    const a = HWText.fixed('a');
    const b = HWText.fixed('b');
    const dataOnly = HWDataOnly([HWString('id')]);

    test('gets no spacers of its own', () {
      const row = HWRow(
        mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
        children: [a, dataOnly, b],
      );
      expect(
        'Spacer(minLength: 0)'.allMatches(row.toSwift(0, dataExpr: 'd')).length,
        3,
      );
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(row.toKotlin(0, dataExpr: 'd'))
            .length,
        3,
      );
    });

    test('leaves no line and takes no gap', () {
      const column = HWColumn(spacing: 8, children: [dataOnly, a, b]);
      expect(column.toSwift(0, dataExpr: 'd'), '''
VStack(alignment: .center, spacing: 0) {
    Text("a")
    Text("b")
    .padding(.top, 8.0)
}''');
      expect(column.toKotlin(0, dataExpr: 'd'), '''
Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    Text(modifier = GlanceModifier.padding(top = 8.0.dp), text = "b", style = TextStyle(color = GlanceTheme.colors.onSurface))
}''');
    });

    test('still declares its data', () {
      const column = HWColumn(children: [a, dataOnly]);
      expect(column.dataDependencies, contains(const HWString('id')));
    });

    test('an adaptive rendering nothing on one platform is skipped there', () {
      const row = HWRow(
        spacing: 4,
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        children: [HWAdaptive(ios: dataOnly, android: a), b],
      );
      expect(row.toSwift(0, dataExpr: 'd'), '''
HStack(alignment: .center, spacing: 0) {
    Text("b")
}
.frame(maxWidth: .infinity, alignment: .leading)''');
      final kotlin = row.toKotlin(0, dataExpr: 'd');
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(kotlin)
            .length,
        1,
      );
      expect(kotlin, contains('padding(start = 4.0.dp)'));
    });
  });
}
