import '../annotations.dart';
import 'hw_size.dart';

/// What the emitters need to know about the platform a tree is generated for.
///
/// [HWSizeAdaptive] switches over the families a widget can actually be shown
/// in, which the annotation decides and only the caller knows; a tree emitted
/// without a context falls back to the families it has content for.
class HWEmitContext {
  /// The families the widget can be shown in on the platform being emitted.
  final Set<HWWidgetFamily> reachableFamilies;

  /// The dp size declared for each system family, overrides applied.
  ///
  /// Empty on iOS, and on Android whenever the caller has no resolved table of
  /// its own.
  final Map<HWWidgetFamily, HWSize> androidSizeTable;

  const HWEmitContext({
    required this.reachableFamilies,
    this.androidSizeTable = const {},
  });
}
