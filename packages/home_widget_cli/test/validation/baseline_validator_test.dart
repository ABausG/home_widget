import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/validation/baseline_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

WidgetSpec _spec(
  HWWidget tree, {
  HomeWidgetAndroidConfiguration? android =
      const HomeWidgetAndroidConfiguration(),
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Baseline',
        iOS: const HomeWidgetIOSConfiguration(groupId: 'group.test'),
        android: android,
      ),
      className: 'Baseline',
      widgetTree: tree,
    );

/// A baseline row Android cannot line up: one text beside a picture.
const _lonelyBaselineRow = HWRow(
  crossAxisAlignment: HWCrossAxisAlignment.baseline,
  children: [
    HWText.fixed('34'),
    HWImage(HWImageData('avatar'), width: 8),
  ],
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

  test('warns about a baseline row with one text beside a picture', () {
    validateBaselineRows(
      _spec(
        const HWColumn(
          children: [
            HWRow(
              crossAxisAlignment: HWCrossAxisAlignment.baseline,
              children: [
                HWText.fixed('34'),
                HWImage(HWImageData('avatar'), width: 8),
              ],
            ),
          ],
        ),
      ),
    );

    final message = verify(() => mockLogger.warn(captureAny())).captured.single;
    expect(
      message,
      allOf(
        contains('Warning: Widget "Baseline"'),
        contains('only one child'),
        contains('leaves them at the top of the row'),
      ),
    );
  });

  test('warns about a baseline row rendering no text at all', () {
    validateBaselineRows(
      _spec(
        const HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          children: [
            HWImage(HWImageData('avatar'), width: 8),
            HWImage(HWImageData('other'), width: 8),
          ],
        ),
      ),
    );

    final message = verify(() => mockLogger.warn(captureAny())).captured.single;
    expect(message, contains('no child'));
  });

  test('stays quiet for a row with two texts', () {
    validateBaselineRows(
      _spec(
        const HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          children: [HWText.fixed('34'), HWText.fixed('kg')],
        ),
      ),
    );
    verifyNever(() => mockLogger.warn(any()));
  });

  test('stays quiet for a row that asks for no baseline', () {
    validateBaselineRows(
      _spec(
        const HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.end,
          children: [
            HWText.fixed('34'),
            HWImage(HWImageData('avatar'), width: 8),
          ],
        ),
      ),
    );
    verifyNever(() => mockLogger.warn(any()));
  });

  test('stays quiet for a baseline row only iOS renders', () {
    validateBaselineRows(
      _spec(
        const HWAdaptive(ios: _lonelyBaselineRow, android: HWText.fixed('34')),
      ),
    );
    verifyNever(() => mockLogger.warn(any()));
  });

  test('warns about a baseline row on the Android side of an adaptive', () {
    validateBaselineRows(
      _spec(
        const HWAdaptive(ios: HWText.fixed('34'), android: _lonelyBaselineRow),
      ),
    );
    verify(() => mockLogger.warn(captureAny())).captured.single;
  });

  test('stays quiet for a baseline row in an accessory-only slot', () {
    validateBaselineRows(
      _spec(
        const HWSizeAdaptive(
          small: HWText.fixed('34'),
          accessoryInline: _lonelyBaselineRow,
        ),
      ),
    );
    verifyNever(() => mockLogger.warn(any()));
  });

  test('warns once about a baseline row in a reachable system slot', () {
    validateBaselineRows(
      _spec(const HWSizeAdaptive(small: _lonelyBaselineRow)),
    );
    verify(() => mockLogger.warn(captureAny())).captured.single;
  });

  test('stays quiet without an Android widget', () {
    validateBaselineRows(
      _spec(
        const HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          children: [
            HWText.fixed('34'),
            HWImage(HWImageData('avatar'), width: 8),
          ],
        ),
        android: null,
      ),
    );
    verifyNever(() => mockLogger.warn(any()));
  });

  group('a baseline builder', () {
    HWRow builder({int? maxItems, HWWidget? item}) => HWRow.builder(
          'forecast',
          maxItems: maxItems,
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: item ?? const HWText(HWItemData(HWString('label'))),
        );

    test('stays quiet while more than one item can render text', () {
      validateBaselineRows(_spec(builder(maxItems: 5)));
      validateBaselineRows(_spec(builder()));
      verifyNever(() => mockLogger.warn(any()));
    });

    test('warns when it renders a single item', () {
      validateBaselineRows(_spec(builder(maxItems: 1)));

      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single;
      expect(
        message,
        startsWith(
          'Warning: Widget "Baseline": HWRow.builder(\'forecast\') with '
          'HWCrossAxisAlignment.baseline has only one child rendering text of '
          'its own.',
        ),
      );
    });

    test('warns when its item renders no text of its own', () {
      validateBaselineRows(
        _spec(
          builder(
            maxItems: 5,
            item: const HWImage(HWItemData(HWImageData('icon')), width: 8),
          ),
        ),
      );

      final message =
          verify(() => mockLogger.warn(captureAny())).captured.single;
      expect(message, contains("HWRow.builder('forecast') with"));
      expect(message, contains('has no child rendering text'));
    });
  });
}
