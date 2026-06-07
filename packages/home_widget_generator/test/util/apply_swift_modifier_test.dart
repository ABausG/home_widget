import 'package:home_widget_generator/src/utils/apply_swift_modifier.dart';
import 'package:test/test.dart';

void main() {
  group('applySwiftModifier', () {
    test('appends modifier directly to a regular View', () {
      expect(
        applySwiftModifier('Text("a")', '.frame(maxWidth: .infinity)', 0),
        'Text("a")\n.frame(maxWidth: .infinity)',
      );
    });

    test('preserves indentation when appending to a regular View', () {
      expect(
        applySwiftModifier('    Text("a")', '.padding(8)', 1),
        '    Text("a")\n    .padding(8)',
      );
    });

    test('wraps a leading if/else in Group { ... } before modifier', () {
      final input = 'if cond {\n'
          '    Text("a")\n'
          '} else {\n'
          '    Text("b")\n'
          '}';
      expect(
        applySwiftModifier(input, '.frame(maxWidth: .infinity)', 0),
        'Group {\n'
        '    if cond {\n'
        '        Text("a")\n'
        '    } else {\n'
        '        Text("b")\n'
        '    }\n'
        '}\n'
        '.frame(maxWidth: .infinity)',
      );
    });

    test('wraps a leading switch statement in Group { ... }', () {
      final input = 'switch value {\n'
          'case .a: Text("a")\n'
          'default: Text("b")\n'
          '}';
      final result = applySwiftModifier(input, '.padding(8)', 0);
      expect(result, startsWith('Group {\n'));
      expect(result, endsWith('\n}\n.padding(8)'));
      expect(result, contains('switch value {'));
    });

    test('does not wrap when child only contains "if" inside a larger View',
        () {
      const input = 'Text(condition ? "a" : "b")';
      expect(
        applySwiftModifier(input, '.padding(8)', 0),
        'Text(condition ? "a" : "b")\n.padding(8)',
      );
    });

    test('handles indented leading if/else', () {
      const input = '    if cond { Text("a") } else { Text("b") }';
      final result =
          applySwiftModifier(input, '.frame(maxWidth: .infinity)', 1);
      expect(result, startsWith('    Group {\n'));
      expect(result, contains('        if cond'));
      expect(result, endsWith('    }\n    .frame(maxWidth: .infinity)'));
    });
  });
}
