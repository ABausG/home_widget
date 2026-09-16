import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/validation/baseline_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

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
}
