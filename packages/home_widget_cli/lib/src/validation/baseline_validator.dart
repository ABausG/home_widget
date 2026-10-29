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

  final context = spec.androidEmitContext;
  for (final widget in spec.androidRenderedWidgets) {
    if (widget is! HWRow) continue;
    if (widget.effectiveCrossAxisAlignment != HWCrossAxisAlignment.baseline) {
      continue;
    }

    final texts = _textsToLineUp(widget, context);
    if (texts >= 2) continue;

    final row = switch (widget.list) {
      final list? => "HWRow.builder('$list')",
      null => 'an HWRow',
    };
    final how = texts == 0 ? 'no child' : 'only one child';
    logger.warn(
      'Warning: Widget "${spec.data.name}": $row with '
      'HWCrossAxisAlignment.baseline has $how rendering text of its own. '
      'Android has no baseline to line the children up on and leaves them at '
      'the top of the row, while iOS still aligns them on the first text '
      'baseline.',
    );
  }
}

/// How many children of [row] render text of their own.
///
/// A builder's item counts once per item it can render, and a builder without
/// `maxItems` as two, which is all a row needs to line its children up.
int _textsToLineUp(HWRow row, HWEmitContext context) {
  final item = row.item;
  if (item == null) {
    return row.children
        .where((child) => child.kotlinBaselineText(context) != null)
        .length;
  }
  if (item.kotlinBaselineText(context) == null) return 0;
  return row.maxItems ?? 2;
}
