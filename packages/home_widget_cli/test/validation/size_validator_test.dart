import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/validation/size_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

const _iosDefault = HomeWidgetIOSConfiguration(groupId: 'group.test');
const _androidDefault = HomeWidgetAndroidConfiguration();

WidgetSpec _spec(
  HWWidget tree, {
  HomeWidgetIOSConfiguration? iOS = _iosDefault,
  HomeWidgetAndroidConfiguration? android,
}) =>
    WidgetSpec(
      data: HomeWidget(name: 'Adaptive', iOS: iOS, android: android),
      className: 'Adaptive',
      widgetTree: tree,
    );

Matcher _errorWith(Matcher message) =>
    isA<GeneratorError>().having((e) => e.message, 'message', message);

const _s = HWText.fixed('s');
const _m = HWText.fixed('m');
const _l = HWText.fixed('l');
const _wide = HWText.fixed('wide');
const _tall = HWText.fixed('tall');
const _strip = HWText.fixed('strip');
const _dashboard = HWText.fixed('dashboard');

const _stripRange = HWAndroidSizeRange(maxHeight: 120, child: _strip);
const _dashboardRange = HWAndroidSizeRange(
  minWidth: 400,
  minHeight: 200,
  child: _dashboard,
);

/// The §4.4 widget: three slots, a strip for every one-row widget and a
/// dashboard for tablets.
const _example = HWSizeAdaptive(
  small: _s,
  medium: _m,
  large: _l,
  androidSizeRanges: [_stripRange, _dashboardRange],
);

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.warn(any())).thenReturn(null);
  });

  tearDown(() {
    logger = Logger();
  });

  group('androidSizes', () {
    test('rejects an accessory key even without an Android widget', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          androidSizes: const {
            HWWidgetFamily.accessoryCircular: HWSize(100, 100),
          },
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              contains('accessoryCircular'),
              contains('Android has no accessory families'),
            ),
          ),
        ),
      );
    });

    test('rejects a size without a positive extent', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          androidSizes: const {HWWidgetFamily.systemMedium: HWSize(0, 110)},
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              contains('systemMedium HWSize(0, 110)'),
              contains('greater than 0'),
            ),
          ),
        ),
      );
    });

    test('rejects two instances overriding one family differently', () {
      final spec = _spec(
        HWColumn(
          children: [
            HWSizeAdaptive(
              small: HWText.fixed('s'),
              androidSizes: const {
                HWWidgetFamily.systemMedium: HWSize(200, 100),
              },
            ),
            HWSizeAdaptive(
              small: HWText.fixed('s2'),
              androidSizes: const {
                HWWidgetFamily.systemMedium: HWSize(220, 100),
              },
            ),
          ],
        ),
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              contains('systemMedium different androidSizes'),
              contains('HWSize(200, 100) and HWSize(220, 100)'),
              contains('sizeMode is declared once per widget'),
            ),
          ),
        ),
      );
    });

    test('accepts the same override written twice', () {
      final spec = _spec(
        HWColumn(
          children: [
            HWSizeAdaptive(
              small: HWText.fixed('s'),
              androidSizes: const {
                HWWidgetFamily.systemMedium: HWSize(200, 100),
              },
            ),
            HWSizeAdaptive(
              small: HWText.fixed('s2'),
              androidSizes: const {
                HWWidgetFamily.systemMedium: HWSize(200, 100),
              },
            ),
          ],
        ),
        android: _androidDefault,
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('rejects a conflict without an Android widget', () {
      final spec = _spec(
        HWColumn(
          children: [
            HWSizeAdaptive(
              small: HWText.fixed('s'),
              androidSizes: const {
                HWWidgetFamily.systemMedium: HWSize(200, 100),
              },
            ),
            HWSizeAdaptive(
              small: HWText.fixed('s2'),
              androidSizes: const {
                HWWidgetFamily.systemMedium: HWSize(220, 100),
              },
            ),
          ],
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(_errorWith(contains('systemMedium different androidSizes'))),
      );
    });

    test('leaves the table checks alone without an Android widget', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          androidSizes: const {HWWidgetFamily.systemMedium: HWSize(110, 110)},
        ),
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('rejects two families resolving to one dp size', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          androidSizes: const {HWWidgetFamily.systemMedium: HWSize(110, 110)},
        ),
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              contains('systemSmall and systemMedium both declare '
                  'HWSize(110, 110)'),
              contains('Glance cannot tell two identical sizes apart'),
            ),
          ),
        ),
      );
    });

    test('warns about a family an override made smaller than its fallback', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          medium: HWText.fixed('m'),
          large: HWText.fixed('l'),
          androidSizes: const {HWWidgetFamily.systemLarge: HWSize(200, 100)},
        ),
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('systemLarge (HWSize(200, 100)) smaller than its '
                  'fallback systemMedium (HWSize(250, 110))'),
              contains('rendered in a smaller box'),
            ),
          ),
        ),
      ).called(1);
    });

    test('the default table satisfies every fallback chain', () {
      final spec = _spec(
        HWSizeAdaptive(small: HWText.fixed('s')),
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verifyNever(() => mockLogger.warn(any(that: contains('fallback'))));
    });
  });

  group('missing content', () {
    test('names the family, the widget and the platform', () {
      final spec = _spec(
        HWSizeAdaptive(accessoryCircular: HWText.fixed('c')),
        iOS: const HomeWidgetIOSConfiguration(
          groupId: 'group.test',
          supportedFamilies: [
            HWWidgetFamily.systemExtraLargePortrait,
            HWWidgetFamily.accessoryCircular,
          ],
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            equals(
              'HWSizeAdaptive has no content for systemExtraLargePortrait, '
              'which "Adaptive" supports on iOS. Add an `extraLargePortrait` '
              'slot or one of its fallbacks (`large`, `medium`, `small`).',
            ),
          ),
        ),
      );
    });

    test('an accessory family names only its own slot', () {
      final spec = _spec(
        HWSizeAdaptive(small: HWText.fixed('s')),
        iOS: const HomeWidgetIOSConfiguration(
          groupId: 'group.test',
          supportedFamilies: [
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.accessoryInline,
          ],
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            equals(
              'HWSizeAdaptive has no content for accessoryInline, which '
              '"Adaptive" supports on iOS. Add an `accessoryInline` slot.',
            ),
          ),
        ),
      );
    });

    test('reports a family both platforms show, one paragraph each', () {
      final spec = _spec(
        HWSizeAdaptive(accessoryCircular: HWText.fixed('c')),
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              startsWith(
                'HWSizeAdaptive has no content for systemSmall, which '
                '"Adaptive" supports on iOS and Android. Add a `small` slot.',
              ),
              contains('systemExtraLargePortrait, which "Adaptive" supports '
                  'on Android.'),
            ),
          ),
        ),
      );
    });

    test('says nothing about a family no platform reaches', () {
      final spec = _spec(
        HWSizeAdaptive(small: HWText.fixed('s')),
        android: _androidDefault,
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('ignores a family the enclosing slot never renders', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          large: HWSizeAdaptive(large: HWText.fixed('l')),
        ),
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('names a family the nested instance does miss', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWSizeAdaptive(medium: HWText.fixed('m')),
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              contains('no content for systemSmall'),
              isNot(contains('systemLarge')),
            ),
          ),
        ),
      );
    });

    test('ignores an instance the platform does not emit', () {
      final spec = _spec(
        HWAdaptive(
          ios: HWText.fixed('i'),
          android: HWSizeAdaptive(accessoryCircular: HWText.fixed('c')),
        ),
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('collects every missing family of every instance in one error', () {
      final spec = _spec(
        HWColumn(
          children: [
            HWSizeAdaptive(small: HWText.fixed('s'), medium: HWText.fixed('m')),
            HWSizeAdaptive(accessoryInline: HWText.fixed('i')),
          ],
        ),
        iOS: const HomeWidgetIOSConfiguration(
          groupId: 'group.test',
          supportedFamilies: [
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.accessoryInline,
          ],
        ),
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            equals(
              'HWSizeAdaptive has no content for systemSmall, which "Adaptive" '
              'supports on iOS. Add a `small` slot.\n'
              'HWSizeAdaptive has no content for accessoryInline, which '
              '"Adaptive" supports on iOS. Add an `accessoryInline` slot.',
            ),
          ),
        ),
      );
    });
  });

  group('unreachable slots', () {
    test('names the family list on iOS and the dp cap on Android', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          extraLarge: HWText.fixed('xl'),
        ),
        android: const HomeWidgetAndroidConfiguration(
          targetCellWidth: 4,
          targetCellHeight: 2,
          resizeMode: HWAndroidResizeMode.none,
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: HWSizeAdaptive slot `extraLarge` in "Adaptive" is never '
          'rendered: iOS supports [systemSmall, systemMedium, systemLarge] and '
          'the Android configuration caps the widget at 250 × 110 dp.',
        ),
      ).called(1);
    });

    test('says so when the widget is not generated for Android', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          extraLarge: HWText.fixed('xl'),
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('slot `extraLarge`'),
              contains('and not generated for Android.'),
            ),
          ),
        ),
      ).called(1);
    });

    test('says so when the widget is not generated for iOS', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          large: HWText.fixed('l'),
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          targetCellWidth: 4,
          targetCellHeight: 2,
          resizeMode: HWAndroidResizeMode.none,
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('slot `large`'),
              contains('not generated for iOS and the Android configuration '
                  'caps the widget at 250 × 110 dp.'),
            ),
          ),
        ),
      ).called(1);
    });

    test('names the lower bound when the widget resizes without a maximum', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          large: HWText.fixed('l'),
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          minResizeWidth: 250,
          minResizeHeight: 250,
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('slot `small`'),
              contains('keeps the widget at 250 × 250 dp or larger.'),
            ),
          ),
        ),
      ).called(1);
    });

    test('an override that pushes a family out of range warns', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          medium: HWText.fixed('m'),
          androidSizes: const {HWWidgetFamily.systemMedium: HWSize(600, 600)},
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          targetCellWidth: 4,
          targetCellHeight: 2,
          resizeMode: HWAndroidResizeMode.none,
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(any(that: contains('slot `medium`'))),
      ).called(1);
    });

    test('names the enclosing slot of a nested instance', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          large: HWSizeAdaptive(
            large: HWText.fixed('l'),
            extraLarge: HWText.fixed('xl'),
          ),
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: HWSizeAdaptive slot `extraLarge` in "Adaptive" is never '
          'rendered: on iOS its enclosing `large` slot only renders for '
          '[systemLarge] and not generated for Android.',
        ),
      ).called(1);
    });

    test('says so for a platform that never renders the instance', () {
      final spec = _spec(
        HWAdaptive(
          ios: HWText.fixed('i'),
          android: HWSizeAdaptive(
            small: HWText.fixed('s'),
            extraLarge: HWText.fixed('xl'),
          ),
        ),
        android: const HomeWidgetAndroidConfiguration(
          targetCellWidth: 4,
          targetCellHeight: 2,
          resizeMode: HWAndroidResizeMode.none,
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('slot `extraLarge`'),
              contains('not rendered on iOS and the Android configuration '
                  'caps the widget at 250 × 110 dp.'),
            ),
          ),
        ),
      ).called(1);
    });

    test('an override that pulls a family into range does not', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          large: HWText.fixed('l'),
          androidSizes: const {HWWidgetFamily.systemLarge: HWSize(90, 90)},
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          maxResizeWidth: 100,
          maxResizeHeight: 100,
        ),
      );

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('slot `large`'))),
      );
    });
  });

  group('slot shapes', () {
    test('warns about an inline slot WidgetKit cannot render', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          accessoryInline: HWColumn(children: [HWText.fixed('a')]),
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains('the `accessoryInline` slot of HWSizeAdaptive is a '
                  'HWColumn'),
              contains('HWText, an HWImage, or an HWRow of those'),
            ),
          ),
        ),
      ).called(1);
    });

    test('accepts a row of text and images inline', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWText.fixed('s'),
          accessoryInline: HWRow(
            children: [
              HWText.fixed('a'),
              HWImage.asset('assets/icon.png'),
            ],
          ),
        ),
        iOS: const HomeWidgetIOSConfiguration(
          groupId: 'group.test',
          supportedFamilies: [
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.accessoryInline,
          ],
        ),
      );

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('accessoryInline'))),
      );
    });

    test('checks the item and whenEmpty of an inline builder', () {
      WidgetSpec inline(HWWidget item) => _spec(
            HWSizeAdaptive(
              small: HWText.fixed('s'),
              accessoryInline: HWRow.builder(
                'tags',
                maxItems: 3,
                item: item,
                whenEmpty: HWText.fixed('none'),
              ),
            ),
            iOS: const HomeWidgetIOSConfiguration(
              groupId: 'group.test',
              supportedFamilies: [
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.accessoryInline,
              ],
            ),
          );

      validateSizeAdaptive(inline(HWText(HWItemData(HWString('tag')))));
      verifyNever(
        () => mockLogger.warn(any(that: contains('accessoryInline'))),
      );

      validateSizeAdaptive(
        inline(HWColumn(children: [HWText(HWItemData(HWString('tag')))])),
      );
      verify(
        () => mockLogger.warn(any(that: contains('`accessoryInline` slot'))),
      ).called(1);
    });

    test('warns once per HWSizeAdaptive nested in a slot', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: HWColumn(
            children: [HWSizeAdaptive(small: HWText.fixed('inner'))],
          ),
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: Widget "Adaptive": an HWSizeAdaptive sits inside the '
          '`small` slot of another one, which only renders for systemSmall, '
          'systemMedium, systemLarge. The inner one can never see another '
          'family.',
        ),
      ).called(1);
    });
  });

  group('androidSizeRange bounds', () {
    WidgetSpec specWith(HWAndroidSizeRange range) => _spec(
          HWSizeAdaptive(small: _s, androidSizeRanges: [range]),
          android: _androidDefault,
        );

    test('rejects a minimum above its maximum', () {
      expect(
        () => validateSizeAdaptive(
          specWith(
            const HWAndroidSizeRange(
              minWidth: 400,
              maxWidth: 300,
              child: _strip,
            ),
          ),
        ),
        throwsA(
          _errorWith(
            equals(
              'Widget "Adaptive": an HWAndroidSizeRange has minWidth 400 '
              'and maxWidth 300. A minimum must not exceed its maximum.',
            ),
          ),
        ),
      );
    });

    test('rejects a negative minimum', () {
      expect(
        () => validateSizeAdaptive(
          specWith(const HWAndroidSizeRange(minHeight: -10, child: _strip)),
        ),
        throwsA(
          _errorWith(
            equals(
              'Widget "Adaptive": an HWAndroidSizeRange has minHeight -10. '
              'A minimum must be a finite dp value of 0 or more.',
            ),
          ),
        ),
      );
    });

    test('rejects an infinite minimum', () {
      expect(
        () => validateSizeAdaptive(
          specWith(
            const HWAndroidSizeRange(
              minWidth: double.infinity,
              child: _strip,
            ),
          ),
        ),
        throwsA(_errorWith(contains('has minWidth Infinity.'))),
      );
    });

    test('rejects a negative maximum', () {
      expect(
        () => validateSizeAdaptive(
          specWith(const HWAndroidSizeRange(maxHeight: -1, child: _strip)),
        ),
        throwsA(
          _errorWith(
            equals(
              'Widget "Adaptive": an HWAndroidSizeRange has maxHeight -1. A '
              'maximum must be a dp value of 0 or more, or double.infinity for '
              'no bound at all.',
            ),
          ),
        ),
      );
    });

    test('rejects a maximum that is not a number', () {
      expect(
        () => validateSizeAdaptive(
          specWith(
            const HWAndroidSizeRange(maxWidth: double.nan, child: _strip),
          ),
        ),
        throwsA(_errorWith(contains('has maxWidth NaN.'))),
      );
    });

    test('reads an infinite maximum as no bound at all', () {
      expect(
        () => validateSizeAdaptive(
          specWith(
            const HWAndroidSizeRange(
              minHeight: 200,
              maxHeight: double.infinity,
              child: _strip,
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('checks an instance only iOS renders too', () {
      final spec = _spec(
        HWAdaptive(
          ios: const HWSizeAdaptive(
            small: _s,
            androidSizeRanges: [
              HWAndroidSizeRange(minHeight: 400, maxHeight: 300, child: _l),
            ],
          ),
          android: _s,
        ),
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(_errorWith(contains('minHeight 400 and maxHeight 300'))),
      );
    });
  });

  group('the sixteen-size cap', () {
    test('names the grid the bounds ask for', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          androidSizeRanges: [
            HWAndroidSizeRange(maxHeight: 120, child: _strip),
            HWAndroidSizeRange(minWidth: 300, maxWidth: 399, child: _wide),
            _dashboardRange,
            HWAndroidSizeRange(
              minHeight: 300,
              maxHeight: 400,
              child: _tall,
            ),
            HWAndroidSizeRange(minWidth: 150, maxWidth: 200, child: _l),
          ],
        ),
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            equals(
              'Widget "Adaptive" needs 23 Android sizes to place its '
              'HWAndroidSizeRange bounds exactly (widths 80, 150, 201, 250, '
              '300, 400; heights 80, 121, 200, 250, 300, 401). Android '
              'renders at most 16 per widget. Reuse bounds (the family sizes '
              '110, 250 and 530 cost nothing extra) or drop a range.',
            ),
          ),
        ),
      );
    });

    test('the worked example stays well under it', () {
      expect(
        () => validateSizeAdaptive(_spec(_example, android: _androidDefault)),
        returnsNormally,
      );
    });
  });

  group('unrendered androidSizeRanges', () {
    test('warns about one an earlier range covers', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          large: _l,
          androidSizeRanges: [
            _stripRange,
            HWAndroidSizeRange(maxHeight: 100, child: _dashboard),
          ],
        ),
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the second HWAndroidSizeRange (maxHeight: 100) in '
          '"Adaptive" is never rendered: an earlier range of the same '
          'HWSizeAdaptive matches every size it would.',
        ),
      ).called(1);
    });

    test('warns about one an earlier range shadows the thresholds of', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          large: _l,
          androidSizeRanges: [
            _stripRange,
            HWAndroidSizeRange(
              minHeight: 50,
              maxHeight: 100,
              child: _dashboard,
            ),
          ],
        ),
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the second HWAndroidSizeRange (minHeight: 50, '
          'maxHeight: 100) in "Adaptive" is never rendered: an earlier '
          'range of the same HWSizeAdaptive matches every size it would.',
        ),
      ).called(1);
    });

    test("warns about one that stops below the widget's minimum size", () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          large: _l,
          androidSizeRanges: [HWAndroidSizeRange(maxHeight: 30, child: _l)],
        ),
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the first HWAndroidSizeRange (maxHeight: 30) in '
          '"Adaptive" is never rendered: it lies below the widget\'s minimum '
          'size.',
        ),
      ).called(1);
    });

    test('warns about one beyond what the configuration allows', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          large: _l,
          androidSizeRanges: [
            HWAndroidSizeRange(minWidth: 600, minHeight: 600, child: _wide),
          ],
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          maxResizeWidth: 400,
          maxResizeHeight: 400,
        ),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the first HWAndroidSizeRange (minWidth: 600, '
          'minHeight: 600) in "Adaptive" is never rendered: it lies beyond the '
          'maximum size the Android configuration allows.',
        ),
      ).called(1);
    });

    test('warns about one on an instance Android never reaches', () {
      final spec = _spec(
        HWAdaptive(
          ios: const HWSizeAdaptive(
            small: _s,
            androidSizeRanges: [_stripRange],
          ),
          android: _s,
        ),
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the first HWAndroidSizeRange (maxHeight: 120) in '
          '"Adaptive" is never rendered: Android never renders the '
          'HWSizeAdaptive it sits on.',
        ),
      ).called(1);
    });

    test('says nothing about the worked example', () {
      validateSizeAdaptive(_spec(_example, android: _androidDefault));

      verifyNever(
        () => mockLogger.warn(any(that: contains('HWAndroidSizeRange'))),
      );
    });

    test('says nothing at all without an Android configuration', () {
      expect(() => validateSizeAdaptive(_spec(_example)), returnsNormally);

      verifyNever(() => mockLogger.warn(any()));
    });
  });

  group('androidSizeRanges below the target span', () {
    Matcher containsSpanWarning() => contains('target span');

    test('warns about one that only matches below the target rows', () {
      final spec = _spec(
        _example,
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(targetCellHeight: 3),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the first HWAndroidSizeRange (maxHeight: 120) in '
          '"Adaptive" only matches below the widget\'s 3-row target span. '
          'Launchers keep the widget at targetCellHeight rows unless '
          'minResizeHeight is set; add minResizeHeight (40, say) to '
          'HomeWidgetAndroidConfiguration.',
        ),
      ).called(1);
    });

    test('warns about one that only matches below the target columns', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          androidSizeRanges: [
            HWAndroidSizeRange(maxWidth: 120, child: _strip),
          ],
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(targetCellWidth: 3),
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: the first HWAndroidSizeRange (maxWidth: 120) in '
          '"Adaptive" only matches below the widget\'s 3-column target span. '
          'Launchers keep the widget at targetCellWidth columns unless '
          'minResizeWidth is set; add minResizeWidth (40, say) to '
          'HomeWidgetAndroidConfiguration.',
        ),
      ).called(1);
    });

    test('says nothing once minResizeHeight lets the launcher go lower', () {
      final spec = _spec(
        _example,
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          targetCellHeight: 3,
          minResizeHeight: 40,
        ),
      );

      validateSizeAdaptive(spec);

      verifyNever(() => mockLogger.warn(any(that: containsSpanWarning())));
    });

    test('says nothing about a bound at the target span', () {
      final spec = _spec(
        _example,
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(targetCellHeight: 2),
      );

      validateSizeAdaptive(spec);

      verifyNever(() => mockLogger.warn(any(that: containsSpanWarning())));
    });

    test('says nothing without a target span', () {
      validateSizeAdaptive(
        _spec(_example, iOS: null, android: _androidDefault),
      );

      verifyNever(() => mockLogger.warn(any(that: containsSpanWarning())));
    });

    test('says nothing about an axis the widget cannot be resized along', () {
      final spec = _spec(
        _example,
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          targetCellHeight: 3,
          resizeMode: HWAndroidResizeMode.horizontal,
        ),
      );

      validateSizeAdaptive(spec);

      verifyNever(() => mockLogger.warn(any(that: containsSpanWarning())));
    });

    test('ignores an instance Android never renders', () {
      final spec = _spec(
        HWAdaptive(
          ios: const HWSizeAdaptive(
            small: _s,
            androidSizeRanges: [
              HWAndroidSizeRange(maxHeight: 60, child: _strip),
            ],
          ),
          android: const HWSizeAdaptive(
            small: _s,
            medium: _m,
            large: _l,
            androidSizeRanges: [_dashboardRange],
          ),
        ),
        android: const HomeWidgetAndroidConfiguration(targetCellHeight: 3),
      );

      validateSizeAdaptive(spec);

      verifyNever(() => mockLogger.warn(any(that: containsSpanWarning())));
    });
  });

  group('slots and content on the grid', () {
    test('warns about a slot the ranges shadow at every corner', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          androidSizeRanges: [
            HWAndroidSizeRange(maxHeight: 249, child: _strip),
          ],
        ),
        iOS: null,
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(any(that: contains('slot `medium`'))),
      ).called(1);
    });

    test('keeps a slot some corner of the grid renders', () {
      final spec = _spec(_example, iOS: null, android: _androidDefault);

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('is never rendered'))),
      );
    });

    test('names the enclosing androidSizeRange of a nested instance', () {
      final spec = _spec(
        HWSizeAdaptive(
          small: _s,
          androidSizeRanges: [
            HWAndroidSizeRange(
              maxHeight: 120,
              child: const HWSizeAdaptive(small: _strip, large: _dashboard),
            ),
          ],
        ),
        iOS: null,
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: HWSizeAdaptive slot `large` in "Adaptive" is never '
          'rendered: not generated for iOS and on Android its enclosing '
          'androidSizeRange only renders where its bounds match.',
        ),
      ).called(1);
      verify(
        () => mockLogger.warn(
          'Warning: Widget "Adaptive": an HWSizeAdaptive sits inside an '
          'androidSizeRange of another one, which only renders where that '
          'range matches. The inner one can never be rendered anywhere else.',
        ),
      ).called(1);
    });

    test('still reports a family the corners ask for and nothing answers', () {
      final spec = _spec(
        const HWSizeAdaptive(large: _l, androidSizeRanges: [_stripRange]),
        iOS: null,
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(
          _errorWith(
            allOf(
              contains('no content for systemSmall'),
              contains('no content for systemMedium'),
            ),
          ),
        ),
      );
    });

    test('says nothing when ranges cover every corner they are picked at', () {
      final spec = _spec(
        const HWSizeAdaptive(
          large: _l,
          androidSizeRanges: [
            HWAndroidSizeRange(maxWidth: 249, child: _strip),
            HWAndroidSizeRange(maxHeight: 249, child: _dashboard),
          ],
        ),
        iOS: null,
        android: _androidDefault,
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('demands no family the widget could never be resized to', () {
      final spec = _spec(
        const HWSizeAdaptive(large: _l, androidSizeRanges: [_stripRange]),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          minResizeWidth: 250,
          minResizeHeight: 250,
        ),
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('demands nothing from a widget capped below the dp floor', () {
      // The floor corner is cut whatever the cap is, so it is the one corner
      // that can sit above the maximum.
      final spec = _spec(
        const HWSizeAdaptive(
          large: _l,
          androidSizeRanges: [_dashboardRange],
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(
          maxResizeWidth: 30,
          maxResizeHeight: 30,
        ),
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });

    test('checks a nested instance only where its range renders', () {
      HWWidget treeWith(HWWidget inner) => HWSizeAdaptive(
            small: _s,
            androidSizeRanges: [
              HWAndroidSizeRange(
                minWidth: 400,
                minHeight: 200,
                child: inner,
              ),
            ],
          );

      expect(
        () => validateSizeAdaptive(
          _spec(
            treeWith(const HWSizeAdaptive(medium: _m, large: _l)),
            iOS: null,
            android: _androidDefault,
          ),
        ),
        returnsNormally,
      );

      // The corners the range renders at never pick systemSmall, so only
      // the family they do pick is reported.
      expect(
        () => validateSizeAdaptive(
          _spec(
            treeWith(const HWSizeAdaptive(large: _l)),
            iOS: null,
            android: _androidDefault,
          ),
        ),
        throwsA(
          _errorWith(
            allOf(
              contains('no content for systemMedium'),
              isNot(contains('systemSmall')),
            ),
          ),
        ),
      );
    });

    test('the same tree without a range still misses systemSmall', () {
      final spec = _spec(
        const HWSizeAdaptive(large: _l),
        iOS: null,
        android: _androidDefault,
      );

      expect(
        () => validateSizeAdaptive(spec),
        throwsA(_errorWith(contains('no content for systemSmall'))),
      );
    });

    test('an instance the tree holds twice answers for both places', () {
      const shared = HWSizeAdaptive(small: _s, large: _l);
      final spec = _spec(
        HWColumn(
          children: [
            shared,
            shared,
            HWAdaptive(
              ios: _s,
              android: const HWSizeAdaptive(
                small: _s,
                androidSizeRanges: [_stripRange],
              ),
            ),
          ],
        ),
        iOS: null,
        android: _androidDefault,
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
    });
  });

  group('non-nesting family sizes', () {
    test('warns about the two extra-large families', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          extraLarge: _wide,
          extraLargePortrait: _tall,
          androidSizeRanges: [_stripRange],
        ),
        iOS: null,
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: in "Adaptive", extraLarge (530 × 250 dp) and '
          'extraLargePortrait (250 × 530 dp) render different layouts. With '
          "androidSizeRanges, sizes that fit both get extraLargePortrait's, "
          'even when they are wider than tall.',
        ),
      ).called(1);
    });

    test('says nothing when only one of the two has a slot of its own', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          extraLargePortrait: _tall,
          androidSizeRanges: [_stripRange],
        ),
        iOS: null,
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('render different layouts'))),
      );
    });

    test('names whichever family the corner rule picks', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(300, 100)},
          androidSizeRanges: [_stripRange],
        ),
        iOS: null,
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verify(
        () => mockLogger.warn(
          'Warning: in "Adaptive", small (110 × 110 dp) and medium '
          '(300 × 100 dp) render different layouts. With androidSizeRanges, '
          "sizes that fit both get medium's, even when they are taller than "
          'wide.',
        ),
      ).called(1);
    });

    test('says nothing when both families render the same layout', () {
      final spec = _spec(_example, iOS: null, android: _androidDefault);

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('render different layouts'))),
      );
    });

    test('says nothing when one of them is out of the resize range', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          extraLarge: _wide,
          extraLargePortrait: _tall,
          androidSizeRanges: [_stripRange],
        ),
        iOS: null,
        android: const HomeWidgetAndroidConfiguration(maxResizeWidth: 400),
      );

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('render different layouts'))),
      );
    });

    test('says nothing without a range', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: _s,
          medium: _m,
          large: _l,
          extraLarge: _wide,
          extraLargePortrait: _tall,
        ),
        iOS: null,
        android: _androidDefault,
      );

      validateSizeAdaptive(spec);

      verifyNever(
        () => mockLogger.warn(any(that: contains('render different layouts'))),
      );
    });
  });

  group('trees without an HWSizeAdaptive', () {
    test('are not validated against families at all', () {
      final spec = _spec(
        HWText.fixed('plain'),
        iOS: const HomeWidgetIOSConfiguration(
          groupId: 'group.test',
          supportedFamilies: [HWWidgetFamily.accessoryCircular],
        ),
        android: _androidDefault,
      );

      expect(() => validateSizeAdaptive(spec), returnsNormally);
      verifyNever(() => mockLogger.warn(any()));
    });
  });
}
