import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/utils/inject_glance_modifier.dart';
import 'package:test/test.dart';

void main() {
  group('injectGlanceModifier', () {
    test('injects modifier into simple Text call', () {
      expect(
        injectGlanceModifier('Text("a")', 'fillMaxSize'),
        'Text(modifier = GlanceModifier.fillMaxSize, "a")',
      );
    });

    test('injects modifier into Column with brace body', () {
      expect(
        injectGlanceModifier('Column {', 'fillMaxSize'),
        'Column(modifier = GlanceModifier.fillMaxSize) {',
      );
    });

    test('rewrites existing GlanceModifier. prefix in args', () {
      expect(
        injectGlanceModifier(
          'Column(GlanceModifier.padding(4.dp)) {',
          'fillMaxSize',
        ),
        'Column(GlanceModifier.fillMaxSize.padding(4.dp)) {',
      );
    });

    test('drops a fill one axis when both axes are injected', () {
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.fillMaxHeight(), '
              'horizontalAlignment = Alignment.Start) {',
          'fillMaxSize()',
        ),
        'Column(modifier = GlanceModifier.fillMaxSize(), '
        'horizontalAlignment = Alignment.Start) {',
      );
      expect(
        injectGlanceModifier(
          'Row(GlanceModifier.padding(4.dp).fillMaxWidth()) {',
          'fillMaxSize()',
        ),
        'Row(GlanceModifier.fillMaxSize().padding(4.dp)) {',
      );
    });

    test('reads the fills of the modifier chain only', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.fillMaxHeight(), '
              'text = "a.fillMaxWidth()")',
          'fillMaxSize()',
        ),
        'Text(modifier = GlanceModifier.fillMaxSize(), '
        'text = "a.fillMaxWidth()")',
      );
    });

    test('injects beside a text literal naming a fill', () {
      expect(
        injectGlanceModifier('Text(text = "fillMaxSize()")', 'fillMaxWidth()'),
        'Text(modifier = GlanceModifier.fillMaxWidth(), '
        'text = "fillMaxSize()")',
      );
      expect(
        injectGlanceModifier(
          'Text(text = "GlanceModifier.fillMaxSize()")',
          'fillMaxWidth()',
        ),
        'Text(modifier = GlanceModifier.fillMaxWidth(), '
        'text = "GlanceModifier.fillMaxSize()")',
      );
    });

    test('keeps the arguments after a chain holding brackets', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.padding(start = 8.dp, top = 4.dp), '
              'text = "a")',
          'fillMaxWidth()',
        ),
        'Text(modifier = GlanceModifier.fillMaxWidth()'
        '.padding(start = 8.dp, top = 4.dp), text = "a")',
      );
    });

    test('leaves a chain that already fills both axes alone', () {
      const code = 'Column(modifier = GlanceModifier.fillMaxSize()) {';
      expect(injectGlanceModifier(code, 'fillMaxHeight()'), code);
      expect(injectGlanceModifier(code, 'fillMaxWidth()'), code);
    });

    test('reads a fill off the calls, not off a string literal', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.clickable(actionStartActivity'
              '<MainActivity>(context, Uri.parse("app://x?q=fillMaxSize()"))), '
              'text = "a")',
          'fillMaxWidth()',
        ),
        'Text(modifier = GlanceModifier.fillMaxWidth().clickable'
        '(actionStartActivity<MainActivity>(context, '
        'Uri.parse("app://x?q=fillMaxSize()"))), text = "a")',
      );
    });

    test('a size() does not keep an injected fill out', () {
      expect(
        injectGlanceModifier(
          'Image(modifier = GlanceModifier.size(24.0.dp), provider = p)',
          'fillMaxWidth()',
        ),
        'Image(modifier = GlanceModifier.fillMaxWidth().height(24.0.dp), '
        'provider = p)',
      );
    });

    test('drops the width the chain already carried', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.width(100.0.dp), text = "a")',
          'width(80.0.dp)',
        ),
        'Text(modifier = GlanceModifier.width(80.0.dp), text = "a")',
      );
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.fillMaxWidth()) {',
          'width(80.0.dp)',
        ),
        'Column(modifier = GlanceModifier.width(80.0.dp)) {',
      );
    });

    test('drops the height the chain already carried', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.height(50.0.dp), text = "a")',
          'height(40.0.dp)',
        ),
        'Text(modifier = GlanceModifier.height(40.0.dp), text = "a")',
      );
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.fillMaxHeight()) {',
          'fillMaxHeight()',
        ),
        'Column(modifier = GlanceModifier.fillMaxHeight()) {',
      );
    });

    test('leaves a chain filling both axes the one it is not given', () {
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.fillMaxSize()) {',
          'width(80.0.dp)',
        ),
        'Column(modifier = GlanceModifier.width(80.0.dp).fillMaxHeight()) {',
      );
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.fillMaxSize()) {',
          'height(40.0.dp)',
        ),
        'Column(modifier = GlanceModifier.height(40.0.dp).fillMaxWidth()) {',
      );
    });

    test('drops every size when both axes are injected', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.width(100.0.dp).height(50.0.dp)'
              '.padding(4.dp), text = "a")',
          'fillMaxSize()',
        ),
        'Text(modifier = GlanceModifier.fillMaxSize().padding(4.dp), '
        'text = "a")',
      );
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.fillMaxSize()) {',
          'width(80.0.dp).height(40.0.dp)',
        ),
        'Column(modifier = GlanceModifier.width(80.0.dp).height(40.0.dp)) {',
      );
    });

    test('a size() sizes both axes, and keeps the one it is not given', () {
      expect(
        injectGlanceModifier(
          'Image(modifier = GlanceModifier.size(24.0.dp), provider = p)',
          'width(80.0.dp).height(40.0.dp)',
        ),
        'Image(modifier = GlanceModifier.width(80.0.dp).height(40.0.dp), '
        'provider = p)',
      );
      expect(
        injectGlanceModifier(
          'Image(modifier = GlanceModifier.size(24.0.dp), provider = p)',
          'width(80.0.dp)',
        ),
        'Image(modifier = GlanceModifier.width(80.0.dp).height(24.0.dp), '
        'provider = p)',
      );
      expect(
        injectGlanceModifier(
          'Image(modifier = GlanceModifier.size(24.0.dp), provider = p)',
          'height(40.0.dp)',
        ),
        'Image(modifier = GlanceModifier.height(40.0.dp).width(24.0.dp), '
        'provider = p)',
      );
    });

    test('a wrapContent call is a size too', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.wrapContentWidth(), text = "a")',
          'width(80.0.dp)',
        ),
        'Text(modifier = GlanceModifier.width(80.0.dp), text = "a")',
      );
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.wrapContentSize(), text = "a")',
          'width(80.0.dp)',
        ),
        'Text(modifier = GlanceModifier.width(80.0.dp).wrapContentHeight(), '
        'text = "a")',
      );
    });

    test('keeps the modifiers sizing nothing, in the order they were in', () {
      expect(
        injectGlanceModifier(
          'Text(modifier = GlanceModifier.background(Color.Red)'
              '.padding(start = 8.dp).height(50.0.dp), text = "a")',
          'width(80.0.dp)',
        ),
        'Text(modifier = GlanceModifier.width(80.0.dp).background(Color.Red)'
        '.padding(start = 8.dp).height(50.0.dp), text = "a")',
      );
    });

    test('keeps a defaultWeight the chain carried, whose axis it cannot see',
        () {
      expect(
        injectGlanceModifier(
          'Column(modifier = GlanceModifier.defaultWeight()) {',
          'height(40.0.dp)',
        ),
        'Column(modifier = GlanceModifier.height(40.0.dp).defaultWeight()) {',
      );
    });

    test('an injected defaultWeight sizes the axis it is named with', () {
      const code = 'Column(modifier = GlanceModifier.fillMaxHeight()) {';
      expect(
        injectGlanceModifier(
          code,
          'fillMaxWidth().defaultWeight()',
          weightAxis: GlanceSizeAxis.height,
        ),
        'Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {',
      );
      expect(
        injectGlanceModifier(code, 'fillMaxWidth().defaultWeight()'),
        'Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight()'
        '.fillMaxHeight()) {',
      );
    });

    test('rewrites bare GlanceModifier token in args', () {
      expect(
        injectGlanceModifier('Column(GlanceModifier) {', 'fillMaxSize'),
        'Column(GlanceModifier.fillMaxSize) {',
      );
    });

    test('injects into both branches of if / else', () {
      expect(
        injectGlanceModifier(
          'if (true) { Text("a") } else { Text("b") }',
          'fillMaxSize',
        ),
        'if (true) { Text(modifier = GlanceModifier.fillMaxSize, "a") } else { Text(modifier = GlanceModifier.fillMaxSize, "b") }',
      );
    });

    test('injects into single-branch if', () {
      expect(
        injectGlanceModifier('if (true) { Text("a") }', 'fillMaxSize'),
        'if (true) { Text(modifier = GlanceModifier.fillMaxSize, "a") }',
      );
    });

    test('injects into every branch of an if / else if / else chain', () {
      expect(
        injectGlanceModifier(
          'if (a) { Text("a") } else if (b) { Text("b") } '
              'else if (c) { Text("c") } else { Text("d") }',
          'fillMaxSize',
        ),
        'if (a) { Text(modifier = GlanceModifier.fillMaxSize, "a") } '
        'else if (b) { Text(modifier = GlanceModifier.fillMaxSize, "b") } '
        'else if (c) { Text(modifier = GlanceModifier.fillMaxSize, "c") } '
        'else { Text(modifier = GlanceModifier.fillMaxSize, "d") }',
      );
    });

    test('injects into a branch nested in another branch', () {
      expect(
        injectGlanceModifier(
          'if (a) { if (b) { Text("a") } else { Text("b") } } else { Text("c") }',
          'fillMaxSize',
        ),
        'if (a) { if (b) { Text(modifier = GlanceModifier.fillMaxSize, "a") } '
        'else { Text(modifier = GlanceModifier.fillMaxSize, "b") } } '
        'else { Text(modifier = GlanceModifier.fillMaxSize, "c") }',
      );
    });

    test('stops at a statement that only follows the if chain', () {
      expect(
        injectGlanceModifier(
          'if (a) { Text("a") }\nColumn { Text("b") }',
          'fillMaxSize',
        ),
        'if (a) { Text(modifier = GlanceModifier.fillMaxSize, "a") }\n'
        'Column { Text("b") }',
      );
    });

    test('injects into every branch of a when statement', () {
      expect(
        injectGlanceModifier(
          'when (LocalSize.current) {\n'
              '    DpSize(250.dp, 110.dp) -> {\n'
              '        Text(text = "m")\n'
              '    }\n'
              '    else -> {\n'
              '        Text(text = "s")\n'
              '    }\n'
              '}',
          'fillMaxSize()',
        ),
        'when (LocalSize.current) {\n'
        '    DpSize(250.dp, 110.dp) -> {\n'
        '        Text(modifier = GlanceModifier.fillMaxSize(), text = "m")\n'
        '    }\n'
        '    else -> {\n'
        '        Text(modifier = GlanceModifier.fillMaxSize(), text = "s")\n'
        '    }\n'
        '}',
      );
    });

    test('counts no brace written inside a string literal', () {
      expect(
        injectGlanceModifier(
          'when (LocalSize.current) {\n'
              '    DpSize(250.dp, 110.dp) -> {\n'
              r'        Text(text = "} {\" }")'
              '\n'
              '    }\n'
              '    else -> {\n'
              '        Text(text = "s")\n'
              '    }\n'
              '}',
          'fillMaxSize()',
        ),
        'when (LocalSize.current) {\n'
        '    DpSize(250.dp, 110.dp) -> {\n'
        r'        Text(modifier = GlanceModifier.fillMaxSize(), text = "} {\" }")'
        '\n'
        '    }\n'
        '    else -> {\n'
        '        Text(modifier = GlanceModifier.fillMaxSize(), text = "s")\n'
        '    }\n'
        '}',
      );
    });

    test('injects into an if nested in a when branch', () {
      expect(
        injectGlanceModifier(
          'when (x) {\n'
              '    A -> {\n'
              '        if (b) { Text("a") } else { Text("b") }\n'
              '    }\n'
              '    else -> {\n'
              '        Text("c")\n'
              '    }\n'
              '}',
          'fillMaxSize',
        ),
        'when (x) {\n'
        '    A -> {\n'
        '        if (b) { Text(modifier = GlanceModifier.fillMaxSize, "a") } '
        'else { Text(modifier = GlanceModifier.fillMaxSize, "b") }\n'
        '    }\n'
        '    else -> {\n'
        '        Text(modifier = GlanceModifier.fillMaxSize, "c")\n'
        '    }\n'
        '}',
      );
    });

    test('wraps an if whose block is never closed in a Box', () {
      expect(
        injectGlanceModifier('if (a) { Text("a")', 'fillMaxSize'),
        'Box(modifier = GlanceModifier.fillMaxSize) {\n'
        '    if (a) { Text("a")\n'
        '}',
      );
    });

    test('wraps a when whose string literal is never closed in a Box', () {
      expect(
        injectGlanceModifier(
          'when (x) {\n    A -> { Text("a) }',
          'fillMaxSize',
        ),
        'Box(modifier = GlanceModifier.fillMaxSize) {\n'
        '    when (x) {\n'
        '        A -> { Text("a) }\n'
        '}',
      );
    });

    test('wraps a when with no brace-delimited branch in a Box', () {
      expect(
        injectGlanceModifier('when (x) { A -> Text("a") }', 'fillMaxSize'),
        'Box(modifier = GlanceModifier.fillMaxSize) {\n'
        '    when (x) { A -> Text("a") }\n'
        '}',
      );
    });

    test('injects the emitted HWSizeAdaptive when', () {
      const adaptive = HWSizeAdaptive(
        small: HWText.fixed('s'),
        medium: HWText.fixed('m'),
      );
      expect(
        injectGlanceModifier(
          adaptive.toKotlin(0, dataExpr: 'd'),
          'fillMaxSize()',
        ),
        'when (LocalSize.current) {\n'
        '    DpSize(250.dp, 110.dp) -> {\n'
        '        Text(modifier = GlanceModifier.fillMaxSize(), text = "m", style = TextStyle(color = GlanceTheme.colors.onSurface))\n'
        '    }\n'
        '    else -> {\n'
        '        Text(modifier = GlanceModifier.fillMaxSize(), text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))\n'
        '    }\n'
        '}',
      );
    });

    test('wraps unrecognized code in Box with modifier', () {
      expect(
        injectGlanceModifier('foo', 'fillMaxSize'),
        'Box(modifier = GlanceModifier.fillMaxSize) {\n'
        '    foo\n'
        '}',
      );
    });

    test('preserves leading indent on Column', () {
      expect(
        injectGlanceModifier('  Column {', 'fillMaxSize'),
        '  Column(modifier = GlanceModifier.fillMaxSize) {',
      );
    });
  });

  group('wrapGlanceRootContent', () {
    test('wraps in centered Box with modifier chain', () {
      expect(
        wrapGlanceRootContent(
          'Column {\n    Text("a")\n}',
          modifier: 'padding(16.dp).fillMaxSize()',
        ),
        'Box(modifier = GlanceModifier.padding(16.dp).fillMaxSize(), contentAlignment = Alignment.Center) {\n'
        '    Column {\n'
        '        Text("a")\n'
        '    }\n'
        '}',
      );
    });

    test('preserves leading indent on wrapper', () {
      expect(
        wrapGlanceRootContent(
          '  Text("a")',
          modifier: 'fillMaxSize()',
        ),
        '  Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {\n'
        '      Text("a")\n'
        '  }',
      );
    });
  });
}
