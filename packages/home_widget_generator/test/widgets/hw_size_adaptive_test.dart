import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_tree_parser.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

const _small = HWText.fixed('s');
const _medium = HWText.fixed('m');
const _large = HWText.fixed('l');
const _extraLarge = HWText.fixed('xl');
const _portrait = HWText.fixed('xlp');
const _circular = HWText.fixed('c');
const _rectangular = HWText.fixed('r');
const _inline = HWText.fixed('i');

const _allSystem = {
  HWWidgetFamily.systemSmall,
  HWWidgetFamily.systemMedium,
  HWWidgetFamily.systemLarge,
  HWWidgetFamily.systemExtraLarge,
  HWWidgetFamily.systemExtraLargePortrait,
};

const _allAccessory = {
  HWWidgetFamily.accessoryCircular,
  HWWidgetFamily.accessoryRectangular,
  HWWidgetFamily.accessoryInline,
};

/// Resolves [annotation] through the parser the generator uses, so decoding is
/// exercised on a real analyzer constant.
Future<HWWidget> parseWidget(String annotation) async {
  final file = File(
    p.join(
      Directory.current.path,
      'test',
      '.tmp_size_adaptive_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  group('HWSizeAdaptive', () {
    group('model', () {
      test('needs at least one slot', () {
        expect(HWSizeAdaptive.new, throwsA(isA<AssertionError>()));
      });

      test('branchesFor is false while the reachable families agree', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _large);
        expect(
          adaptive.branchesFor({
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.systemMedium,
          }),
          isFalse,
        );
        expect(
          adaptive.branchesFor({
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.systemLarge,
          }),
          isTrue,
        );
      });

      test('branchesFor is false for a family set nothing resolves for', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _large);
        expect(adaptive.branchesFor(_allAccessory), isFalse);
      });

      test('slotFor returns the slot as written', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          accessoryCircular: _circular,
        );
        expect(adaptive.slotFor(HWWidgetFamily.systemSmall), same(_small));
        expect(
          adaptive.slotFor(HWWidgetFamily.accessoryCircular),
          same(_circular),
        );
        expect(adaptive.slotFor(HWWidgetFamily.systemMedium), isNull);
        expect(adaptive.slotFor(HWWidgetFamily.accessoryInline), isNull);
      });

      test('resolve walks down to the next smaller system slot', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _large);
        expect(adaptive.resolve(HWWidgetFamily.systemSmall), same(_small));
        expect(adaptive.resolve(HWWidgetFamily.systemMedium), same(_small));
        expect(adaptive.resolve(HWWidgetFamily.systemLarge), same(_large));
        expect(adaptive.resolve(HWWidgetFamily.systemExtraLarge), same(_large));
        expect(
          adaptive.resolve(HWWidgetFamily.systemExtraLargePortrait),
          same(_large),
        );
      });

      test('resolve skips the landscape extra-large for the portrait one', () {
        const adaptive =
            HWSizeAdaptive(medium: _medium, extraLarge: _extraLarge);
        expect(
          adaptive.resolve(HWWidgetFamily.systemExtraLarge),
          same(_extraLarge),
        );
        expect(
          adaptive.resolve(HWWidgetFamily.systemExtraLargePortrait),
          same(_medium),
        );
      });

      test('resolve returns null when no slot is below a family', () {
        const adaptive = HWSizeAdaptive(large: _large);
        expect(adaptive.resolve(HWWidgetFamily.systemSmall), isNull);
        expect(adaptive.resolve(HWWidgetFamily.systemMedium), isNull);
        expect(adaptive.resolve(HWWidgetFamily.systemLarge), same(_large));
      });

      test('accessory families never fall back', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          accessoryCircular: _circular,
        );
        expect(
          adaptive.resolve(HWWidgetFamily.accessoryCircular),
          same(_circular),
        );
        expect(adaptive.resolve(HWWidgetFamily.accessoryRectangular), isNull);
        expect(adaptive.resolve(HWWidgetFamily.accessoryInline), isNull);
      });

      test('familiesResolvingTo names the families rendering one slot', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _large);
        expect(
          adaptive.familiesResolvingTo(_large, _allSystem),
          {
            HWWidgetFamily.systemLarge,
            HWWidgetFamily.systemExtraLarge,
            HWWidgetFamily.systemExtraLargePortrait,
          },
        );
        expect(
          adaptive.familiesResolvingTo(_small, _allSystem),
          {HWWidgetFamily.systemSmall, HWWidgetFamily.systemMedium},
        );
        expect(
          adaptive.familiesResolvingTo(_large, const [
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.systemMedium,
          ]),
          isEmpty,
        );
      });

      test('providedSlots and providedFamilies follow family order', () {
        const adaptive = HWSizeAdaptive(
          accessoryInline: _inline,
          medium: _medium,
          small: _small,
        );
        expect(adaptive.providedSlots, [_small, _medium, _inline]);
        expect(adaptive.providedFamilies, {
          HWWidgetFamily.systemSmall,
          HWWidgetFamily.systemMedium,
          HWWidgetFamily.accessoryInline,
        });
      });

      test('childWidgets and dataDependencies cover every slot', () {
        const adaptive = HWSizeAdaptive(
          small: HWText(HWString('smallKey')),
          large: HWText(HWString('largeKey')),
        );
        expect(adaptive.childWidgets.length, 2);
        expect(
          adaptive.dataDependencies.map((d) => d.key).toSet(),
          {'smallKey', 'largeKey'},
        );
      });
    });

    group('imports and view properties', () {
      test('a single slot needs neither the environment nor LocalSize', () {
        const adaptive = HWSizeAdaptive(small: _small);
        expect(adaptive.swiftViewModifiers, isEmpty);
        expect(
          adaptive.kotlinImports,
          isNot(contains('import androidx.glance.LocalSize')),
        );
      });

      test('the same widget in two slots stays degenerate', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _small);
        expect(adaptive.swiftViewModifiers, isEmpty);
        expect(
          adaptive.kotlinImports,
          isNot(contains('import androidx.glance.LocalSize')),
        );
      });

      test('distinct slots declare widgetFamily and the Glance size imports',
          () {
        const adaptive = HWSizeAdaptive(small: _small, large: _large);
        expect(
          adaptive.swiftViewModifiers,
          contains('@Environment(\\.widgetFamily) var widgetFamily'),
        );
        expect(
          adaptive.kotlinImports,
          containsAll([
            'import androidx.glance.LocalSize',
            'import androidx.compose.ui.unit.DpSize',
            'import androidx.compose.ui.unit.dp',
            'import androidx.glance.text.Text',
          ]),
        );
      });

      test('accessory slots alone never pull in the Glance size imports', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          accessoryCircular: _circular,
          accessoryInline: _inline,
        );
        expect(
          adaptive.swiftViewModifiers,
          contains('@Environment(\\.widgetFamily) var widgetFamily'),
        );
        expect(
          adaptive.kotlinImports,
          isNot(contains('import androidx.glance.LocalSize')),
        );
      });

      test('slot modifiers and imports are unioned in', () {
        const adaptive = HWSizeAdaptive(
          small: HWText.fixed(
            'x',
            style: HWTextStyle(
              color: HWThemedColor(
                light: HWFixedColor(0xFF000000),
                dark: HWFixedColor(0xFFFFFFFF),
              ),
            ),
          ),
        );
        expect(
          adaptive.swiftViewModifiers,
          contains('@Environment(\\.colorScheme) var colorScheme'),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('a single reachable widget collapses to no switch', () {
        const adaptive = HWSizeAdaptive(small: _small);
        expect(adaptive.toSwift(0, dataExpr: 'd'), 'Text("s")');
      });

      test('families resolving to the same widget collapse too', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _small);
        expect(adaptive.toSwift(0, dataExpr: 'd'), 'Text("s")');
      });

      test('without a context only the provided families are switched over',
          () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          large: _large,
        );
        expect(adaptive.toSwift(0, dataExpr: 'd'), '''
switch widgetFamily {
case .systemMedium:
    Text("m")
case .systemLarge:
    Text("l")
default:
    Text("s")
}''');
      });

      test('a context groups the families it reaches by identity', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          large: _large,
        );
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(reachableFamilies: _allSystem),
          ),
          '''
switch widgetFamily {
case .systemMedium:
    Text("m")
case .systemLarge, .systemExtraLarge:
    Text("l")
#if compiler(>=6.4)
case .systemExtraLargePortrait:
    Text("l")
#endif
default:
    Text("s")
}''',
        );
      });

      test('the portrait extra-large keeps its own gated case', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          extraLarge: _extraLarge,
          extraLargePortrait: _portrait,
        );
        expect(adaptive.toSwift(0, dataExpr: 'd'), '''
switch widgetFamily {
case .systemExtraLarge:
    Text("xl")
#if compiler(>=6.4)
case .systemExtraLargePortrait:
    Text("xlp")
#endif
default:
    Text("s")
}''');
      });

      test('the gated case can be the only case', () {
        const adaptive = HWSizeAdaptive(small: _small, medium: _medium);
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemExtraLargePortrait,
              },
            ),
          ),
          '''
switch widgetFamily {
#if compiler(>=6.4)
case .systemExtraLargePortrait:
    Text("m")
#endif
default:
    Text("s")
}''',
        );
      });

      test('a portrait resolving to the default is not listed', () {
        const adaptive = HWSizeAdaptive(small: _small, extraLarge: _extraLarge);
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemExtraLarge,
                HWWidgetFamily.systemExtraLargePortrait,
              },
            ),
          ),
          '''
switch widgetFamily {
case .systemExtraLarge:
    Text("xl")
default:
    Text("s")
}''',
        );
      });

      test('the default branch is the smallest reachable system family', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          large: _large,
        );
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemMedium,
                HWWidgetFamily.systemLarge,
              },
            ),
          ),
          '''
switch widgetFamily {
case .systemLarge:
    Text("l")
default:
    Text("m")
}''',
        );
      });

      test('an accessory-only widget defaults to its first accessory family',
          () {
        const adaptive = HWSizeAdaptive(
          accessoryCircular: _circular,
          accessoryRectangular: _rectangular,
          accessoryInline: _inline,
        );
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(reachableFamilies: _allAccessory),
          ),
          '''
switch widgetFamily {
case .accessoryRectangular:
    Text("r")
case .accessoryInline:
    Text("i")
default:
    Text("c")
}''',
        );
      });

      test('a system family wins the default over an accessory one', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          accessoryCircular: _circular,
        );
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.accessoryCircular,
                HWWidgetFamily.systemSmall,
              },
            ),
          ),
          '''
switch widgetFamily {
case .accessoryCircular:
    Text("c")
default:
    Text("s")
}''',
        );
      });

      test('a family without content is left out', () {
        const adaptive =
            HWSizeAdaptive(large: _large, accessoryInline: _inline);
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemLarge,
                HWWidgetFamily.accessoryInline,
              },
            ),
          ),
          '''
switch widgetFamily {
case .accessoryInline:
    Text("i")
default:
    Text("l")
}''',
        );
      });

      test('no reachable family emits the first provided slot', () {
        const adaptive = HWSizeAdaptive(small: _small, large: _large);
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(reachableFamilies: {}),
          ),
          'Text("s")',
        );
      });

      test('the switch carries the indent and nests its children', () {
        const adaptive = HWSizeAdaptive(small: _small, medium: _medium);
        expect(adaptive.toSwift(2, dataExpr: 'd'), '''
        switch widgetFamily {
        case .systemMedium:
            Text("m")
        default:
            Text("s")
        }''');
      });

      test('the context reaches the slots', () {
        const adaptive = HWSizeAdaptive(
          small: HWColumn(
            children: [
              HWSizeAdaptive(small: _small, medium: _medium),
            ],
          ),
        );
        expect(
          adaptive.toSwift(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {HWWidgetFamily.systemSmall},
            ),
          ),
          '''
VStack(alignment: .center, spacing: 0) {
    Text("s")
}''',
        );
      });
    });

    group('Android (Glance)', () {
      test('a single reachable widget collapses to no when', () {
        const adaptive = HWSizeAdaptive(small: _small);
        expect(
          adaptive.toKotlin(0, dataExpr: 'd'),
          'Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
      });

      test('branches compare against the declared sizes', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          large: _large,
        );
        expect(adaptive.toKotlin(0, dataExpr: 'd'), '''
when (LocalSize.current) {
    DpSize(250.dp, 110.dp) -> {
        Text(text = "m", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
    DpSize(250.dp, 250.dp) -> {
        Text(text = "l", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
    else -> {
        Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''');
      });

      test('families sharing a widget share one branch', () {
        const adaptive = HWSizeAdaptive(small: _small, medium: _medium);
        expect(
          adaptive.toKotlin(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemMedium,
                HWWidgetFamily.systemLarge,
              },
            ),
          ),
          '''
when (LocalSize.current) {
    DpSize(250.dp, 110.dp), DpSize(250.dp, 250.dp) -> {
        Text(text = "m", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
    else -> {
        Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''',
        );
      });

      test('accessory families are never emitted', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          accessoryCircular: _circular,
        );
        final kotlin = adaptive.toKotlin(
          0,
          dataExpr: 'd',
          context: const HWEmitContext(
            reachableFamilies: {
              HWWidgetFamily.systemSmall,
              HWWidgetFamily.systemMedium,
              HWWidgetFamily.accessoryCircular,
            },
          ),
        );
        expect(kotlin, isNot(contains('"c"')));
        expect(kotlin, contains('DpSize(250.dp, 110.dp) -> {'));
      });

      test('no reachable system family emits the first provided slot', () {
        const adaptive = HWSizeAdaptive(
          accessoryCircular: _circular,
          accessoryInline: _inline,
        );
        expect(
          adaptive.toKotlin(0, dataExpr: 'd'),
          'Text(text = "c", style = TextStyle(color = GlanceTheme.colors.onSurface))',
        );
      });

      test('androidSizes replaces the declared size of a family', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(200, 100)},
        );
        expect(adaptive.toKotlin(0, dataExpr: 'd'), '''
when (LocalSize.current) {
    DpSize(200.dp, 100.dp) -> {
        Text(text = "m", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
    else -> {
        Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''');
      });

      test('an empty context table means the defaults, not androidSizes', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(200, 100)},
        );
        expect(
          adaptive.toKotlin(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemMedium,
              },
              androidSizeTable: {},
            ),
          ),
          contains('DpSize(250.dp, 110.dp) -> {'),
        );
      });

      test('a context without a table leaves androidSizes alone', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(200, 100)},
        );
        expect(
          adaptive.toKotlin(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemMedium,
              },
            ),
          ),
          contains('DpSize(200.dp, 100.dp) -> {'),
        );
      });

      test('a context size table wins over androidSizes', () {
        const adaptive = HWSizeAdaptive(
          small: _small,
          medium: _medium,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(200, 100)},
        );
        expect(
          adaptive.toKotlin(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {
                HWWidgetFamily.systemSmall,
                HWWidgetFamily.systemMedium,
              },
              androidSizeTable: {
                HWWidgetFamily.systemMedium: HWSize(300, 112.5),
              },
            ),
          ),
          '''
when (LocalSize.current) {
    DpSize(300.dp, 112.5.dp) -> {
        Text(text = "m", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
    else -> {
        Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''',
        );
      });

      test('the when carries the indent and nests its children', () {
        const adaptive = HWSizeAdaptive(small: _small, medium: _medium);
        expect(adaptive.toKotlin(1, dataExpr: 'd'), '''
    when (LocalSize.current) {
        DpSize(250.dp, 110.dp) -> {
            Text(text = "m", style = TextStyle(color = GlanceTheme.colors.onSurface))
        }
        else -> {
            Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))
        }
    }''');
      });

      test('the context reaches the slots', () {
        const adaptive = HWSizeAdaptive(
          small: HWColumn(
            children: [
              HWSizeAdaptive(small: _small, medium: _medium),
            ],
          ),
        );
        expect(
          adaptive.toKotlin(
            0,
            dataExpr: 'd',
            context: const HWEmitContext(
              reachableFamilies: {HWWidgetFamily.systemSmall},
            ),
          ),
          '''
Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text(text = "s", style = TextStyle(color = GlanceTheme.colors.onSurface))
}''',
        );
      });

      test('kotlinSizeMode declares every size it is given', () {
        expect(
          HWSizeAdaptive.kotlinSizeMode(
            const [HWSize(250, 110), HWSize(250, 250)],
          ),
          '''
  override val sizeMode = SizeMode.Responsive(
      setOf(
          DpSize(250.dp, 110.dp),
          DpSize(250.dp, 250.dp),
      )
  )''',
        );
      });

      test('kotlinSizeMode with no size declares an empty set', () {
        expect(
          HWSizeAdaptive.kotlinSizeMode(const []),
          '''
  override val sizeMode = SizeMode.Responsive(
      setOf(
      )
  )''',
        );
      });
    });

    group('equality', () {
      test('compares every slot', () {
        expect(
          const HWSizeAdaptive(small: _small, medium: _medium),
          const HWSizeAdaptive(small: _small, medium: _medium),
        );
        expect(
          const HWSizeAdaptive(small: _small),
          isNot(const HWSizeAdaptive(medium: _small)),
        );
        expect(
          const HWSizeAdaptive(small: _small, accessoryInline: _inline),
          isNot(const HWSizeAdaptive(small: _small)),
        );
      });

      test('hashes without a size table', () {
        expect(
          const HWSizeAdaptive(small: _small, medium: _medium).hashCode,
          const HWSizeAdaptive(small: _small, medium: _medium).hashCode,
        );
      });

      test('androidSizes compare and hash regardless of order', () {
        const a = HWSizeAdaptive(
          small: _small,
          androidSizes: {
            HWWidgetFamily.systemMedium: HWSize(200, 100),
            HWWidgetFamily.systemLarge: HWSize(200, 200),
          },
        );
        const b = HWSizeAdaptive(
          small: _small,
          androidSizes: {
            HWWidgetFamily.systemLarge: HWSize(200, 200),
            HWWidgetFamily.systemMedium: HWSize(200, 100),
          },
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('a different or missing size table breaks equality', () {
        const withSizes = HWSizeAdaptive(
          small: _small,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(200, 100)},
        );
        const otherSize = HWSizeAdaptive(
          small: _small,
          androidSizes: {HWWidgetFamily.systemMedium: HWSize(200, 110)},
        );
        const otherFamily = HWSizeAdaptive(
          small: _small,
          androidSizes: {HWWidgetFamily.systemLarge: HWSize(200, 100)},
        );
        const oneMore = HWSizeAdaptive(
          small: _small,
          androidSizes: {
            HWWidgetFamily.systemMedium: HWSize(200, 100),
            HWWidgetFamily.systemLarge: HWSize(200, 200),
          },
        );
        expect(withSizes, isNot(const HWSizeAdaptive(small: _small)));
        expect(withSizes, isNot(otherSize));
        expect(withSizes, isNot(otherFamily));
        expect(withSizes, isNot(oneMore));
      });
    });

    group('parser integration', () {
      test('decodes every slot', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    medium: HWText.fixed('medium'),
    large: HWColumn(children: [HWText.fixed('large')]),
    extraLarge: HWText.fixed('extraLarge'),
    extraLargePortrait: HWText.fixed('portrait'),
    accessoryCircular: HWText.fixed('circular'),
    accessoryRectangular: HWText.fixed('rectangular'),
    accessoryInline: HWText.fixed('inline'),
  ),
)''');

        expect(widget, isA<HWSizeAdaptive>());
        final adaptive = widget as HWSizeAdaptive;
        expect((adaptive.small! as HWText).fixedContent, 'small');
        expect((adaptive.medium! as HWText).fixedContent, 'medium');
        expect(adaptive.large, isA<HWColumn>());
        expect((adaptive.extraLarge! as HWText).fixedContent, 'extraLarge');
        expect(
          (adaptive.extraLargePortrait! as HWText).fixedContent,
          'portrait',
        );
        expect(
          (adaptive.accessoryCircular! as HWText).fixedContent,
          'circular',
        );
        expect(
          (adaptive.accessoryRectangular! as HWText).fixedContent,
          'rectangular',
        );
        expect((adaptive.accessoryInline! as HWText).fixedContent, 'inline');
        expect(adaptive.androidSizes, isNull);
      });

      test('decodes androidSizes', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveSizesWidget',
  widget: HWSizeAdaptive(
    medium: HWText.fixed('medium'),
    large: HWText.fixed('large'),
    androidSizes: {
      HWWidgetFamily.systemMedium: HWSize(200, 100),
      HWWidgetFamily.systemLarge: HWSize(200.5, 200),
    },
  ),
)''');

        final adaptive = widget as HWSizeAdaptive;
        expect(adaptive.androidSizes, {
          HWWidgetFamily.systemMedium: const HWSize(200, 100),
          HWWidgetFamily.systemLarge: const HWSize(200.5, 200),
        });
      });

      test('decodes an androidSizes key by name', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveNamedKeyWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizes: {HWWidgetFamily.systemExtraLargePortrait: HWSize(250, 530)},
  ),
)''');

        expect((widget as HWSizeAdaptive).androidSizes, {
          HWWidgetFamily.systemExtraLargePortrait: const HWSize(250, 530),
        });
      });

      test('rejects an androidSizes value that is not an HWSize', () async {
        await expectLater(
          parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveBadSizeWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizes: {HWWidgetFamily.systemMedium: null},
  ),
)'''),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('systemMedium a value that is not an HWSize'),
            ),
          ),
        );
      });

      test('rejects an androidSizes key that is not an HWWidgetFamily',
          () async {
        await expectLater(
          parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveBadKeyWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizes: {null: HWSize(200, 100)},
  ),
)'''),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('has a key that is not an HWWidgetFamily'),
            ),
          ),
        );
      });

      test('an empty androidSizes map decodes as none', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveEmptySizesWidget',
  widget: HWSizeAdaptive(
    small: HWText.fixed('small'),
    androidSizes: {},
  ),
)''');

        expect((widget as HWSizeAdaptive).androidSizes, isNull);
      });

      test('decodes data dependencies from every slot', () async {
        final widget = await parseWidget('''
@HomeWidget(
  name: 'SizeAdaptiveDataWidget',
  widget: HWSizeAdaptive(
    small: HWText(HWString('smallKey')),
    accessoryInline: HWText(HWString('inlineKey')),
  ),
)''');

        expect(
          widget.dataDependencies.map((d) => d.key).toSet(),
          {'smallKey', 'inlineKey'},
        );
      });
    });
  });
}
