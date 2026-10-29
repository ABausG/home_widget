import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWAlignment', () {
    test('maps every value to a SwiftUI Alignment', () {
      expect(
        {
          for (final alignment in HWAlignment.values)
            alignment.name: alignment.swiftAlignment,
        },
        {
          'topStart': '.topLeading',
          'topCenter': '.top',
          'topEnd': '.topTrailing',
          'centerStart': '.leading',
          'center': '.center',
          'centerEnd': '.trailing',
          'bottomStart': '.bottomLeading',
          'bottomCenter': '.bottom',
          'bottomEnd': '.bottomTrailing',
        },
      );
    });

    test('maps every value to a Glance Alignment', () {
      expect(
        {
          for (final alignment in HWAlignment.values)
            alignment.name: alignment.kotlinAlignment,
        },
        {
          'topStart': 'Alignment.TopStart',
          'topCenter': 'Alignment.TopCenter',
          'topEnd': 'Alignment.TopEnd',
          'centerStart': 'Alignment.CenterStart',
          'center': 'Alignment.Center',
          'centerEnd': 'Alignment.CenterEnd',
          'bottomStart': 'Alignment.BottomStart',
          'bottomCenter': 'Alignment.BottomCenter',
          'bottomEnd': 'Alignment.BottomEnd',
        },
      );
    });
  });

  group('HWStackFit', () {
    test('offers a loose and an expanding fit', () {
      expect(HWStackFit.values.map((fit) => fit.name), ['loose', 'expand']);
    });
  });

  group('HWMainAxisAlignment spacers', () {
    test('place spacers before, between and after the children', () {
      final places = {
        for (final alignment in [null, ...HWMainAxisAlignment.values])
          alignment?.name: (
            alignment.hasLeadingSpacer,
            alignment.hasSpacerBetween,
            alignment.hasTrailingSpacer,
          ),
      };
      expect(places, {
        null: (false, false, false),
        'start': (false, false, false),
        'center': (true, false, true),
        'end': (true, false, false),
        'spaceBetween': (false, true, false),
        'spaceEvenly': (true, true, true),
      });
    });

    test('count the spacers for n children', () {
      const n = 4;
      expect(
        {
          for (final alignment in [null, ...HWMainAxisAlignment.values])
            alignment?.name: alignment.spacerCount(n),
        },
        {
          null: 0,
          'start': 0,
          'center': 2,
          'end': 1,
          'spaceBetween': n - 1,
          'spaceEvenly': n + 1,
        },
      );
    });

    test('count the spacers of a stack with one child or none', () {
      expect(HWMainAxisAlignment.spaceBetween.spacerCount(1), 0);
      expect(HWMainAxisAlignment.spaceBetween.spacerCount(0), 0);
      expect(HWMainAxisAlignment.spaceEvenly.spacerCount(1), 2);
      expect(HWMainAxisAlignment.center.spacerCount(0), 2);
    });

    test('leave room for the largest child counts Glance lays out', () {
      int largestFitting(HWMainAxisAlignment? alignment) {
        var children = 0;
        while (children + 1 + alignment.spacerCount(children + 1) <= 10) {
          children++;
        }
        return children;
      }

      expect(
        {
          for (final alignment in [null, ...HWMainAxisAlignment.values])
            alignment?.name: largestFitting(alignment),
        },
        {
          null: 10,
          'start': 10,
          'end': 9,
          'center': 8,
          'spaceBetween': 5,
          'spaceEvenly': 4,
        },
      );
    });
  });
}
