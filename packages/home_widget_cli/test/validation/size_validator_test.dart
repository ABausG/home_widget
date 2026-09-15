import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/validation/size_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

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
