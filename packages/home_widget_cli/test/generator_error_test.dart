import 'package:home_widget_cli/src/generator_error.dart';
import 'package:test/test.dart';

void main() {
  group('GeneratorError', () {
    test('toString includes the message', () {
      const error = GeneratorError('something went wrong');
      expect(error.toString(), 'GeneratorError: something went wrong');
    });

    test('is an Exception', () {
      const error = GeneratorError('msg');
      expect(error, isA<Exception>());
      expect(error.message, 'msg');
    });
  });
}
