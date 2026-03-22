import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidget.toSwift', () {
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

    test('emits int data ref', () {
      final node = HWText(HWInt('count'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.count != nil ? "\\(data.count!)" : "0")');
    });

    test('emits bool data ref', () {
      final node = HWText(HWBool('flag'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.flag != nil ? "\\(data.flag!)" : "false")');
    });

    test('emits double data ref', () {
      final node = HWText(HWDouble('ratio'));
      final result = node.toSwift(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(data.ratio != nil ? "\\(data.ratio!)" : "0.0")');
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

    test('VStack from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
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
      expect(result, contains('HStack {'));
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
      expect(result, contains('VStack {'));
      expect(result, contains('HStack {'));
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
      expect(result, contains('VStack {'));
      expect(result, contains('Text(entry.widgetData.countLabel ?? "")'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      // Root VStack at 0 indent
      expect(result, startsWith('VStack {'));
      // HStack at 4 spaces
      expect(result, contains('    HStack {'));
      // Text at 8 spaces
      expect(result, contains('        Text("x")'));
    });

    test('Column with .start alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.start,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .leading) {'));
    });

    test('Row with .end alignment', () {
      final node = HWRow(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.end,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('HStack(alignment: .bottom) {'));
    });

    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .center) {'));
    });

    test('no alignment emits bare stack', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, isNot(contains('alignment:')));
    });

    test(
        'Column with .center emits Spacer before and after (mainAxisAlignment)',
        () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      // Should have 2 spacers
      expect('Spacer()'.allMatches(result).length, 2);
    });

    test('Column with .end emits Spacer before children', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.end,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      // Only 1 spacer (before)
      expect('Spacer()'.allMatches(result).length, 1);
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
      expect(result, contains('HStack {'));
      expect(result, contains('Text("a")'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("b")'));
      // 1 spacer between 2 children
      expect('Spacer()'.allMatches(result).length, 1);
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
      // Spacer before first, between, and after last = 3 spacers
      expect('Spacer()'.allMatches(result).length, 3);
    });

    test('Column with .start emits no spacers', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.start,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, isNot(contains('Spacer()')));
    });

    test('HWFill emits frame max', () {
      final node = HWFill(child: HWText.fixed('a'));
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result,
          'Text("a")\n.frame(maxWidth: .infinity, maxHeight: .infinity)');
    });

    test('HWText emits style and alignment', () {
      final node = HWText.fixed('Styled', 
        style: HWTextStyle(
          fontSize: 24, 
          fontWeight: HWFontWeight.bold, 
          italic: true, 
          underline: true, 
          color: HWFixedColor(0xFFFF0000)
        ),
        textAlign: HWTextAlign.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.system(size: 24.0, weight: .bold))'));
      expect(result, contains('.foregroundColor(Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))'));
      expect(result, contains('.italic()'));
      expect(result, contains('.underline(true)'));
      expect(result, contains('.multilineTextAlignment(.center)'));
    });

    test('HWRoleTextStyle emits semantic font', () {
      final node = HWText.fixed('Role', style: HWRoleTextStyle.headline());
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.headline)'));
    });

    test('HWRoleTextStyle overridden by explicit size', () {
      final node = HWText.fixed('Role Override', style: HWRoleTextStyle.headline(fontSize: 30));
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('.font(.system(size: 30.0))'));
    });

    test('HWTextStyle baseStyle resolution', () {
      final node = HWText.fixed('Base Base', 
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
}
