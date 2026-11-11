import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

const _label = HWText(HWString.fixed('label'));

const _handler = InteractionHandler(
  libraryUri: 'package:app/handlers.dart',
  name: 'onCounterInteraction',
);

HWButton _button(
  String id, {
  List<HWDataType<dynamic>> data = const [],
  HWWidget child = _label,
}) =>
    HWButton(id, data: data, child: child);

HWLink _link(String id, {HWWidget child = _label}) =>
    HWLink(id, url: 'myapp://$id', child: child);

/// A spec rendering [tree], whose data fields are what the tree reads, the
/// way the schema parser builds one.
WidgetSpec _spec(
  HWWidget tree, {
  InteractionHandler? handler = _handler,
  List<HWWidgetFamily>? families = const [HWWidgetFamily.systemMedium],
  bool android = true,
  bool iOS = true,
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Counter',
        android: android ? const HomeWidgetAndroidConfiguration() : null,
        iOS: iOS
            ? HomeWidgetIOSConfiguration(
                groupId: 'group.counter',
                supportedFamilies: families,
              )
            : null,
      ),
      className: 'Counter',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
      interactionHandler: handler,
    );

Matcher _throwsMessage(Matcher message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = useMockLogger();
  });

  group('HWButton', () {
    test('is accepted with a payload of every type', () {
      final spec = _spec(
        HWColumn(
          children: [
            _button(
              'increment',
              data: const [
                HWString('city'),
                HWInt('count', defaultValue: 1),
                HWDouble('ratio'),
                HWBool('done'),
                HWDateTime('at'),
                HWTimedData(HWString('phase')),
                HWJson('user', HWString('name')),
                HWPayload('id', HWJson('user', HWInt('id'))),
                HWPayload('step', HWInt.fixed(7)),
                HWPayload('since', HWDateTime.fixed('2026-09-22T10:00:00Z')),
                HWPayload('half', HWDouble.fixed(0.5)),
              ],
            ),
            _button('reset'),
          ],
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('needs a function to call', () {
      final spec = _spec(
        HWColumn(children: [_button('increment'), _button('reset')]),
        handler: null,
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            startsWith(
              "Widget \"Counter\": HWButton('increment') has no function to "
              'call.',
            ),
            contains('Set onInteraction on the @HomeWidget annotation'),
            contains('taking a CounterInteraction.'),
          ),
        ),
      );
    });

    test('a function without a button to call it is warned about', () {
      final spec = _spec(const HWColumn(children: [_label]));

      expect(() => validateWidgetData(spec), returnsNormally);
      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single as String;
      expect(
        message,
        startsWith(
          'Warning: Widget "Counter" sets onInteraction, but has no HWButton '
          'to call it.',
        ),
      );
      expect(message, contains('or remove onInteraction'));
    });

    test('a widget without buttons and without a function is silent', () {
      final spec = _spec(const HWColumn(children: [_label]), handler: null);

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('needs an id that names a class', () {
      for (final id in ['', '1x', 'my-button', 'my button', 'über']) {
        expect(
          () => validateWidgetData(_spec(_button(id))),
          _throwsMessage(
            allOf(
              contains('Widget "Counter": invalid HWButton id "$id"'),
              contains('names the generated interaction class'),
              contains('ASCII letters and digits'),
            ),
          ),
          reason: id,
        );
      }
    });
  });

  group('button payloads', () {
    test('cannot send a fixed value without a name', () {
      final spec = _spec(_button('add', data: const [HWInt.fixed(7)]));

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            startsWith(
              "Widget \"Counter\": HWButton('add') sends HWInt.fixed(7), "
              'which has no name',
            ),
            contains('HWPayload("name", HWInt.fixed(7))'),
          ),
        ),
      );
    });

    test('cannot send an image, an icon or a localized string', () {
      expect(
        () => validateWidgetData(
          _spec(_button('add', data: const [HWImageData('avatar')])),
        ),
        _throwsMessage(
          allOf(
            contains("HWButton('add') cannot send an image"),
            contains('runtime image "avatar"'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            _button(
              'add',
              data: const [
                HWIconData.resolved(
                  'mood',
                  entries: [HWIconEntry('happy', 0xE88A)],
                  iconFont: HWIconFont(family: 'MaterialIcons'),
                ),
              ],
            ),
          ),
        ),
        _throwsMessage(
          contains("HWButton('add') cannot send the icon \"mood\""),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            _button(
              'add',
              data: const [
                HWLocalizedString(
                  'title',
                  defaultTranslations: {'en': 'Title'},
                ),
              ],
            ),
          ),
        ),
        _throwsMessage(
          contains(
            "HWButton('add') cannot send the localized string \"title\"",
          ),
        ),
      );
    });

    test('send an item field inside the item of a builder', () {
      final spec = _spec(
        HWColumn.builder(
          'todos',
          maxItems: 3,
          item: _button(
            'toggle',
            data: const [
              HWItemData(HWString('id')),
              HWPayload('done', HWItemData(HWBool('checked'))),
            ],
            child: const HWText(HWItemData(HWString('title'))),
          ),
          whenEmpty: _button('add'),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('send an item field below the item of a builder', () {
      final spec = _spec(
        HWColumn.builder(
          'todos',
          maxItems: 3,
          item: HWRow(
            children: [
              const HWText(HWItemData(HWString('title'))),
              _button('toggle', data: const [HWItemData(HWString('id'))]),
            ],
          ),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('cannot send an item field outside a builder', () {
      final spec = _spec(
        HWColumn(
          children: [
            _button('toggle', data: const [HWItemData(HWString('id'))]),
          ],
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains("HWButton('toggle') sends HWItemData(HWString('id'))"),
            contains('There is no item here'),
            contains('only works inside the item'),
          ),
        ),
      );
    });

    test('cannot send an item field from the whenEmpty of a builder', () {
      final spec = _spec(
        HWColumn.builder(
          'todos',
          item: const HWText(HWItemData(HWString('title'))),
          whenEmpty: _button('add', data: const [HWItemData(HWString('id'))]),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(contains("HWButton('add') sends HWItemData")),
      );
    });

    test('cannot use a name the generated class already has', () {
      for (final name in const [
        'fromUri',
        'hashCode',
        'noSuchMethod',
        'runtimeType',
        'toString',
        'toUri',
      ]) {
        expect(
          () => validateWidgetData(
            _spec(_button('add', data: [HWString(name)])),
          ),
          _throwsMessage(
            allOf(
              contains('Invalid data name "$name"'),
              contains("payload name of Widget \"Counter\": HWButton('add')"),
              contains('already has a member named "$name"'),
            ),
          ),
          reason: name,
        );
      }
    });

    test('cannot use the marker of a tap as a name', () {
      final spec = _spec(
        _button('add', data: const [HWString(HWPayloadUrl.marker)]),
      );

      expect(HWPayloadUrl.marker, 'homeWidget');
      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains('Invalid data name "homeWidget"'),
            contains('the query parameter marking a tap on a widget'),
          ),
        ),
      );
    });

    test('cannot use a name that is no identifier', () {
      final spec = _spec(
        _button('add', data: const [HWPayload('my-step', HWInt.fixed(1))]),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains('"my-step"'),
            contains("payload name of Widget \"Counter\": HWButton('add')"),
          ),
        ),
      );
    });

    test('cannot send two values of one name', () {
      final spec = _spec(
        _button(
          'add',
          data: const [HWInt('step'), HWPayload('step', HWInt.fixed(2))],
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            startsWith(
              "Widget \"Counter\": HWButton('add') sends two values named "
              '"step"',
            ),
            contains('HWPayload("other", ...)'),
          ),
        ),
      );
    });
  });

  group('button ids', () {
    const families = [
      HWWidgetFamily.systemMedium,
      HWWidgetFamily.systemLarge,
    ];

    test('are unique within a layout', () {
      final spec = _spec(
        HWColumn(children: [_button('add'), _button('add')]),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            startsWith(
              "Widget \"Counter\": HWButton('add') is declared twice. A "
              'button id',
            ),
            contains('A button id is unique within a widget'),
            contains('one of them renders at a time'),
          ),
        ),
      );
    });

    test('cannot differ only in the case of their first letter', () {
      final spec = _spec(
        HWColumn(children: [_button('increment'), _button('Increment')]),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains(
              "HWButton('increment') and HWButton('Increment') both generate "
              'CounterIncrementInteraction.',
            ),
            contains('unique within a widget'),
          ),
        ),
      );
    });

    test('may repeat across the slots of an HWSizeAdaptive', () {
      final spec = _spec(
        HWSizeAdaptive(
          medium: HWRow(children: [_button('add')]),
          large: HWColumn(children: [_button('add'), _button('reset')]),
        ),
        families: families,
        android: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      expect(
        spec.interactionTargets.map((target) => target.className),
        ['CounterAddInteraction', 'CounterResetInteraction'],
      );
    });

    test('may repeat across the branches of a conditional', () {
      final spec = _spec(
        HWBoolConditional(
          data: const HWBool('compact', defaultValue: false),
          whenTrue: _button('add', data: const [HWInt('step')]),
          whenFalse: HWColumn(
            children: [
              _button('add', data: const [HWPayload('step', HWInt('size'))]),
            ],
          ),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('may repeat across the branches of an HWDataExists', () {
      final spec = _spec(
        HWDataExists(
          data: const HWString('city'),
          whenPresent: _button('add'),
          whenAbsent: HWRow(children: [_button('add')]),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('may repeat across the sides of an HWAdaptive', () {
      final spec = _spec(
        HWAdaptive(
          ios: _button('add'),
          android: HWColumn(children: [_button('add')]),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('may repeat across the item and the whenEmpty of a builder', () {
      final spec = _spec(
        HWColumn.builder(
          'todos',
          maxItems: 3,
          item: _button('add', child: const HWText(HWItemData(HWString('t')))),
          whenEmpty: _button('add'),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('one button written into two slots is one button', () {
      final shared = _button('add');
      final spec = _spec(
        HWSizeAdaptive(medium: shared, large: shared),
        families: families,
        android: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('cannot repeat inside one branch of a conditional', () {
      final spec = _spec(
        HWBoolConditional(
          data: const HWBool('compact', defaultValue: false),
          whenTrue: HWColumn(children: [_button('add'), _button('add')]),
          whenFalse: _button('add'),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains("HWButton('add') is declared twice"),
            contains('unique within a widget'),
          ),
        ),
      );
    });

    test('must send the same data across the slots of an HWSizeAdaptive', () {
      final spec = _spec(
        HWSizeAdaptive(
          medium: _button('add', data: const [HWInt('step')]),
          large: _button('add'),
        ),
        families: families,
        android: false,
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            startsWith(
              "Widget \"Counter\": HWButton('add') is declared twice, but "
              'with different data.',
            ),
            contains('the same interaction class'),
          ),
        ),
      );
    });

    test('must send data of the same shape where they repeat', () {
      WidgetSpec repeating(
        List<HWDataType<dynamic>> first,
        List<HWDataType<dynamic>> second, {
        String secondId = 'add',
      }) =>
          _spec(
            HWBoolConditional(
              data: const HWBool('compact', defaultValue: false),
              whenTrue: _button('add', data: first),
              whenFalse: _button(secondId, data: second),
            ),
          );

      const cases = <(List<HWDataType<dynamic>>, List<HWDataType<dynamic>>)>[
        ([HWInt('step')], []),
        ([HWInt('step')], [HWInt('size')]),
        ([HWInt('step')], [HWPayload('step', HWString('city'))]),
        ([HWInt('step')], [HWInt('step', defaultValue: 1)]),
      ];
      for (final (first, second) in cases) {
        expect(
          () => validateWidgetData(repeating(first, second)),
          _throwsMessage(contains('but with different data')),
          reason: '$first / $second',
        );
      }

      expect(
        () => validateWidgetData(
          repeating(const [HWInt('step')], const [], secondId: 'Add'),
        ),
        _throwsMessage(
          contains(
            "HWButton('add') and HWButton('Add') both generate "
            'CounterAddInteraction, but with different data.',
          ),
        ),
      );
    });

    test('may share an id with a link', () {
      final spec = _spec(
        HWColumn(children: [_button('open'), _link('open')]),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });
  });

  group('nesting', () {
    test('a button cannot sit inside another button', () {
      final spec = _spec(
        _button(
          'outer',
          child: HWColumn(children: [_button('inner')]),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          equals(
            "Widget \"Counter\": HWButton('inner') sits inside "
            "HWButton('outer'). A tap runs one interaction, so a button "
            'cannot contain another one.',
          ),
        ),
      );
    });

    test('a link cannot sit inside a button', () {
      final spec = _spec(
        _button(
          'outer',
          child: HWColumn(children: [_link('inner')]),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          equals(
            "Widget \"Counter\": HWLink('inner') sits inside "
            "HWButton('outer'). A tap either opens the app or runs Dart code "
            'without opening it, so a link and a button cannot contain each '
            'other.',
          ),
        ),
      );
    });

    test('a button cannot sit inside a link', () {
      final spec = _spec(
        _link(
          'outer',
          child: HWBoolConditional(
            data: const HWBool('compact', defaultValue: false),
            whenTrue: _label,
            whenFalse: _button('inner'),
          ),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          equals(
            "Widget \"Counter\": HWButton('inner') sits inside "
            "HWLink('outer'). A tap either opens the app or runs Dart code "
            'without opening it, so a link and a button cannot contain each '
            'other.',
          ),
        ),
      );
    });

    test('a link inside another link keeps its own message', () {
      final spec = _spec(
        _link(
          'outer',
          child: HWColumn(children: [_link('inner')]),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          equals(
            "Widget \"Counter\": HWLink('inner') sits inside "
            "HWLink('outer'). A tap opens one URL, so a link cannot contain "
            'another one.',
          ),
        ),
      );
    });
  });

  group('buttons are found', () {
    test('in the item and the whenEmpty of a builder', () {
      for (final tree in [
        HWColumn.builder(
          'todos',
          maxItems: 3,
          item: _button(
            '1x',
            child: const HWText(HWItemData(HWString('title'))),
          ),
          whenEmpty: _label,
        ),
        HWRow.builder(
          'todos',
          maxItems: 3,
          item: const HWText(HWItemData(HWString('title'))),
          whenEmpty: HWColumn(children: [_button('1x')]),
        ),
      ]) {
        expect(
          () => validateWidgetData(_spec(tree)),
          _throwsMessage(contains('invalid HWButton id "1x"')),
        );
      }
    });

    test('on both sides of an HWAdaptive', () {
      for (final tree in [
        HWAdaptive(ios: _button('1x'), android: _label),
        HWAdaptive(ios: _label, android: HWRow(children: [_button('1x')])),
      ]) {
        expect(
          () => validateWidgetData(_spec(tree)),
          _throwsMessage(contains('invalid HWButton id "1x"')),
        );
      }
    });

    test('in both branches of a conditional', () {
      const data = HWBool('compact', defaultValue: false);
      for (final tree in [
        HWBoolConditional(
          data: data,
          whenTrue: _button('1x'),
          whenFalse: _label,
        ),
        HWBoolConditional(
          data: data,
          whenTrue: _label,
          whenFalse: _button('1x'),
        ),
        HWDataExists(
          data: const HWString('city'),
          whenPresent: _label,
          whenAbsent: _button('1x'),
        ),
      ]) {
        expect(
          () => validateWidgetData(_spec(tree)),
          _throwsMessage(contains('invalid HWButton id "1x"')),
        );
      }
    });

    test('in every slot of an HWSizeAdaptive', () {
      for (final tree in [
        HWSizeAdaptive(medium: _button('1x'), large: _label),
        HWSizeAdaptive(medium: _label, large: _button('1x')),
      ]) {
        expect(
          () => validateWidgetData(
            _spec(
              tree,
              families: const [
                HWWidgetFamily.systemMedium,
                HWWidgetFamily.systemLarge,
              ],
              android: false,
            ),
          ),
          _throwsMessage(contains('invalid HWButton id "1x"')),
        );
      }
    });

    test('below a link next to them', () {
      final spec = _spec(
        HWColumn(
          children: [
            _link('open'),
            HWPadding(padding: const HWEdgeInsets.all(4), child: _button('1x')),
          ],
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(contains('invalid HWButton id "1x"')),
      );
    });
  });

  group('accessoryInline', () {
    const inline = [
      HWWidgetFamily.systemMedium,
      HWWidgetFamily.accessoryInline,
    ];

    test('a button the inline accessory renders is warned about', () {
      final spec = _spec(
        HWAdaptive(
          ios: HWRow(children: [_button('add')]),
          android: HWRow(children: [_button('reset')]),
        ),
        families: inline,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single as String;
      expect(
        message,
        startsWith(
          'Warning: Widget "Counter" can be shown as accessoryInline on iOS, '
          "which shows text only: HWButton('add') cannot be tapped there",
        ),
      );
      expect(message, isNot(contains('reset')));
      expect(message, contains('Android is not affected'));
      expect(message, contains('HWSizeAdaptive slot of another family'));
    });

    test('names every button the inline accessory renders once', () {
      final spec = _spec(
        HWBoolConditional(
          data: const HWBool('compact', defaultValue: false),
          whenTrue: _button('add'),
          whenFalse: HWRow(children: [_button('add'), _button('reset')]),
        ),
        families: inline,
        android: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single as String;
      expect(
        message,
        contains("text only: HWButton('add'), HWButton('reset') cannot be"),
      );
    });

    test('a button only another family renders is not warned about', () {
      final spec = _spec(
        HWSizeAdaptive(
          medium: HWRow(children: [_button('add')]),
          accessoryInline: _label,
        ),
        families: inline,
        android: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('a widget never shown inline is not warned about', () {
      for (final families in const [
        null,
        [HWWidgetFamily.systemSmall, HWWidgetFamily.accessoryRectangular],
      ]) {
        final spec = _spec(_button('add'), families: families, android: false);

        expect(() => validateWidgetData(spec), returnsNormally);
      }
      verifyNever(() => mockLogger.warn(any()));
    });

    test('a widget without iOS is not warned about', () {
      final spec = _spec(_button('add'), iOS: false);

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });
  });
}
