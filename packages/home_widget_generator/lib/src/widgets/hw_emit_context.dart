import '../annotations.dart';
import 'hw_size.dart';

/// The axis a Glance `Column` or `Row` lays its children out along.
enum HWAxis { vertical, horizontal }

/// The room the outermost Glance composable of a widget asks for.
///
/// A `Box` a stack wraps around a child takes the child's place in the stack,
/// so it asks for the same room, and the child, laid out by the `Box` now,
/// fills it.
class HWKotlinRoom {
  /// Whether it takes a weight along the main axis of the Glance `Column` or
  /// `Row` it sits in.
  final bool weight;

  /// Whether it takes the whole width it is given.
  final bool fillsWidth;

  /// Whether it takes the whole height it is given.
  final bool fillsHeight;

  const HWKotlinRoom({
    this.weight = false,
    this.fillsWidth = false,
    this.fillsHeight = false,
  });

  /// The `GlanceModifier` calls asking for this room, in chain order.
  List<String> get modifiers => [
        if (weight) 'defaultWeight()',
        if (fillsWidth && fillsHeight)
          'fillMaxSize()'
        else if (fillsWidth)
          'fillMaxWidth()'
        else if (fillsHeight)
          'fillMaxHeight()',
      ];

  /// The imports [modifiers] need. `defaultWeight()` needs none: it is a
  /// member of the `ColumnScope` or `RowScope` it is called in.
  Set<String> get kotlinImports => {
        if (fillsWidth && fillsHeight)
          'import androidx.glance.layout.fillMaxSize'
        else if (fillsWidth)
          'import androidx.glance.layout.fillMaxWidth'
        else if (fillsHeight)
          'import androidx.glance.layout.fillMaxHeight',
      };
}

/// What the emitters need to know about the platform a tree is generated for.
///
/// [HWSizeAdaptive] switches over the families a widget can actually be shown
/// in, which the annotation decides and only the caller knows; a tree emitted
/// without a context falls back to the families it has content for.
class HWEmitContext {
  /// The families the widget can be shown in on the platform being emitted, or
  /// null when only the content a tree has decides.
  final Set<HWWidgetFamily>? reachableFamilies;

  /// The dp size declared for each system family, overrides applied, or null
  /// when the caller has no resolved table of its own.
  ///
  /// Always null on iOS.
  final Map<HWWidgetFamily, HWSize>? androidSizeTable;

  /// The axis of the Glance `Column` or `Row` this is emitted directly inside,
  /// or null when the nearest enclosing composable is not one.
  ///
  /// A Glance linear container is a `LinearLayout` whose children are laid out
  /// at weight 0, so a child asking for the whole main axis takes every pixel
  /// and leaves its siblings none; along that axis a weight is what asks for
  /// the same room without starving them.
  final HWAxis? enclosingLinearAxis;

  /// The key of the list whose item this is emitted inside, or null outside
  /// the item of every `HWColumn.builder` and `HWRow.builder`.
  ///
  /// The same code renders every item, so whatever it keys by itself — the
  /// room an Android custom font text is measured to have — takes the list and
  /// the item's index into the key.
  final String? itemList;

  const HWEmitContext({
    this.reachableFamilies,
    this.androidSizeTable,
    this.enclosingLinearAxis,
    this.itemList,
  });

  /// This context, for a widget the Glance `Column` or `Row` running along
  /// [axis] lays out, or one laid out by something else when it is null.
  HWEmitContext inLinear(HWAxis? axis) => HWEmitContext(
        reachableFamilies: reachableFamilies,
        androidSizeTable: androidSizeTable,
        enclosingLinearAxis: axis,
        itemList: itemList,
      );

  /// This context, for the item of the builder over [list].
  HWEmitContext inItemOf(String list) => HWEmitContext(
        reachableFamilies: reachableFamilies,
        androidSizeTable: androidSizeTable,
        enclosingLinearAxis: enclosingLinearAxis,
        itemList: list,
      );
}
