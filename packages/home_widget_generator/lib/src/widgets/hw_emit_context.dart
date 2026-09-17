import '../annotations.dart';
import 'hw_size.dart';

/// The axis a Glance `Column` or `Row` lays its children out along.
enum HWAxis { vertical, horizontal }

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

  const HWEmitContext({
    this.reachableFamilies,
    this.androidSizeTable,
    this.enclosingLinearAxis,
  });

  /// This context, for a widget the Glance `Column` or `Row` running along
  /// [axis] lays out, or one laid out by something else when it is null.
  HWEmitContext inLinear(HWAxis? axis) => HWEmitContext(
        reachableFamilies: reachableFamilies,
        androidSizeTable: androidSizeTable,
        enclosingLinearAxis: axis,
      );
}
