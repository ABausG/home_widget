import 'package:home_widget_generator/src/generator_error.dart';
import 'package:test/test.dart';

void main() {
  test('GeneratorError toString', () {
    expect(
      GeneratorError('bad').toString(),
      'GeneratorError: bad',
    );
  });
}
