import 'package:home_widget_cli/src/models/payload_field.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';
import 'package:test/test.dart';

List<HWPayloadEntry> _payload(List<HWDataType<dynamic>> data) =>
    HWPayloadEntry.listOf(data);

PayloadField _single(List<List<HWDataType<dynamic>>> payloads) =>
    PayloadField.merge([for (final data in payloads) _payload(data)]).single;

void main() {
  group('listOf', () {
    test('has one field per entry, as one target sends it', () {
      final fields = PayloadField.listOf(
        _payload(const [
          HWString('city'),
          HWPayload('days', HWInt.fixed(7)),
          HWDouble('ratio', defaultValue: 0.5),
          HWPayload('town', HWString('home', defaultValue: "O'Hare")),
          HWPayload('since', HWDateTime.fixed('2026-09-22T10:00:00Z')),
        ]),
      );

      expect(
        fields.map((field) => (field.name, field.type, field.fallback)),
        [
          ('city', HWPayloadType.string, null),
          ('days', HWPayloadType.int, '7'),
          ('ratio', HWPayloadType.double, '0.5'),
          ('town', HWPayloadType.string, r"'O\'Hare'"),
          (
            'since',
            HWPayloadType.dateTime,
            'DateTime.fromMillisecondsSinceEpoch(1790071200000, isUtc: true)',
          ),
        ],
      );
      expect(fields.map((field) => field.isNullable), [
        true,
        false,
        false,
        false,
        false,
      ]);
    });

    test('spells an int fallback that compiles to JavaScript', () {
      final field = PayloadField.listOf(
        _payload(const [HWPayload('big', HWInt.fixed(9007199254740993))]),
      ).single;

      expect(field.fallback, '(2097152 * 4294967296 + 1)');
    });

    test('leaves out an entry no payload can carry', () {
      expect(
        PayloadField.listOf(_payload(const [HWImageData('avatar')])),
        isEmpty,
      );
    });
  });

  group('merge', () {
    test('falls back where every target falls back on the same value', () {
      final field = _single([
        const [HWPayload('step', HWInt.fixed(5))],
        const [HWInt('step', defaultValue: 5)],
        const [HWPayload('step', HWInt('size', defaultValue: 5))],
      ]);

      expect(field.fallback, '5');
      expect(field.isNullable, isFalse);
    });

    test('compares fallbacks of every type by value', () {
      expect(
        _single([
          const [HWPayload('on', HWBool.fixed(true))],
          const [HWBool('on', defaultValue: true)],
        ]).fallback,
        'true',
      );
      expect(
        _single([
          const [HWPayload('ratio', HWDouble.fixed(0.5))],
          const [HWDouble('ratio', defaultValue: 0.5)],
        ]).fallback,
        '0.5',
      );
      expect(
        _single([
          const [HWPayload('size', HWString.fixed('small'))],
          const [HWString('size', defaultValue: 'small')],
        ]).fallback,
        "'small'",
      );
    });

    test('compares fixed dates by their UTC millisecond', () {
      final field = _single([
        const [HWPayload('at', HWDateTime.fixed('2026-09-22T10:00:00Z'))],
        const [HWPayload('at', HWDateTime.fixed('2026-09-22T12:00:00+02:00'))],
      ]);

      expect(
        field.fallback,
        'DateTime.fromMillisecondsSinceEpoch(1790071200000, isUtc: true)',
      );
    });

    test('is nullable where the targets fall back on different values', () {
      const cases = <List<List<HWDataType<dynamic>>>>[
        [
          [HWPayload('amount', HWInt.fixed(250))],
          [HWPayload('amount', HWInt.fixed(500))],
        ],
        [
          [HWPayload('amount', HWInt.fixed(250))],
          [HWInt('amount', defaultValue: 500)],
        ],
        [
          [HWPayload('at', HWDateTime.fixed('2026-09-22T10:00:00Z'))],
          [HWPayload('at', HWDateTime.fixed('2026-09-22T11:00:00Z'))],
        ],
      ];
      for (final payloads in cases) {
        final field = _single(payloads);

        expect(field.isNullable, isTrue, reason: '$payloads');
        expect(field.fallback, isNull, reason: '$payloads');
      }
    });

    test('is nullable where a target sends a stored value without default', () {
      final field = _single([
        const [HWPayload('amount', HWInt.fixed(250))],
        const [HWPayload('amount', HWInt('customAmount'))],
      ]);

      expect(field.isNullable, isTrue);
    });

    test('is nullable where a target sends nothing under the name', () {
      final fields = PayloadField.merge([
        _payload(const [HWPayload('amount', HWInt.fixed(250))]),
        _payload(const [
          HWPayload('amount', HWInt.fixed(250)),
          HWPayload('source', HWString.fixed('custom')),
        ]),
        _payload(const []),
      ]);

      expect(
        fields.map((field) => (field.name, field.isNullable)),
        [('amount', true), ('source', true)],
      );
    });

    test('orders the fields by where their names first appear', () {
      final fields = PayloadField.merge([
        _payload(const [HWInt('b')]),
        _payload(const [HWInt('c'), HWInt('a'), HWInt('b')]),
        _payload(const [HWInt('a'), HWInt('d')]),
      ]);

      expect(fields.map((field) => field.name), ['b', 'c', 'a', 'd']);
    });

    test('takes the type of the first entry of a name', () {
      final field = _single([
        const [HWPayload('step', HWInt('a'))],
        const [HWPayload('step', HWString('b'))],
      ]);

      expect(field.type, HWPayloadType.int);
    });
  });
}
