import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

const _label = HWText(HWString.fixed('label'));

HWLink _link(
  String id, {
  String? url,
  List<HWDataType<dynamic>> data = const [],
  HWWidget child = _label,
}) =>
    HWLink(id, url: url ?? 'myapp://$id', data: data, child: child);

/// A spec rendering [tree], whose data fields are what the tree reads, the
/// way the schema parser builds one.
WidgetSpec _spec(
  HWWidget tree, {
  String? widgetUrl,
  List<HWDataType<dynamic>> widgetUrlData = const [],
  List<HWWidgetFamily>? families = const [HWWidgetFamily.systemMedium],
  bool android = true,
  bool iOS = true,
  bool openAppOnTap = true,
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Weather',
        widgetUrl: widgetUrl,
        widgetUrlData: widgetUrlData,
        android: android
            ? HomeWidgetAndroidConfiguration(openAppOnTap: openAppOnTap)
            : null,
        iOS: iOS
            ? HomeWidgetIOSConfiguration(
                groupId: 'group.weather',
                supportedFamilies: families,
              )
            : null,
      ),
      className: 'Weather',
      dataFields: [
        ...tree.dataDependencies,
        for (final entry in HWPayloadEntry.listOf(widgetUrlData))
          if (entry.value.isDataDependency) entry.value,
      ],
      widgetTree: tree,
    );

