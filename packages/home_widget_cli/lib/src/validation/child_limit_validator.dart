import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';
import '../util/logger.dart';

/// The most children Glance lays out in one `Column` or `Row`.
///
/// Its container layouts hold ten child stubs, and it drops every child past
/// them, only logging that it truncated the container.
const int glanceChildLimit = 10;

/// The most custom font texts the core plugin measures the room of per widget
/// size, `MAX_MEASURE_ROUNDS` in `HomeWidgetFonts.kt`.
const int measuredTextLimit = 32;

/// Rejects an [HWColumn] or [HWRow] Android would render with more children
/// than Glance lays out.
///
/// Every spacer a `mainAxisAlignment` adds is a child to Glance as well, while
/// `spacing` is padding and a child rendering nothing, like [HWDataOnly], is
/// not there at all. A builder's children are its items, so it needs a
/// `maxItems` bounding them.
void validateChildLimits(WidgetSpec spec) {
  if (spec.data.android == null) return;

  for (final widget in spec.androidRenderedWidgets) {
    if (widget is! HWMultiChildWidget) continue;
    if (widget.item case final item?) {
      _validateBuilder(spec, widget, item);
      continue;
    }

    final children =
        widget.children.where((child) => !child.kotlinRendersNothing).length;
    final alignment = widget.mainAxisAlignment;
    final spacers = alignment.spacerCount(children);
    final total = children + spacers;
    if (total <= glanceChildLimit) continue;

    final stack = widget is HWColumn ? 'Column' : 'Row';
    final name = (alignment ?? HWMainAxisAlignment.start).name;
    final spacerNoun = spacers == 1 ? 'spacer' : 'spacers';
    final fewerSpacers = spacers == 0
        ? ''
        : ', or use a mainAxisAlignment that adds fewer spacers';
    throw GeneratorError(
      'Widget "${spec.data.name}": an HW$stack has $children children + '
      '$spacers $spacerNoun ($name) = $total > $glanceChildLimit. On Android, '
      'Glance lays out at most $glanceChildLimit children in a $stack, '
      'spacers included, and silently drops the rest. Group some children in '
      'a nested HWColumn or HWRow, which counts as one child$fewerSpacers.',
    );
  }
}

/// Rejects a builder that can render more items than Glance lays out, or that
/// leaves the number of items open.
///
/// While the list is empty, the builder renders its `whenEmpty` alone, which
/// with the spacers of any alignment stays well within the limit.
void _validateBuilder(
  WidgetSpec spec,
  HWMultiChildWidget builder,
  HWWidget item,
) {
  if (item.kotlinRendersNothing) return;

  final stack = builder is HWColumn ? 'Column' : 'Row';
  final spelling = "HW$stack.builder('${builder.list}')";
  final alignment = builder.mainAxisAlignment;
  final name = (alignment ?? HWMainAxisAlignment.start).name;
  final largest = _largestFitting(alignment);
  final limit = 'On Android, Glance lays out at most $glanceChildLimit '
      'children in a $stack, spacers included, and silently drops the rest';

  final maxItems = builder.maxItems;
  if (maxItems == null) {
    throw GeneratorError(
      'Widget "${spec.data.name}": $spelling has no maxItems. $limit, so a '
      'builder needs maxItems there: at most $largest items fit a $stack with '
      'mainAxisAlignment $name.',
    );
  }

  final spacers = alignment.spacerCount(maxItems);
  final total = maxItems + spacers;
  if (total <= glanceChildLimit) return;

  final alternative = _alignmentFitting(maxItems);
  throw GeneratorError(
    'Widget "${spec.data.name}": $spelling renders up to $maxItems items + '
    '$spacers ${spacers == 1 ? 'spacer' : 'spacers'} ($name) = $total > '
    '$glanceChildLimit. $limit. Use maxItems $largest'
    '${alternative == null ? '' : ', or mainAxisAlignment ${alternative.name}'}'
    '.',
  );
}

/// The most items a builder aligned by [alignment] can render within the
/// limit, spacers included.
int _largestFitting(HWMainAxisAlignment? alignment) {
  var items = glanceChildLimit;
  while (items + alignment.spacerCount(items) > glanceChildLimit) {
    items--;
  }
  return items;
}

/// The alignment adding the most spacers that [items] items still fit with,
/// the closest there is to spreading them out, or null when none does.
HWMainAxisAlignment? _alignmentFitting(int items) {
  HWMainAxisAlignment? fitting;
  for (final alignment in HWMainAxisAlignment.values) {
    final spacers = alignment.spacerCount(items);
    if (items + spacers > glanceChildLimit) continue;
    if (fitting == null || spacers > fitting.spacerCount(items)) {
      fitting = alignment;
    }
  }
  return fitting;
}

/// Warns about a widget whose Android layout can hold more custom font texts
/// than the core plugin measures the room of.
///
/// Every text in a custom font is measured under a key of its own before it is
/// drawn, and one inside the item of a builder once per item. Past
/// [measuredTextLimit] keys the rest are drawn against the bounds of the whole
/// widget. The count is an upper bound: it adds up the texts of every slot and
/// branch Android can render, where one size only ever renders one of them.
void validateMeasuredTexts(WidgetSpec spec) {
  if (spec.data.android == null) return;

  var texts = 0;
  for (final widget in spec.androidRenderedWidgets) {
    if (androidMeasuresText(widget)) texts++;
    if (widget case HWMultiChildWidget(:final item?, :final maxItems?)) {
      final perItem =
          spec.androidRenderedWithin(item).where(androidMeasuresText).length;
      texts += perItem * (maxItems - 1);
    }
  }
  if (texts <= measuredTextLimit) return;

  logger.warn(
    'Warning: Widget "${spec.data.name}": its Android layout can render up to '
    '$texts texts in a custom font, counting a text in the item of a builder '
    'once per item, but Android measures the room of at most '
    '$measuredTextLimit of them per widget size. The rest are drawn against '
    'the bounds of the whole widget and can overflow their place. Lower the '
    'maxItems of a builder, or render some of the texts in the platform font.',
  );
}
