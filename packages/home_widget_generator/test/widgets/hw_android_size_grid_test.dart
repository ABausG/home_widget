import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _small = HWText.fixed('small');
const _medium = HWText.fixed('medium');
const _large = HWText.fixed('large');
const _extraLarge = HWText.fixed('xl');
const _portrait = HWText.fixed('xlp');
const _strip = HWText.fixed('strip');
const _compact = HWText.fixed('compact');
const _wide = HWText.fixed('wide');
const _narrow = HWText.fixed('narrow');
const _tall = HWText.fixed('tall');
const _dashboard = HWText.fixed('dashboard');
const _footerSmall = HWText.fixed('footer-small');
const _footerLarge = HWText.fixed('footer-large');

/// The widget minimum both axes of a grid are floored at unless a test says
/// otherwise: the `minWidth` an Android configuration defaults to.
const double _floor = 80;

const _stripRange = HWAndroidSizeRange(maxHeight: 120, child: _strip);
const _dashboardRange = HWAndroidSizeRange(
  minWidth: 400,
  minHeight: 200,
  child: _dashboard,
);

/// The §4.4 widget: three slots, a strip for every one-row widget and a
/// dashboard for tablets.
const _example = HWSizeAdaptive(
  small: _small,
  medium: _medium,
  large: _large,
  androidSizeRanges: [_stripRange, _dashboardRange],
);

const _footer = HWSizeAdaptive(small: _footerSmall, large: _footerLarge);

const _splitStrips = HWSizeAdaptive(
  small: _small,
  medium: _medium,
  large: _large,
  androidSizeRanges: [
    HWAndroidSizeRange(maxWidth: 249, maxHeight: 120, child: _compact),
    HWAndroidSizeRange(minWidth: 250, maxHeight: 120, child: _wide),
    _dashboardRange,
  ],
);

const _fourRanges = HWSizeAdaptive(
  small: _small,
  medium: _medium,
  large: _large,
  androidSizeRanges: [
    _stripRange,
    HWAndroidSizeRange(maxWidth: 180, minHeight: 121, child: _narrow),
    _dashboardRange,
    HWAndroidSizeRange(
      minWidth: 300,
      maxWidth: 399,
      minHeight: 300,
      child: _tall,
    ),
  ],
);

HWAndroidSizeGrid _grid(
  List<HWSizeAdaptive> instances, {
  Map<HWWidgetFamily, HWSize>? sizes,
  double minWidth = _floor,
  double minHeight = _floor,
  bool keepFamilyCompositionSize = true,
  double? maxWidth,
  double? maxHeight,
}) =>
    HWAndroidSizeGrid.compile(
      instances: instances,
      table: HWWidgetFamily.androidSizeTable(sizes),
      minWidth: minWidth,
      minHeight: minHeight,
      keepFamilyCompositionSize: keepFamilyCompositionSize,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );

/// The thresholds before merging, which are where Glance's 1 dp of slack can
/// tip a pick either way.
Set<double> _rawThresholds(
  List<HWSizeAdaptive> instances,
  Map<HWWidgetFamily, HWSize> table, {
  required double floor,
  required bool horizontal,
}) =>
    {
      floor,
      for (final size in table.values) horizontal ? size.width : size.height,
      for (final instance in instances)
        for (final range in instance.androidSizeRangesOrEmpty)
          ...horizontal ? range.widthThresholds : range.heightThresholds,
    };

bool _near(double value, Set<double> thresholds) =>
    thresholds.any((threshold) => (value - threshold).abs() < 1.5);

/// Whether two family sizes fit [real] without either containing the other,
/// which is the one region a grid cannot follow (§4.3).
bool _nonNestingFit(Map<HWWidgetFamily, HWSize> table, HWSize real) {
  final fitting = [
    for (final size in table.values)
      if (HWAndroidSizeGrid.fits(size, real)) size,
  ];
  for (final a in fitting) {
    for (final b in fitting) {
      if (a.width > b.width && a.height < b.height) return true;
    }
  }
  return false;
}

