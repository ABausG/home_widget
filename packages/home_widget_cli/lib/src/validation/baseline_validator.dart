import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';
import '../util/logger.dart';

/// Warns about an [HWRow] asking for [HWCrossAxisAlignment.baseline] that
/// Android cannot line up.
///
/// A row lines its children up by the text they render, and needs two of them
/// to have a line to share. With fewer, Android leaves every child at the top
/// of the row while iOS still puts the bottom edge of a child rendering no text
/// — a picture, an icon — on the baseline of the one that does, so the two
/// platforms read differently.
void validateBaselineRows(WidgetSpec spec) {
  if (spec.data.android == null) return;

  for (final widget in spec.effectiveWidgetTree.descendants) {
    if (widget is! HWRow) continue;
    if (widget.effectiveCrossAxisAlignment != HWCrossAxisAlignment.baseline) {
      continue;
    }

    final texts =
        widget.children.where((child) => child.kotlinBaselineText != null);
    if (texts.length >= 2) continue;

    final how = texts.isEmpty ? 'no child' : 'only one child';
    logger.warn(
      'Warning: Widget "${spec.data.name}": an HWRow with '
      'HWCrossAxisAlignment.baseline has $how rendering text of its own. '
      'Android has no baseline to line the children up on and leaves them at '
      'the top of the row, while iOS still aligns them on the first text '
      'baseline.',
    );
  }
}
