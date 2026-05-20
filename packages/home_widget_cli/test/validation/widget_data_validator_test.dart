import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('validateWidgetData', () {
    test('rejects Kotlin-reserved identifiers for JSON roots (e.g. file)', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('file', HWString('title')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"file"'),
              contains('Kotlin'),
            ),
          ),
        ),
      );
    });

    test('rejects identifiers with underscores', () {
      void expectRejected(String key) {
        final spec = WidgetSpec(
          data: HomeWidget(name: 'T'),
          className: 'T',
          dataFields: [HWString(key)],
        );
        expect(
          () => validateWidgetData(spec),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('letters and digits'),
            ),
          ),
          reason: key,
        );
      }

      expectRejected('_private');
      expectRejected('foo_bar');
    });

    test('throws on reserved identifiers for primitive keys', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: [
          HWString('let'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('reserved keyword in Swift'),
          ),
        ),
      );
    });

    test('allows duplicate identical JSON declarations', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('title')),
          HWJson('fileKey', HWString('title')),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('throws on conflicting leaf types at the same JSON path', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('enabled')),
          HWJson('fileKey', HWBool('enabled', defaultValue: false)),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws on scalar vs nested object at same JSON segment', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('user')),
          HWJson(
            'fileKey',
            HWJson('user', HWBool('enabled', defaultValue: true)),
          ),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws when data name is empty', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: [
          HWString(''),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('reports multiple platforms for cross-language reserved names', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: [
          HWString('class'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf([
              contains('"class"'),
              contains('Dart'),
              contains('Swift'),
              contains('Kotlin'),
            ]),
          ),
        ),
      );
    });

    test('throws when nested JSON path collides with primitive at same segment',
        () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson(
            'fileKey',
            HWJson('user', HWBool('enabled', defaultValue: true)),
          ),
          HWJson('fileKey', HWString('user')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws when duplicate JSON leaves differ only by default value', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('leaf', defaultValue: 'a')),
          HWJson('fileKey', HWString('leaf', defaultValue: 'b')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });
  });
}