Matcher _throwsMessage(Matcher message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = useMockLogger();
  });

  group('widgetUrlData', () {
    test('is accepted next to a widgetUrl', () {
      final spec = _spec(
        _label,
        widgetUrl: 'myapp://weather',
        widgetUrlData: const [
          HWString('city'),
          HWPayload('days', HWInt.fixed(7)),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('is rejected without a widgetUrl', () {
      final spec = _spec(_label, widgetUrlData: const [HWString('city')]);

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains('Widget "Weather"'),
            contains('widgetUrlData is set without a widgetUrl'),
          ),
        ),
      );
    });

    test('cannot read the item of a builder', () {
      final spec = _spec(
        _label,
        widgetUrl: 'myapp://weather',
        widgetUrlData: const [HWItemData(HWString('id'))],
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains('widgetUrlData sends HWItemData(HWString(\'id\'))'),
            contains('There is no item here'),
          ),
        ),
      );
    });

    test('cannot use a query parameter of the widgetUrl as a name', () {
      final spec = _spec(
        _label,
        widgetUrl: 'myapp://weather?city=1',
        widgetUrlData: const [HWString('city')],
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          contains(
            'already a query parameter of the URL "myapp://weather?city=1"',
          ),
        ),
      );
    });
  });

  group('HWLink', () {
    test('is accepted with a payload of every type', () {
      final spec = _spec(
        HWColumn(
          children: [
            _link(
              'forecast',
              data: const [
                HWString('city'),
                HWInt('count', defaultValue: 1),
                HWDouble('ratio'),
                HWBool('done'),
                HWDateTime('at'),
                HWTimedData(HWString('phase')),
                HWJson('user', HWString('name')),
                HWPayload('id', HWJson('user', HWInt('id'))),
                HWPayload('days', HWInt.fixed(7)),
                HWPayload('since', HWDateTime.fixed('2026-09-22T10:00:00Z')),
                HWPayload('half', HWDouble.fixed(0.5)),
              ],
            ),
          ],
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('sends an item field inside the item of a builder', () {
      final spec = _spec(
        HWColumn.builder(
          'todos',
          maxItems: 3,
          item: _link(
            'open',
            data: const [
              HWItemData(HWString('id')),
              HWPayload('done', HWItemData(HWBool('checked'))),
            ],
            child: const HWText(HWItemData(HWString('title'))),
          ),
          whenEmpty: _link('add'),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('cannot send an item field outside a builder', () {
      final spec = _spec(
        HWColumn(
          children: [
            _link('open', data: const [HWItemData(HWString('id'))]),
          ],
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains("HWLink('open') sends HWItemData(HWString('id'))"),
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
          whenEmpty: _link('add', data: const [HWItemData(HWString('id'))]),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(contains("HWLink('add') sends HWItemData")),
      );
    });

    test('needs an id that names a class', () {
      for (final id in ['', '1st', 'my-link', 'my link', 'über']) {
        expect(
          () => validateWidgetData(_spec(_link(id, url: 'myapp://x'))),
          _throwsMessage(
            allOf(
              contains('invalid HWLink id "$id"'),
              contains('ASCII letters and digits'),
            ),
          ),
          reason: id,
        );
      }
    });

    test('needs an absolute URL', () {
      expect(
        () => validateWidgetData(_spec(_link('open', url: ' '))),
        _throwsMessage(contains("HWLink('open') url is empty")),
      );
      expect(
        () => validateWidgetData(_spec(_link('open', url: '/details'))),
        _throwsMessage(
          allOf(
            contains("HWLink('open') url \"/details\" is not a valid URL"),
            contains('myapp://details'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(_spec(_link('open', url: 'http://[::1'))),
        _throwsMessage(contains('is not a valid URL')),
      );
    });

    test('cannot sit inside another link', () {
      final spec = _spec(
        _link(
          'outer',
          child: HWColumn(children: [_link('inner')]),
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          contains("HWLink('inner') sits inside HWLink('outer')"),
        ),
      );
    });
  });

  group('link ids', () {
    test('are unique within a layout', () {
      final spec = _spec(
        HWColumn(children: [_link('open'), _link('open')]),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains("HWLink('open') is declared twice"),
            contains('unique within a widget'),
          ),
        ),
      );
    });

    test('cannot differ only in the case of their first letter', () {
      final spec = _spec(
        HWColumn(children: [_link('open'), _link('Open')]),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          contains(
            "HWLink('open') and HWLink('Open') both generate "
            'WeatherOpenLink',
          ),
        ),
      );
    });

    test('may repeat across the slots of an HWSizeAdaptive', () {
      final spec = _spec(
        HWSizeAdaptive(
          medium: HWRow(children: [_link('open')]),
          large: HWColumn(children: [_link('open'), _link('more')]),
        ),
        families: const [
          HWWidgetFamily.systemMedium,
          HWWidgetFamily.systemLarge,
        ],
        android: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      expect(
        spec.launchTargets.map((target) => target.className),
        ['WeatherOpenLink', 'WeatherMoreLink'],
      );
    });

    test('may repeat across the branches of a conditional', () {
      final spec = _spec(
        HWBoolConditional(
          data: const HWBool('compact', defaultValue: false),
          whenTrue: _link('open', data: const [HWString('city')]),
          whenFalse: HWColumn(
            children: [
              _link('open', data: const [HWPayload('city', HWString('town'))]),
            ],
          ),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('may repeat across the sides of an HWAdaptive', () {
      final spec = _spec(
        HWAdaptive(
          ios: _link('open'),
          android: HWColumn(children: [_link('open')]),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('may repeat across the item and the whenEmpty of a builder', () {
      final spec = _spec(
        HWColumn.builder(
          'todos',
          maxItems: 3,
          item: _link('open', child: const HWText(HWItemData(HWString('t')))),
          whenEmpty: _link('open'),
        ),
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('one link written into two slots is one link', () {
      final shared = _link('open');
      final spec = _spec(
        HWSizeAdaptive(medium: shared, large: shared),
        families: const [
          HWWidgetFamily.systemMedium,
          HWWidgetFamily.systemLarge,
        ],
        android: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('must open the same URL where they repeat', () {
      final spec = _spec(
        HWSizeAdaptive(
          medium: _link('open', url: 'myapp://a'),
          large: _link('open', url: 'myapp://b'),
        ),
        families: const [
          HWWidgetFamily.systemMedium,
          HWWidgetFamily.systemLarge,
        ],
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains("HWLink('open') is declared twice"),
            contains('with a different url or data'),
          ),
        ),
      );
    });

    test('must send data of the same shape where they repeat', () {
      WidgetSpec repeating(
        List<HWDataType<dynamic>> first,
        List<HWDataType<dynamic>> second,
      ) =>
          _spec(
            HWBoolConditional(
              data: const HWBool('compact', defaultValue: false),
              whenTrue: _link('open', data: first),
              whenFalse: _link('open', data: second),
            ),
          );

      const cases = <(List<HWDataType<dynamic>>, List<HWDataType<dynamic>>)>[
        ([HWString('city')], []),
        ([HWString('city')], [HWString('town')]),
        ([HWString('city')], [HWPayload('city', HWInt('count'))]),
        ([HWInt('count')], [HWInt('count', defaultValue: 1)]),
      ];
      for (final (first, second) in cases) {
        expect(
          () => validateWidgetData(repeating(first, second)),
          _throwsMessage(contains('with a different url or data')),
          reason: '$first / $second',
        );
      }
    });
  });

  group('launch URLs', () {
    test('of two links must be told apart', () {
      final spec = _spec(
        HWColumn(
          children: [
            _link('first', url: 'myapp://open'),
            _link('second', url: 'myApp://open?tab=1'),
          ],
        ),
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains('WeatherFirstLink ("myapp://open")'),
            contains('WeatherSecondLink ("myApp://open?tab=1")'),
            contains('cannot tell apart'),
          ),
        ),
      );
    });

    test('of a link and the widget must be told apart', () {
      final spec = _spec(
        _link('open', url: 'myapp://weather'),
        widgetUrl: 'myapp://weather',
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains('WeatherWidgetTap ("myapp://weather")'),
            contains('WeatherOpenLink ("myapp://weather")'),
          ),
        ),
      );
    });

    test('differing in a static query parameter are told apart', () {
      final spec = _spec(
        HWColumn(
          children: [
            _link('first', url: 'myapp://open?tab=1'),
            _link('second', url: 'myapp://open?tab=2'),
          ],
        ),
        widgetUrl: 'myapp://weather',
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });
  });

  group('tap areas', () {
    test('a link in a layout a small widget shows is warned about', () {
      final spec = _spec(
        HWColumn(children: [_link('open'), _link('more')]),
        families: null,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single as String;
      expect(message, contains('Widget "Weather"'));
      expect(message, contains('systemSmall'));
      expect(message, contains("HWLink('open'), HWLink('more')"));
      expect(message, contains('without a URL'));
    });

    test('the warning names widgetUrl as what opens instead', () {
      final spec = _spec(
        HWColumn(children: [_link('open')]),
        widgetUrl: 'myapp://weather',
        families: const [
          HWWidgetFamily.systemSmall,
          HWWidgetFamily.accessoryInline,
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single as String;
      expect(message, contains('systemSmall, accessoryInline'));
      expect(message, contains('through widgetUrl'));
    });

    test('a link that is the whole small layout is not warned about', () {
      final spec = _spec(_link('open'), families: null);

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('a link that is the whole small layout cannot join a widgetUrl', () {
      final spec = _spec(
        _link('open'),
        widgetUrl: 'myapp://weather',
        families: null,
      );

      expect(
        () => validateWidgetData(spec),
        _throwsMessage(
          allOf(
            contains("HWLink('open') is the whole layout"),
            contains('remove widgetUrl'),
          ),
        ),
      );
    });

    test('a root link of a widget without iOS joins a widgetUrl', () {
      final spec = _spec(
        _link('open'),
        widgetUrl: 'myapp://weather',
        families: null,
        iOS: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('links are warned about where Android opens nothing', () {
      final spec = _spec(
        HWColumn(children: [_link('open')]),
        openAppOnTap: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('android.openAppOnTap to false'),
              contains('open nothing on Android'),
            ),
          ),
        ),
      ).called(1);
    });

    test('a widget without links is never warned about', () {
      final spec = _spec(
        _label,
        widgetUrl: 'myapp://weather',
        families: null,
        openAppOnTap: false,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });
  });

  group('validatePayload', () {
    void validate(
      List<HWDataType<dynamic>> data, {
      bool inItem = false,
      Map<String, String> reserved = const {},
    }) =>
        validatePayload(
          HWPayloadEntry.listOf(data),
          owner: 'HWButton("rate")',
          inItem: inItem,
          reserved: reserved,
        );

    test('accepts an empty payload', () {
      expect(() => validate(const []), returnsNormally);
    });

    test('rejects an image, an icon and a localized string', () {
      expect(
        () => validate(const [HWImageData('avatar')]),
        _throwsMessage(
          allOf(
            contains('HWButton("rate") cannot send an image'),
            contains('runtime image "avatar"'),
          ),
        ),
      );
      expect(
        () => validate(const [
          HWPayload('logo', HWImageData.asset('assets/logo.png')),
        ]),
        _throwsMessage(contains('asset "assets/logo.png"')),
      );
      expect(
        () => validate(const [
          HWIconData.resolved(
            'mood',
            entries: [HWIconEntry('happy', 0xE88A)],
            iconFont: HWIconFont(family: 'MaterialIcons'),
          ),
        ]),
        _throwsMessage(contains('cannot send the icon "mood"')),
      );
      expect(
        () => validate(const [
          HWLocalizedString('title', defaultTranslations: {'en': 'Title'}),
        ]),
        _throwsMessage(contains('cannot send the localized string "title"')),
      );
      expect(
        () => validate(const [
          HWPayload('title', HWString.localizedFixed({'en': 'Title'})),
        ]),
        _throwsMessage(contains('the localized string "title"')),
      );
    });

    test('rejects a fixed value without a name', () {
      expect(
        () => validate(const [HWInt.fixed(7)]),
        _throwsMessage(
          allOf(
            contains('sends HWInt.fixed(7), which has no name'),
            contains('HWPayload("name", HWInt.fixed(7))'),
          ),
        ),
      );
    });

    test('accepts an item field only inside an item', () {
      const data = [HWTimedData(HWItemData(HWString('id')))];

      expect(() => validate(data, inItem: true), returnsNormally);
      expect(
        () => validate(data),
        _throwsMessage(
          contains("sends HWTimedData(HWItemData(HWString('id')))"),
        ),
      );
    });

    test('rejects a fixed number that is not finite', () {
      expect(
        () => validate(const [HWPayload('x', HWDouble.fixed(double.nan))]),
        _throwsMessage(contains('HWDouble.fixed(NaN) is not a finite number')),
      );
    });

    test('rejects a fixed date that names no instant', () {
      expect(
        () => validate(const [HWPayload('at', HWDateTime.fixed('tomorrow'))]),
        _throwsMessage(contains('is not an ISO 8601 date')),
      );
      expect(
        () => validate(const [
          HWPayload('at', HWDateTime.fixed('2026-09-22T10:00:00')),
        ]),
        _throwsMessage(contains('names no time zone')),
      );
    });

    test('rejects a name the generated class cannot carry', () {
      expect(
        () => validate(const [HWPayload('my-name', HWString('city'))]),
        _throwsMessage(
          allOf(
            contains('Invalid data name "my-name"'),
            contains('payload name of HWButton("rate")'),
          ),
        ),
      );
      expect(
        () => validate(const [HWPayload('class', HWString('city'))]),
        _throwsMessage(contains('reserved keyword')),
      );
      for (final name in const ['toUri', 'fromUri', 'hashCode', 'toString']) {
        expect(
          () => validate([HWPayload(name, const HWString('city'))]),
          _throwsMessage(
            allOf(
              contains('already has a member named "$name"'),
              contains('HWPayload("other", ...)'),
            ),
          ),
          reason: name,
        );
      }
    });

    test('rejects a reserved name with its reason', () {
      expect(
        () => validate(
          const [HWString('homeWidget')],
          reserved: const {'homeWidget': 'taken by the plugin'},
        ),
        _throwsMessage(
          contains('Invalid data name "homeWidget" (payload name of '
              'HWButton("rate")): it is taken by the plugin.'),
        ),
      );
    });

    test('rejects two entries of one name, also through a JSON leaf', () {
      expect(
        () => validate(const [
          HWString('name'),
          HWJson('user', HWString('name')),
        ]),
        _throwsMessage(
          allOf(
            contains('sends two values named "name"'),
            contains('HWPayload("other", ...)'),
          ),
        ),
      );
      expect(
        () => validate(const [
          HWString('name'),
          HWPayload('userName', HWJson('user', HWString('name'))),
        ]),
        returnsNormally,
      );
    });
  });

  test('a link reserves the marker as a payload name', () {
    final spec = _spec(
      _link('open', data: const [HWString('homeWidget')]),
    );

    expect(
      () => validateWidgetData(spec),
      _throwsMessage(
        contains('it is the query parameter marking a tap on a widget'),
      ),
    );
  });
}
