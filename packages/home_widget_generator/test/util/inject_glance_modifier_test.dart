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
