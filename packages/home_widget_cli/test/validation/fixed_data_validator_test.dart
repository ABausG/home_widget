import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _font = HWIconFont(family: 'MaterialIcons');

/// One fixed value of every type that has a fixed form.
const _fixedValues = <HWDataType<dynamic>>[
  HWString.fixed('Hi'),
  HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'}),
  HWInt.fixed(3),
  HWDouble.fixed(2.5),
  HWBool.fixed(true),
  HWDateTime.fixed('2026-09-22T10:00:00Z'),
  HWIconData.resolvedFixed(0xe87d, iconFont: _font),
];

/// How an error names each of [_fixedValues].
const _spellings = [
  'HWString.fixed("Hi")',
  'HWString.localizedFixed',
  'HWInt.fixed(3)',
  'HWDouble.fixed(2.5)',
  'HWBool.fixed(true)',
  'HWDateTime.fixed("2026-09-22T10:00:00Z")',
  'HWIconData.fixed',
];

void main() {
  group('validateWidgetData with fixed values', () {
    test('accepts every fixed value as a direct argument', () {
      const tree = HWColumn(
        children: [
          HWText(HWString.fixed('Hello world!')),
          HWText(HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'})),
          HWText.number(HWInt.fixed(3)),
          HWText.number(HWDouble.fixed(2.5)),
          HWText(HWBool.fixed(true)),
          HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00Z')),
          HWText.dateTime(HWDateTime.fixed('2026-09-22T12:00:00+02:00')),
          HWImage(HWImageData.asset('assets/logo.png')),
          HWText(HWString('label')),
        ],
      );

      expect(
        () => validateWidgetData(_spec(tree, localization: _localization)),
        returnsNormally,
      );
    });

    test('accepts two different fixed values of one type', () {
      const tree = HWColumn(
        children: [
          HWText(HWString.fixed('a')),
          HWText(HWString.fixed('b')),
          HWText(HWInt.fixed(1)),
          HWText(HWInt.fixed(2)),
        ],
      );

      expect(() => validateWidgetData(_spec(tree)), returnsNormally);
    });

    test('skips the key collision check for fixed values sharing no key', () {
      const tree = HWColumn(
        children: [
          HWText(HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'})),
          HWText(HWString.localizedFixed({'en': 'Bye', 'de': 'Tschüss'})),
          HWImage(HWImageData.asset('assets/logo.png')),
          HWRow.builder(
            'assetsLogoPng',
            item: HWText(HWItemData(HWString('label'))),
          ),
        ],
      );
      final spec = _spec(tree, localization: _localization);

      expect(spec.declaredDataFields.where((f) => f.isFixed), hasLength(3));
      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('rejects a fixed value inside HWTimedData', () {
      for (final (index, value) in _fixedValues.indexed) {
        expect(
          () => validateWidgetData(
            _declaring([HWTimedData(value)], localization: _localization),
          ),
          _throwsMessage(
            'HWTimedData cannot wrap ${_spellings[index]}: a fixed value never '
            'changes, so there is nothing for a timeline to switch between. '
            'Use it without HWTimedData, or wrap a stored field.',
          ),
        );
      }
    });

    test('rejects a fixed value inside HWJson, however deep', () {
      for (final (index, value) in _fixedValues.indexed) {
        expect(
          () => validateWidgetData(
            _declaring(
              [HWJson('order', value)],
              localization: _localization,
            ),
          ),
          _throwsMessage(
            'HWJson cannot carry ${_spellings[index]} (in "order"): a fixed '
            'value is written into the widget, so there is nothing to read out '
            'of the group. Use it without HWJson, or nest a stored field.',
          ),
        );
      }

      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson('order', HWJson('customer', HWString.fixed('Hi'))),
          ]),
        ),
        _throwsMessage(contains('HWJson cannot carry HWString.fixed("Hi")')),
      );
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWTimedData(HWJson('order', HWInt.fixed(3))),
          ]),
        ),
        _throwsMessage(contains('HWJson cannot carry HWInt.fixed(3)')),
      );
    });

    test('rejects a fixed value inside HWItemData', () {
      for (final (index, value) in _fixedValues.indexed) {
        final tree = HWRow.builder(
          'forecast',
          item: value is HWIconData
              ? HWIcon(HWItemData(value))
              : HWText(HWItemData(value)),
        );

        expect(
          () => validateWidgetData(_spec(tree, localization: _localization)),
          _throwsMessage(
            'Widget "T": HWItemData cannot wrap ${_spellings[index]} (in list '
            '"forecast"). A fixed value is the same for every item, so there '
            'is nothing to store per item. Use it without HWItemData, or wrap '
            'a stored field.',
          ),
        );
      }

      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWText(HWTimedData(HWItemData(HWString.fixed('Hi')))),
            ),
          ),
        ),
        _throwsMessage(
          contains('HWItemData cannot wrap HWString.fixed("Hi")'),
        ),
      );
    });

    test('rejects a fixed value in HWDataOnly', () {
      for (final (index, value) in _fixedValues.indexed) {
        expect(
          () => validateWidgetData(
            _spec(
              HWDataOnly([const HWString('label'), value]),
              localization: _localization,
            ),
          ),
          _throwsMessage(
            'Widget "T": HWDataOnly cannot declare ${_spellings[index]}. A '
            'fixed value is written into the widget and never stored, so there '
            'is nothing for HWDataOnly to declare. Remove it, or declare a '
            'stored field.',
          ),
        );
      }

      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText(HWString('label')),
                HWDataOnly([HWImageData.asset('assets/logo.png')]),
              ],
            ),
          ),
        ),
        _throwsMessage(
          contains(
            'HWDataOnly cannot declare HWImageData.asset("assets/logo.png")',
          ),
        ),
      );
    });

    test('rejects HWBoolConditional on a fixed value', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWBoolConditional(
              data: HWBool.fixed(true),
              whenTrue: HWText(HWString('yes')),
              whenFalse: HWText(HWString('no')),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": HWBoolConditional cannot test HWBool.fixed(true). A '
          'fixed value never changes, so only one of the two branches is ever '
          'rendered. Render that branch directly, or test a stored '
          'HWBool("key").',
        ),
      );
    });

    test('rejects HWDataExists on a fixed value', () {
      const fixed = <HWDataType<dynamic>>[
        HWString.fixed('Hi'),
        HWInt.fixed(3),
        HWDouble.fixed(2.5),
        HWBool.fixed(true),
        HWDateTime.fixed('2026-09-22T10:00:00Z'),
        HWIconData.resolvedFixed(0xe87d, iconFont: _font),
      ];
      const spellings = [
        'HWString.fixed("Hi")',
        'HWInt.fixed(3)',
        'HWDouble.fixed(2.5)',
        'HWBool.fixed(true)',
        'HWDateTime.fixed("2026-09-22T10:00:00Z")',
        'HWIconData.fixed',
      ];

      for (final (index, value) in fixed.indexed) {
        expect(
          () => validateWidgetData(
            _spec(
              HWDataExists(
                data: value,
                whenPresent: const HWText(HWString('yes')),
                whenAbsent: const HWText(HWString('no')),
              ),
            ),
          ),
          _throwsMessage(
            'Widget "T": HWDataExists cannot test ${spellings[index]}. A fixed '
            'value is always there, so the check is always true and the '
            'whenAbsent branch is never rendered. Render the whenPresent '
            'branch directly, or test a stored field.',
          ),
        );
      }
    });

    test('rejects an HWDateTime.fixed that does not parse', () {
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWDateTime.fixed('next tuesday'))),
        ),
        _throwsMessage(
          'Widget "T": HWDateTime.fixed("next tuesday") is not an ISO 8601 '
          'date. Write the instant as e.g. "2024-03-08T09:41:00Z".',
        ),
      );
    });

    test('rejects a fixed double that is not finite', () {
      const values = [
        (double.infinity, 'Infinity'),
        (double.negativeInfinity, '-Infinity'),
        (double.nan, 'NaN'),
      ];

      for (final (value, spelling) in values) {
        for (final text in [
          HWText(HWDouble.fixed(value)),
          HWText.number(HWDouble.fixed(value)),
        ]) {
          expect(
            () => validateWidgetData(_spec(HWColumn(children: [text]))),
            _throwsMessage(
              'Widget "T": HWDouble.fixed($spelling) is not a finite number, '
              'so there is no literal to write into the widget. Use a finite '
              'value.',
            ),
            reason: spelling,
          );
        }
      }
    });

    test('accepts every ISO 8601 spelling of a fixed instant with a zone', () {
      for (final iso in [
        '2026-09-22T10:00Z',
        '2026-09-22 10:00:00Z',
        '20260922T100000Z',
        '2026-09-22T10:00:00,5Z',
        '2026-09-22T12:00:00+02:00',
      ]) {
        expect(
          () => validateWidgetData(
            _spec(HWText.dateTime(HWDateTime.fixed(iso))),
          ),
          returnsNormally,
          reason: iso,
        );
      }
    });

    test('rejects an HWDateTime.fixed that names no zone', () {
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00'))),
        ),
        _throwsMessage(
          'Widget "T": HWDateTime.fixed("2026-09-22T10:00:00") names no time '
          'zone, so which instant it means would depend on where it is read. '
          'End it in Z or an offset such as +02:00. Write the instant as e.g. '
          '"2024-03-08T09:41:00Z".',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText(HWDateTime.fixed('2026-09-22'))),
        ),
        _throwsMessage(contains('names no time zone')),
      );
    });

    test('rejects a fixed value as the data of a currency or a time zone', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('price'),
              format: HWNumberFormat.currency(
                currency: HWCurrency.data(HWString.fixed('EUR')),
              ),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": HWCurrency.data reads HWString.fixed("EUR"). '
          'HWCurrency.data reads a stored field; write a constant with '
          'HWCurrency.code instead.',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('at'),
              timeZone: HWTimeZone.data(HWString.fixed('Europe/Berlin')),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": HWTimeZone.data reads HWString.fixed("Europe/Berlin"). '
          'HWTimeZone.data reads a stored field; write a constant with '
          'HWTimeZone.named instead.',
        ),
      );
    });

    test('points constant text written as a key to HWString.fixed', () {
      expect(
        () => validateWidgetData(
          _spec(const HWText(HWString('Hello world'))),
        ),
        _throwsMessage(
          'Invalid data name "Hello world" (field "Hello world"): use ASCII '
          'letters and digits only; must start with a letter. For constant '
          'text, use HWString.fixed(...).',
        ),
      );
    });

    test('keeps the HWString.fixed hint off every other invalid name', () {
      const invalid = 'use ASCII letters and digits only; must start with a '
          'letter.';

      expect(
        () => validateWidgetData(
          _spec(const HWText.number(HWInt('3 apples'))),
        ),
        _throwsMessage(
          'Invalid data name "3 apples" (field "3 apples"): $invalid',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText(HWJson('my group', HWString('label')))),
        ),
        _throwsMessage(
          'Invalid data name "my group" (JSON access my group.label): $invalid',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText(HWJson('order', HWString('Total: ')))),
        ),
        _throwsMessage(
          'Invalid data name "Total: " (field "Total: "): $invalid',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText(HWJson('order', HWJson('my customer', HWString('n')))),
          ),
        ),
        _throwsMessage(
          'Invalid data name "my customer" (JSON access my customer.n): '
          '$invalid',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText(HWTimedData(HWString('Hello world')))),
        ),
        _throwsMessage(
          'Invalid data name "Hello world" (field "Hello world"): $invalid',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText(
              HWString.localized('my title', defaultTranslations: {'en': 'T'}),
            ),
            localization: _localization,
          ),
        ),
        _throwsMessage(
          'Invalid data name "my title" (field "my title"): $invalid',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWText(HWItemData(HWString('my label'))),
            ),
          ),
        ),
        _throwsMessage(
          'Invalid data name "my label" (item field "my label" of list '
          '"forecast"): $invalid',
        ),
      );
    });
  });
}

const HomeWidgetLocalization _localization = HomeWidgetLocalization(
  defaultLocale: 'en',
  supportedLocales: ['en', 'de'],
);

/// A spec declaring [dataFields] verbatim, without going through a tree.
WidgetSpec _declaring(
  List<HWDataType<dynamic>> dataFields, {
  HomeWidgetLocalization? localization,
}) =>
    WidgetSpec(
      data: HomeWidget(name: 'T', localization: localization),
      className: 'T',
      dataFields: dataFields,
    );

/// A spec whose data fields are exactly what [tree] binds, the way the parser
/// builds one.
WidgetSpec _spec(HWWidget tree, {HomeWidgetLocalization? localization}) =>
    WidgetSpec(
      data: HomeWidget(name: 'T', widget: tree, localization: localization),
      className: 'T',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

Matcher _throwsMessage(Object message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );
