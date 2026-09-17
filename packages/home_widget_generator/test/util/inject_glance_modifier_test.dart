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
