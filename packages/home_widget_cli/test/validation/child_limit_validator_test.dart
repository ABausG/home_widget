import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/child_limit_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
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
        name: 'Crowded',
        iOS: const HomeWidgetIOSConfiguration(groupId: 'group.test'),
        android: android,
      ),
      className: 'Crowded',
      widgetTree: tree,
    );

List<HWWidget> _texts(int count) => [
      for (var index = 0; index < count; index++) HWText.fixed('$index'),
    ];

/// A column one child past what Glance lays out.
final _crowded = HWColumn(children: _texts(11));

Matcher _rejectedWith(Object message) => throwsA(
      isA<GeneratorError>()
          .having((error) => error.message, 'message', message),
    );

void main() {
  test('accepts a stack of ten children', () {
    expect(
      () => validateChildLimits(_spec(HWColumn(children: _texts(10)))),
      returnsNormally,
    );
  });

  test('rejects a stack of eleven children', () {
    expect(
      () => validateChildLimits(_spec(_crowded)),
      _rejectedWith(
        'Widget "Crowded": an HWColumn has 11 children + 0 spacers (start) = '
        '11 > 10. On Android, Glance lays out at most 10 children in a '
        'Column, spacers included, and silently drops the rest. Group some '
        'children in a nested HWColumn, HWRow or HWStack, which counts as one '
        'child.',
      ),
    );
  });

  test('counts the spacers of the main-axis alignment', () {
    expect(
      () => validateChildLimits(
        _spec(
          HWRow(
            mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
            children: _texts(5),
          ),
        ),
      ),
      _rejectedWith(
        'Widget "Crowded": an HWRow has 5 children + 6 spacers (spaceEvenly) '
        '= 11 > 10. On Android, Glance lays out at most 10 children in a Row, '
        'spacers included, and silently drops the rest. Group some children in '
        'a nested HWColumn, HWRow or HWStack, which counts as one child, or '
        'use a mainAxisAlignment that adds fewer spacers.',
      ),
    );
  });

  test('names a single spacer as one', () {
    expect(
      () => validateChildLimits(
        _spec(
          HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.end,
            children: _texts(10),
          ),
        ),
      ),
      _rejectedWith(contains('10 children + 1 spacer (end) = 11 > 10')),
    );
  });

  final largestFitting = <HWMainAxisAlignment?, int>{
    null: 10,
    HWMainAxisAlignment.start: 10,
    HWMainAxisAlignment.end: 9,
    HWMainAxisAlignment.center: 8,
    HWMainAxisAlignment.spaceBetween: 5,
    HWMainAxisAlignment.spaceEvenly: 4,
  };
  for (final MapEntry(key: alignment, value: largest)
      in largestFitting.entries) {
    test('fits $largest children with ${alignment?.name ?? 'no'} alignment',
        () {
      HWRow row(int children) =>
          HWRow(mainAxisAlignment: alignment, children: _texts(children));

      expect(() => validateChildLimits(_spec(row(largest))), returnsNormally);
      expect(
        () => validateChildLimits(_spec(row(largest + 1))),
        _rejectedWith(contains('> 10')),
      );
    });
  }

  test('does not count spacing, which is padding', () {
    expect(
      () => validateChildLimits(
        _spec(HWColumn(spacing: 8, children: _texts(10))),
      ),
      returnsNormally,
    );
  });

  test('does not count a child rendering nothing on Android', () {
    expect(
      () => validateChildLimits(
        _spec(
          HWColumn(
            children: [
              ..._texts(10),
              const HWDataOnly([HWString('id')]),
              const HWAdaptive(
                ios: HWText.fixed('iOS'),
                android: HWDataOnly([HWString('other')]),
              ),
            ],
          ),
        ),
      ),
      returnsNormally,
    );
  });

  test('checks every nested stack on its own', () {
    expect(
      () => validateChildLimits(
        _spec(
          HWColumn(
            children: [
              ..._texts(9),
              HWRow(children: _texts(10)),
            ],
          ),
        ),
      ),
      returnsNormally,
    );
    expect(
      () => validateChildLimits(
        _spec(
          HWColumn(
            children: [
              HWPadding(
                padding: const HWEdgeInsets.all(4),
                child: HWRow(children: _texts(11)),
              ),
            ],
          ),
        ),
      ),
      _rejectedWith(contains('an HWRow has 11 children')),
    );
  });

  test('skips a widget generated for iOS only', () {
    expect(
      () => validateChildLimits(_spec(_crowded, android: null)),
      returnsNormally,
    );
  });

  test('counts only the Android side of an adaptive', () {
    expect(
      () => validateChildLimits(
        _spec(HWAdaptive(ios: _crowded, android: const HWText.fixed('a'))),
      ),
      returnsNormally,
    );
    expect(
      () => validateChildLimits(
        _spec(HWAdaptive(ios: const HWText.fixed('a'), android: _crowded)),
      ),
      _rejectedWith(contains('an HWColumn has 11 children')),
    );
  });

  test('counts only the slots of a size-adaptive Android renders', () {
    expect(
      () => validateChildLimits(
        _spec(
          HWSizeAdaptive(
            small: const HWText.fixed('a'),
            accessoryRectangular: _crowded,
          ),
        ),
      ),
      returnsNormally,
    );
    expect(
      () => validateChildLimits(
        _spec(HWSizeAdaptive(small: const HWText.fixed('a'), large: _crowded)),
      ),
      _rejectedWith(contains('an HWColumn has 11 children')),
    );
  });

  group('a stack of layers', () {
    test('accepts ten children', () {
      expect(
        () => validateChildLimits(_spec(HWStack(children: _texts(10)))),
        returnsNormally,
      );
    });

    test('rejects eleven children, without naming spacers', () {
      expect(
        () => validateChildLimits(_spec(HWStack(children: _texts(11)))),
        _rejectedWith(
          'Widget "Crowded": an HWStack has 11 children > 10. On Android, '
          'Glance lays out at most 10 children in a Box and silently drops '
          'the rest. Group some children in a nested HWColumn, HWRow or '
          'HWStack, which counts as one child.',
        ),
      );
    });

    test('rejects eleven children of an expanding stack too', () {
      expect(
        () => validateChildLimits(
          _spec(HWStack(fit: HWStackFit.expand, children: _texts(11))),
        ),
        _rejectedWith(contains('an HWStack has 11 children > 10')),
      );
    });

    test('counts a conditional child as one child', () {
      HWStack stack(int texts) => HWStack(
            children: [
              ..._texts(texts),
              const HWBoolConditional(
                data: HWBool('flag', defaultValue: false),
                whenTrue: HWText.fixed('on'),
                whenFalse: HWText.fixed('off'),
              ),
            ],
          );
      expect(() => validateChildLimits(_spec(stack(9))), returnsNormally);
      expect(
        () => validateChildLimits(_spec(stack(10))),
        _rejectedWith(contains('an HWStack has 11 children > 10')),
      );
    });

    test('does not count a child rendering nothing on Android', () {
      expect(
        () => validateChildLimits(
          _spec(
            HWStack(
              children: [
                ..._texts(10),
                const HWDataOnly([HWString('id')]),
                const HWSizedBox.shrink(),
              ],
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('is skipped where only iOS renders it', () {
      expect(
        () => validateChildLimits(
          _spec(
            HWAdaptive(
              ios: HWStack(children: _texts(11)),
              android: const HWText.fixed('a'),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('counts as one child of the stack around it', () {
      expect(
        () => validateChildLimits(
          _spec(
            HWColumn(
              children: [..._texts(9), HWStack(children: _texts(2))],
            ),
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validateChildLimits(
          _spec(
            HWColumn(
              children: [..._texts(10), HWStack(children: _texts(2))],
            ),
          ),
        ),
        _rejectedWith(contains('an HWColumn has 11 children')),
      );
    });

    test('is checked inside the item of a builder', () {
      expect(
        () => validateChildLimits(
          _spec(
            HWRow.builder(
              'forecast',
              maxItems: 2,
              item: HWStack(children: _texts(11)),
            ),
          ),
        ),
        _rejectedWith(contains('an HWStack has 11 children > 10')),
      );
    });
  });

  group('a builder', () {
    HWRow builder({
      int? maxItems,
      HWMainAxisAlignment? alignment,
      HWWidget item = const HWText(HWItemData(HWString('label'))),
      HWWidget? whenEmpty,
      double spacing = 0,
    }) =>
        HWRow.builder(
          'forecast',
          maxItems: maxItems,
          mainAxisAlignment: alignment,
          item: item,
          whenEmpty: whenEmpty,
          spacing: spacing,
        );

    test('needs maxItems on Android', () {
      expect(
        () => validateChildLimits(
          _spec(builder(alignment: HWMainAxisAlignment.spaceEvenly)),
        ),
        _rejectedWith(
          'Widget "Crowded": HWRow.builder(\'forecast\') has no maxItems. On '
          'Android, Glance lays out at most 10 children in a Row, spacers '
          'included, and silently drops the rest, so a builder needs maxItems '
          'there: at most 4 items fit a Row with mainAxisAlignment '
          'spaceEvenly.',
        ),
      );
    });

    test('names the column it is', () {
      expect(
        () => validateChildLimits(
          _spec(
            const HWColumn.builder(
              'events',
              item: HWText(HWItemData(HWString('title'))),
            ),
          ),
        ),
        _rejectedWith(
          startsWith(
            'Widget "Crowded": HWColumn.builder(\'events\') has no maxItems. '
            'On Android, Glance lays out at most 10 children in a Column',
          ),
        ),
      );
    });

    test('rejects more items and spacers than Glance lays out', () {
      expect(
        () => validateChildLimits(
          _spec(
            builder(maxItems: 5, alignment: HWMainAxisAlignment.spaceEvenly),
          ),
        ),
        _rejectedWith(
          'Widget "Crowded": HWRow.builder(\'forecast\') renders up to 5 items '
          '+ 6 spacers (spaceEvenly) = 11 > 10. On Android, Glance lays out at '
          'most 10 children in a Row, spacers included, and silently drops the '
          'rest. Use maxItems 4, or mainAxisAlignment spaceBetween.',
        ),
      );
    });

    test('suggests the alignment that still fits with the most spacers', () {
      expect(
        () => validateChildLimits(
          _spec(builder(maxItems: 10, alignment: HWMainAxisAlignment.end)),
        ),
        _rejectedWith(
          allOf(
            contains('10 items + 1 spacer (end) = 11 > 10'),
            endsWith('Use maxItems 9, or mainAxisAlignment start.'),
          ),
        ),
      );
      expect(
        () => validateChildLimits(_spec(builder(maxItems: 11))),
        _rejectedWith(
          allOf(
            contains('11 items + 0 spacers (start) = 11 > 10'),
            endsWith('Use maxItems 10.'),
          ),
        ),
      );
    });

    final largestFitting = <HWMainAxisAlignment?, int>{
      null: 10,
      HWMainAxisAlignment.start: 10,
      HWMainAxisAlignment.end: 9,
      HWMainAxisAlignment.center: 8,
      HWMainAxisAlignment.spaceBetween: 5,
      HWMainAxisAlignment.spaceEvenly: 4,
    };
    for (final MapEntry(key: alignment, value: largest)
        in largestFitting.entries) {
      test('fits $largest items with ${alignment?.name ?? 'no'} alignment', () {
        expect(
          () => validateChildLimits(
            _spec(builder(maxItems: largest, alignment: alignment)),
          ),
          returnsNormally,
        );
        expect(
          () => validateChildLimits(
            _spec(builder(maxItems: largest + 1, alignment: alignment)),
          ),
          _rejectedWith(contains('Use maxItems $largest')),
        );
      });
    }

    test('counts neither whenEmpty nor spacing against its items', () {
      expect(
        () => validateChildLimits(
          _spec(
            builder(
              maxItems: 4,
              alignment: HWMainAxisAlignment.spaceEvenly,
              whenEmpty: const HWText.fixed('No forecast yet'),
              spacing: 8,
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('needs no maxItems when its item renders nothing on Android', () {
      for (final item in const [
        HWDataOnly([HWItemData(HWString('id'))]),
        HWAdaptive(
          ios: HWText(HWItemData(HWString('label'))),
          android: HWDataOnly([HWItemData(HWString('label'))]),
        ),
      ]) {
        expect(
          () => validateChildLimits(_spec(builder(item: item))),
          returnsNormally,
        );
      }
    });

    test('is not checked for a widget generated for iOS only', () {
      expect(
        () => validateChildLimits(_spec(builder(), android: null)),
        returnsNormally,
      );
    });

    test('is checked where Android renders it and nowhere else', () {
      expect(
        () => validateChildLimits(
          _spec(
            HWAdaptive(ios: builder(), android: const HWText.fixed('a')),
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validateChildLimits(
          _spec(
            HWSizeAdaptive(
              small: builder(maxItems: 3),
              accessoryRectangular: builder(),
            ),
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validateChildLimits(
          _spec(HWAdaptive(ios: const HWText.fixed('a'), android: builder())),
        ),
        _rejectedWith(contains('has no maxItems')),
      );
      expect(
        () => validateChildLimits(
          _spec(HWSizeAdaptive(small: builder(maxItems: 3), large: builder())),
        ),
        _rejectedWith(contains('has no maxItems')),
      );
    });
  });

  group('custom font texts', () {
    const chewy = HWTextStyle(fontFamily: 'Chewy');

    List<HWWidget> fontTexts(int count) => [
          for (var index = 0; index < count; index++)
            HWText.fixed('$index', style: chewy),
        ];

    HWWidget listOf(String list, {required int maxItems, required int texts}) =>
        HWRow.builder(
          list,
          maxItems: maxItems,
          item: HWColumn(children: fontTexts(texts)),
        );

    test('warn once more of them can render than Android measures', () {
      final mock = useMockLogger();
      validateMeasuredTexts(
        _spec(
          HWColumn(
            children: [
              listOf('days', maxItems: 10, texts: 2),
              listOf('hours', maxItems: 10, texts: 2),
            ],
          ),
        ),
      );

      final message = verify(() => mock.warn(captureAny())).captured.single;
      expect(
        message,
        'Warning: Widget "Crowded": its Android layout can render up to 40 '
        'texts in a custom font, counting a text in the item of a builder once '
        'per item, but Android measures the room of at most 32 of them per '
        'widget size. The rest are drawn against the bounds of the whole '
        'widget and can overflow their place. Lower the maxItems of a builder, '
        'or render some of the texts in the platform font.',
      );
    });

    test('stay quiet while every one of them is measured', () {
      final mock = useMockLogger();
      validateMeasuredTexts(
        _spec(
          HWColumn(
            children: [
              HWRow(children: fontTexts(2)),
              listOf('days', maxItems: 10, texts: 3),
              const HWText.fixed('plain'),
            ],
          ),
        ),
      );
      verifyNever(() => mock.warn(any()));
    });

    test('count a text outside the items once', () {
      final mock = useMockLogger();
      validateMeasuredTexts(
        _spec(
          HWColumn(
            children: [
              HWRow(children: fontTexts(3)),
              listOf('days', maxItems: 10, texts: 3),
            ],
          ),
        ),
      );
      expect(
        verify(() => mock.warn(captureAny())).captured.single,
        contains('up to 33 texts'),
      );
    });

    test('count inside a stack of layers, in the item of a builder too', () {
      final mock = useMockLogger();
      validateMeasuredTexts(
        _spec(
          HWColumn(
            children: [
              HWStack(children: fontTexts(3)),
              HWRow.builder(
                'days',
                maxItems: 10,
                item: HWStack(children: fontTexts(3)),
              ),
            ],
          ),
        ),
      );
      expect(
        verify(() => mock.warn(captureAny())).captured.single,
        contains('up to 33 texts'),
      );
    });

    test('count only what Android renders', () {
      final mock = useMockLogger();
      final crowded = HWColumn(
        children: [
          listOf('days', maxItems: 10, texts: 2),
          listOf('hours', maxItems: 10, texts: 2),
        ],
      );
      validateMeasuredTexts(
        _spec(HWAdaptive(ios: crowded, android: const HWText.fixed('a'))),
      );
      validateMeasuredTexts(_spec(crowded, android: null));
      validateMeasuredTexts(
        _spec(
          HWRow.builder(
            'days',
            maxItems: 10,
            item: HWAdaptive(
              ios: HWColumn(children: fontTexts(4)),
              android: const HWText.fixed('plain'),
            ),
          ),
        ),
      );
      verifyNever(() => mock.warn(any()));
    });
  });
}