bool _sameRender(List<HWWidget?> a, List<HWWidget?> b) {
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

/// Every real size the widget can reach on a 1 dp lattice picks the corner
/// rendering what §4.2 says it should, under both platform rules, and never
/// composes a family slot smaller than it is composed without ranges.
///
/// Sizes under the floor are skipped: the launcher never shrinks the widget
/// below its own minimum, so the grid does not answer for them.
void _checkEverySize(
  HWAndroidSizeGrid grid, {
  bool allowNonNesting = false,
  double minWidth = _floor,
  double minHeight = _floor,
}) {
  final table = grid.table;
  final corners = HWAndroidSizeGrid.sortedBySize(grid.sizes);
  final rendered = {
    for (final cell in grid.cells)
      cell.size: [for (final render in cell.renders) render.widget],
  };
  final widths = _rawThresholds(
    grid.instances,
    table,
    floor: minWidth,
    horizontal: true,
  );
  final heights = _rawThresholds(
    grid.instances,
    table,
    floor: minHeight,
    horizontal: false,
  );

  final mismatches = <String>[];
  final fidelity = <String>[];
  for (var row = 40; row <= 800 && mismatches.length < 5; row++) {
    final height = row + 0.3;
    if (height < minHeight) continue;
    if (_near(height, heights)) continue;
    for (var column = 40; column <= 800; column++) {
      final width = column + 0.3;
      if (width < minWidth) continue;
      if (_near(width, widths)) continue;

      final real = HWSize(width, height);
      final want = [
        for (final instance in grid.instances)
          instance.renderAtAndroid(real, table),
      ];
      final closest = HWAndroidSizeGrid.pickClosest(corners, real);
      final largest = HWAndroidSizeGrid.pickLargest(corners, real);
      for (final picked in [closest, largest]) {
        if (_sameRender(rendered[picked]!, want)) continue;
        if (allowNonNesting && _nonNestingFit(table, real)) continue;
        mismatches.add('$real picked $picked -> ${rendered[picked]} '
            'instead of $want');
      }

      if (grid.instances
          .any((instance) => instance.androidSizeRangeAt(real) == null)) {
        final today = HWAndroidSizeGrid.fittingFamilySize(table, real);
        if (today != null &&
            (closest.width < today.width || closest.height < today.height)) {
          fidelity.add('$real composes at $closest, below today\'s $today');
        }
      }
    }
  }

  expect(mismatches, isEmpty);
  expect(fidelity, isEmpty);
}

void main() {
  group('HWAndroidSizeGrid', () {
    group('the platform pick rule', () {
      test('sortedBySize orders by area, then by width', () {
        expect(
          HWAndroidSizeGrid.sortedBySize(const [
            HWSize(250, 250),
            HWSize(110, 110),
            HWSize(250, 110),
            HWSize(110, 250),
          ]),
          const [
            HWSize(110, 110),
            HWSize(110, 250),
            HWSize(250, 110),
            HWSize(250, 250),
          ],
        );
      });

      test('fits allows the platform its dp of slack', () {
        expect(
          HWAndroidSizeGrid.fits(
            const HWSize(110, 110),
            const HWSize(110, 110),
          ),
          isTrue,
        );
        expect(
          HWAndroidSizeGrid.fits(
            const HWSize(110, 110),
            const HWSize(109.3, 110),
          ),
          isTrue,
        );
        expect(
          HWAndroidSizeGrid.fits(
            const HWSize(110, 110),
            const HWSize(108.3, 110),
          ),
          isFalse,
        );
        expect(
          HWAndroidSizeGrid.fits(
            const HWSize(110, 110),
            const HWSize(110, 108.3),
          ),
          isFalse,
        );
      });

      test('pickClosest takes the nearest fitting size', () {
        const sizes = [HWSize(110, 110), HWSize(250, 110), HWSize(250, 250)];
        expect(
          HWAndroidSizeGrid.pickClosest(sizes, const HWSize(276, 220)),
          const HWSize(250, 110),
        );
        expect(
          HWAndroidSizeGrid.pickClosest(sizes, const HWSize(276, 338)),
          const HWSize(250, 250),
        );
      });

      test('nothing fitting falls back to the smallest size', () {
        const sizes = [HWSize(250, 250), HWSize(110, 110), HWSize(250, 110)];
        expect(
          HWAndroidSizeGrid.pickClosest(sizes, const HWSize(80, 80)),
          const HWSize(110, 110),
        );
        expect(
          HWAndroidSizeGrid.pickLargest(sizes, const HWSize(80, 80)),
          const HWSize(110, 110),
        );
      });

      test('pickLargest takes the largest fitting size instead', () {
        const sizes = [HWSize(100, 50), HWSize(70, 70)];
        expect(
          HWAndroidSizeGrid.pickLargest(sizes, const HWSize(100, 100)),
          const HWSize(100, 50),
        );
        expect(
          HWAndroidSizeGrid.pickClosest(sizes, const HWSize(100, 100)),
          const HWSize(70, 70),
        );
      });

      test('familyAt names the family whose size is picked', () {
        final table = HWWidgetFamily.androidSizeTable();
        expect(
          HWAndroidSizeGrid.familyAt(table, const HWSize(276, 220)),
          HWWidgetFamily.systemMedium,
        );
        expect(
          HWAndroidSizeGrid.familyAt(table, const HWSize(80, 80)),
          HWWidgetFamily.systemSmall,
        );
        expect(
          HWAndroidSizeGrid.familyAt(const {}, const HWSize(80, 80)),
          isNull,
        );
      });

      test('fittingFamilySize is null where no family fits', () {
        final table = HWWidgetFamily.androidSizeTable();
        expect(
          HWAndroidSizeGrid.fittingFamilySize(table, const HWSize(276, 102)),
          isNull,
        );
        expect(
          HWAndroidSizeGrid.fittingFamilySize(table, const HWSize(276, 220)),
          const HWSize(250, 110),
        );
      });
    });

    group('the worked example', () {
      test('compiles to the nine corners of §5.1 with custom-font text', () {
        expect(_grid([_example]).sizes, const [
          HWSize(80, 80),
          HWSize(80, 121),
          HWSize(110, 121),
          HWSize(250, 121),
          HWSize(400, 200),
          HWSize(250, 250),
          HWSize(400, 250),
          HWSize(250, 530),
          HWSize(400, 530),
        ]);
      });

      test('compiles to the six corners of §4.4 without it', () {
        expect(
          _grid([_example], keepFamilyCompositionSize: false).sizes,
          const [
            HWSize(80, 80),
            HWSize(80, 121),
            HWSize(250, 121),
            HWSize(400, 200),
            HWSize(250, 250),
            HWSize(400, 250),
          ],
        );
      });

      test('every corner renders what §4.4 tabulates', () {
        final grid = _grid([_example], keepFamilyCompositionSize: false);
        expect(
          {
            for (final cell in grid.cells)
              cell.size: cell.renders.single.widget,
          },
          {
            const HWSize(80, 80): _strip,
            const HWSize(80, 121): _small,
            const HWSize(250, 121): _medium,
            const HWSize(400, 200): _dashboard,
            const HWSize(250, 250): _large,
            const HWSize(400, 250): _dashboard,
          },
        );
      });

      test('keeps every threshold the cells were cut along', () {
        final grid = _grid([_example]);
        expect(grid.widthThresholds, const [80.0, 110.0, 250.0, 400.0, 530.0]);
        expect(
          grid.heightThresholds,
          const [80.0, 110.0, 121.0, 200.0, 250.0, 530.0],
        );
      });

      test('the floor drops every threshold below the widget minimum', () {
        final grid = _grid([_example], minWidth: 260, minHeight: 130);
        expect(grid.widthThresholds, const [260.0, 400.0, 530.0]);
        expect(grid.heightThresholds, const [130.0, 200.0, 250.0, 530.0]);
      });

      test('a corner names the range or the family that decided', () {
        final grid = _grid([_example]);
        final strip = grid.cells.first.renders.single;
        expect(strip.range, same(_stripRange));
        expect(strip.family, isNull);

        final medium = grid.cells
            .firstWhere((cell) => cell.size == const HWSize(250, 121))
            .renders
            .single;
        expect(medium.range, isNull);
        expect(medium.family, HWWidgetFamily.systemMedium);
      });

      test('rule b keeps the corner a family slot is composed at', () {
        // 250 × 530 renders `large`, exactly like 250 × 250 below it, and is
        // only kept because dropping it would compose the slot at the smaller
        // corner.
        final grid = _grid([_example]);
        expect(grid.sizes, contains(const HWSize(250, 530)));
        expect(
          HWAndroidSizeGrid.fittingFamilySize(
            HWWidgetFamily.androidSizeTable(),
            const HWSize(260.3, 560.3),
          ),
          const HWSize(250, 530),
        );
        expect(
          _grid([_example], keepFamilyCompositionSize: false).sizes,
          isNot(contains(const HWSize(250, 530))),
        );
      });

      test('reports which ranges and slots are rendered', () {
        final grid = _grid([_example]);
        expect(grid.rendersRange(_stripRange), isTrue);
        expect(grid.rendersRange(_dashboardRange), isTrue);
        expect(grid.rendersWidget(_medium), isTrue);
        expect(
          grid.rendersRange(
            const HWAndroidSizeRange(minWidth: 4000, child: _narrow),
          ),
          isFalse,
        );
        expect(grid.rendersWidget(const HWText.fixed('nowhere')), isFalse);
      });

      test('a range an earlier one covers is never rendered', () {
        const shadowed = HWAndroidSizeRange(maxHeight: 100, child: _narrow);
        final grid = _grid([
          const HWSizeAdaptive(
            small: _small,
            large: _large,
            androidSizeRanges: [_stripRange, shadowed],
          ),
        ]);
        expect(grid.rendersRange(_stripRange), isTrue);
        expect(grid.rendersRange(shadowed), isFalse);
      });

      test('the maximum resize size clips the thresholds', () {
        final grid = _grid([_example], maxWidth: 399, maxHeight: 400);
        expect(grid.sizes, const [
          HWSize(80, 80),
          HWSize(80, 121),
          HWSize(110, 121),
          HWSize(250, 121),
          HWSize(250, 250),
        ]);
      });

      test('an unbounded maximum contributes no threshold', () {
        final grid = _grid([
          const HWSizeAdaptive(
            small: _small,
            large: _large,
            androidSizeRanges: [
              HWAndroidSizeRange(
                minHeight: 200,
                maxHeight: double.infinity,
                child: _strip,
              ),
            ],
          ),
        ]);
        expect(
          grid.sizes.map((size) => size.height),
          isNot(contains(double.infinity)),
        );
      });
    });

    group('every size on a 1 dp lattice', () {
      test('the worked example', () {
        _checkEverySize(_grid([_example]));
      });

      test('a second instance without ranges', () {
        final grid = _grid([_example, _footer]);
        expect(grid.sizes.length, 13);
        _checkEverySize(grid);
      });

      test('split compact and wide strips', () {
        final grid = _grid([_splitStrips]);
        expect(grid.sizes.length, 10);
        _checkEverySize(grid);
      });

      test('four ranges', () {
        final grid = _grid([_fourRanges]);
        expect(grid.sizes.length, 12);
        _checkEverySize(grid);
      });

      test('a medium moved to a size the others nest in', () {
        final grid = _grid(
          [_example],
          sizes: const {HWWidgetFamily.systemMedium: HWSize(300, 110)},
        );
        expect(grid.sizes.length, 11);
        _checkEverySize(grid);
      });

      test('a medium the small family does not nest in', () {
        final grid = _grid(
          [_example],
          sizes: const {HWWidgetFamily.systemMedium: HWSize(200, 100)},
        );
        _checkEverySize(grid, allowNonNesting: true);
      });

      test('two extra-large families that render differently', () {
        final grid = _grid([
          const HWSizeAdaptive(
            small: _small,
            medium: _medium,
            large: _large,
            extraLarge: _extraLarge,
            extraLargePortrait: _portrait,
            androidSizeRanges: [_stripRange],
          ),
        ]);
        _checkEverySize(grid, allowNonNesting: true);
      });

      test('a widget the launcher can shrink to one dp', () {
        final grid = _grid([_example], minWidth: 1, minHeight: 1);
        _checkEverySize(grid, minWidth: 1, minHeight: 1);
      });
    });
  });
}
