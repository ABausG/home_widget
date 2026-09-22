import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

const _strip = HWText.fixed('strip');
const _other = HWText.fixed('other');

/// Resolves [annotation] through the parser the generator uses, so decoding is
/// exercised on a real analyzer constant.
Future<HWWidget> parseWidget(String annotation) async {
  final file = File(
    p.join(
      Directory.current.path,
      'test',
      '.tmp_android_range_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  await file.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

$annotation
class Fixture {}
''');

  try {
    final collection = AnalysisContextCollection(
      includedPaths: [file.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final context = collection.contextFor(file.path);
    final result = await context.currentSession.getResolvedUnit(file.path);

    if (result is! ResolvedUnitResult) {
      throw StateError('Failed to resolve');
    }

    final element = result.unit.declaredFragment!.element.classes.first;
    final metadata = element.metadata.annotations.firstWhere(
      (m) => m.element?.enclosingElement?.name == 'HomeWidget',
    );

    return WidgetTreeParser(metadata).parse();
  } finally {
    if (await file.exists()) await file.delete();
  }
}

void main() {
  group('HWAndroidSizeRange', () {
    group('model', () {
      test('needs at least one bound', () {
        expect(
          () => HWAndroidSizeRange(child: _strip),
          throwsA(isA<AssertionError>()),
        );
      });

      test('matches inclusively, in whole dp', () {
        const range = HWAndroidSizeRange(
          minWidth: 400,
          maxHeight: 120,
          child: _strip,
        );
        expect(range.matches(const HWSize(400, 40)), isTrue);
        expect(range.matches(const HWSize(400, 120.9)), isTrue);
        expect(range.matches(const HWSize(399.9, 120)), isFalse);
        expect(range.matches(const HWSize(400, 121)), isFalse);
      });

      test('a fractional bound moves to the whole dp beside it', () {
        const range = HWAndroidSizeRange(
          minHeight: 400.5,
          maxWidth: 249.5,
          child: _strip,
        );
        expect(range.matches(const HWSize(249.9, 401)), isTrue);
        expect(range.matches(const HWSize(250, 401)), isFalse);
        expect(range.matches(const HWSize(249, 400.9)), isFalse);
      });

      test('an axis without bounds matches everything', () {
        const range = HWAndroidSizeRange(maxHeight: 120, child: _strip);
        expect(range.matches(const HWSize(40, 40)), isTrue);
        expect(range.matches(const HWSize(4000, 40)), isTrue);
        expect(range.matches(const HWSize(4000, 400)), isFalse);
      });

      test('the bounds name the grid thresholds they put down', () {
        const range = HWAndroidSizeRange(
          minWidth: 400,
          maxWidth: 529,
          minHeight: 200.5,
          maxHeight: 120,
          child: _strip,
        );
        expect(range.widthThresholds, [400, 530]);
        expect(range.heightThresholds, [201, 121]);
        expect(
          const HWAndroidSizeRange(minWidth: 400, child: _strip)
              .heightThresholds,
          isEmpty,
        );
      });

      test('equality and hashCode compare the bounds and the child', () {
        const range = HWAndroidSizeRange(maxHeight: 120, child: _strip);
        expect(range, const HWAndroidSizeRange(maxHeight: 120, child: _strip));
        expect(
          range.hashCode,
          const HWAndroidSizeRange(maxHeight: 120, child: _strip).hashCode,
        );
        expect(
          range,
          isNot(const HWAndroidSizeRange(maxHeight: 121, child: _strip)),
        );
        expect(
          range,
          isNot(const HWAndroidSizeRange(maxHeight: 120, child: _other)),
        );
        expect(
          range,
          isNot(const HWAndroidSizeRange(minWidth: 120, child: _strip)),
        );
        expect(
          const HWAndroidSizeRange(minHeight: 120, child: _strip),
          isNot(const HWAndroidSizeRange(maxHeight: 120, child: _strip)),
        );
        expect(
          const HWAndroidSizeRange(maxWidth: 120, child: _strip),
          isNot(const HWAndroidSizeRange(maxHeight: 120, child: _strip)),
        );
      });

      test('toString names the bounds that were written', () {
        expect(
          const HWAndroidSizeRange(
            minWidth: 400,
            maxWidth: 529.5,
            minHeight: 200,
            maxHeight: 120,
            child: _strip,
          ).toString(),
          'HWAndroidSizeRange(minWidth: 400, maxWidth: 529.5, '
          'minHeight: 200, maxHeight: 120)',
        );
        expect(
          const HWAndroidSizeRange(maxHeight: 120, child: _strip).toString(),
          'HWAndroidSizeRange(maxHeight: 120)',
        );
      });
    });

    group('parser integration', () {
      test('decodes the bounds and the child', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'RangeWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizeRanges: [
      HWAndroidSizeRange(maxHeight: 120, child: HWText.fixed('strip')),
      HWAndroidSizeRange(
        minWidth: 400,
        maxWidth: 529.5,
        minHeight: 200,
        child: HWColumn(children: [HWText.fixed('dashboard')]),
      ),
    ],
  ),
)''');

        final ranges = (widget as HWSizeAdaptive).androidSizeRanges!;
        expect(ranges.length, 2);
        expect(ranges.first.maxHeight, 120);
        expect(ranges.first.minWidth, isNull);
        expect((ranges.first.child as HWText).fixedContent, 'strip');
        expect(ranges.last.minWidth, 400);
        expect(ranges.last.maxWidth, 529.5);
        expect(ranges.last.minHeight, 200);
        expect(ranges.last.maxHeight, isNull);
        expect(ranges.last.child, isA<HWColumn>());
      });

      test('an empty list decodes as none', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'EmptyRangesWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizeRanges: [],
  ),
)''');

        expect((widget as HWSizeAdaptive).androidSizeRanges, isNull);
      });

      // The assertion is what a boundless range trips first: the annotation is
      // a constant, so it never reaches `fromDartObject`.
      test('a range without a single bound does not compile', () async {
        await expectLater(
          parseWidget('''
@HomeWidget(
  name: 'BoundlessRangeWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizeRanges: [HWAndroidSizeRange(child: HWText.fixed('strip'))],
  ),
)'''),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('Could not compute constant value'),
            ),
          ),
        );
      });

      test('rejects an entry that is not a range', () async {
        await expectLater(
          parseWidget('''
@HomeWidget(
  name: 'BadRangeEntryWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizeRanges: [null],
  ),
)'''),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('has an entry that is not an HWAndroidSizeRange'),
            ),
          ),
        );
      });
    });
  });
}
