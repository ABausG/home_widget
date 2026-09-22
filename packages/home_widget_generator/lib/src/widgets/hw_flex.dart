part of 'hw_widget.dart';

/// Base class for the stacks laying their children out along one axis, the
/// way Flutter's `Flex` sits behind `Column` and `Row`.
///
/// Holds what a main axis brings with it: the two alignments, the gap between
/// adjacent children, and the builder rendering one item per list entry.
sealed class HWFlex extends HWMultiChildWidget {
  /// How the children are placed along the cross axis.
  final HWCrossAxisAlignment? crossAxisAlignment;

  /// How the children are distributed along the main axis.
  final HWMainAxisAlignment? mainAxisAlignment;

  /// The gap between two adjacent children along the main axis, in logical
  /// pixels.
  ///
  /// Like Flutter's `Flex.spacing`: there is none before the first child or
  /// after the last, and [mainAxisAlignment] distributes the room left over on
  /// top of it.
  final double spacing;

  /// The key of the list a builder renders [item] once per entry of, or null
  /// for a stack of fixed [children].
  final String? list;

  /// The widget a builder renders once per list entry, the only subtree an
  /// [HWItemData] reads from, or null for a stack of fixed [children].
  final HWWidget? item;

  /// The most items a builder renders, or null for every one of them.
  final int? maxItems;

  /// What a builder renders as its only child while there is no item to
  /// render, or null for an empty stack.
  final HWWidget? whenEmpty;

  const HWFlex({
    required super.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
    this.spacing = 0,
  })  : list = null,
        item = null,
        maxItems = null,
        whenEmpty = null;

  const HWFlex.builder(
    String this.list, {
    required HWWidget this.item,
    this.maxItems,
    this.whenEmpty,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
    this.spacing = 0,
  }) : super(children: const []);

  /// Whether this stack renders [item] once per entry of [list], rather than
  /// fixed [children].
  bool get isBuilder => list != null;

  /// Every item field a builder's [item] reads, in the order they are first
  /// read, and empty for a stack of fixed [children].
  ///
  /// Each is an [HWItemData], or an [HWTimedData] around one, exactly as
  /// declared: two reads of one field declaring different `previewValues`
  /// both appear, for the caller to merge.
  List<HWDataType<dynamic>> get itemReads => [
        for (final dependency
            in item?.dataDependencies ?? const <HWDataType<dynamic>>{})
          if (dependency.unwrapped is HWItemData) dependency,
      ];

  /// The axis the children are laid out along.
  HWAxis get _mainAxis;

  /// The alignment this stack renders with, always emitted so that neither
  /// platform falls back to its own default.
  ///
  /// `baseline` lines up along a horizontal cross axis, which only a row has;
  /// [HWColumn.fromDartObject] rejects it, and both of a column's emitters
  /// centre on it.
  HWCrossAxisAlignment get effectiveCrossAxisAlignment =>
      crossAxisAlignment ?? HWCrossAxisAlignment.center;

  /// A builder's own reads are what its [item] reads of the widget's data,
  /// every item field left to [itemReads], plus what [whenEmpty] reads.
  @override
  Set<HWDataType<dynamic>> get dataDependencies {
    final item = this.item;
    if (item == null) return super.dataDependencies;
    return {
      ...item.dataDependencies
          .where((dependency) => dependency.unwrapped is! HWItemData),
      ...?whenEmpty?.dataDependencies,
    };
  }

  @override
  List<HWWidget> get childWidgets {
    final item = this.item;
    if (item == null) return super.childWidgets;
    return [item, if (whenEmpty case final whenEmpty?) whenEmpty];
  }

  /// Whether the child at [position] among the rendered ones gets a gap
  /// before it.
  bool _hasGapAt(int position) => position > 0 && spacing > 0;

  /// The gap before the child at [position] among the rendered ones, as a
  /// Kotlin `Dp` expression, or null for none.
  String? _kotlinGapAt(int position) =>
      _hasGapAt(position) ? '$spacing.dp' : null;

  /// The gap before each item of a builder, as a Kotlin `Dp` expression that is
  /// 0 for the first one, or null for no spacing.
  String? get _kotlinItemGap =>
      spacing > 0 ? 'if (${HWListLoop.index} > 0) $spacing.dp else 0.dp' : null;

  /// The name the Glance loop binds each item under, or `_` when nothing reads
  /// it: Kotlin warns about a lambda parameter nothing reads under a name of
  /// its own.
  ///
  /// [HWItemData] is the only thing emitting a read of it, so a builder whose
  /// [item] reads no item field never names it.
  String get _kotlinItemName => itemReads.isEmpty ? '_' : HWListLoop.item;

  /// The name the Glance loop binds each item's index under, or `_` when
  /// nothing reads it, as [_kotlinItemName].
  ///
  /// Four things emit a read of it: the gap before every item but the first,
  /// the spacers [mainAxisAlignment] puts between the items, the `Box` a
  /// baseline-aligned row places each item through, which [places] reports,
  /// and the bounds key of an Android bitmap text, which is keyed per item.
  String _kotlinIndexName(HWEmitContext? context, {required bool places}) =>
      _kotlinItemGap != null ||
              mainAxisAlignment.hasSpacerBetween ||
              places ||
              (item?.kotlinRendersBitmapTextIn(context) ?? false)
          ? HWListLoop.index
          : '_';

  /// Whether this stack turns `LinearLayout`'s baseline correction off, which
  /// a child reporting a baseline then has to lose.
  bool get _kotlinDefeatsBaseline => false;

  /// How this stack lays out a child with [gap] before it, padded down to a
  /// baseline by the `Box` [placement] holds the modifiers of when given.
  _HWKotlinStackSlot _kotlinSlot({String? gap, List<String>? placement}) =>
      _HWKotlinStackSlot(
        axis: _mainAxis,
        gap: gap,
        placement: placement,
        defeatsBaseline: _kotlinDefeatsBaseline,
      );

  /// [code], this stack's SwiftUI code, taking its whole main axis where the
  /// spacers of [mainAxisAlignment] may not stretch it.
  ///
  /// Glance fills the main axis of a stack whose alignment is carried by
  /// spacers whatever it holds, while SwiftUI only stretches through the
  /// spacers, and `spaceBetween` puts none around fewer than two children — a
  /// number a builder only knows at runtime. The frame then puts the content at
  /// the start of the main axis, as Flutter does with a single child.
  String _swiftFillingMainAxis(String code, int indent) {
    final alignment = mainAxisAlignment;
    if (!alignment.fillsMainAxis) return code;
    if (!isBuilder) {
      final rendered =
          children.where((child) => !child.swiftRendersNothing).length;
      if (alignment.spacerCount(rendered) > 0) return code;
    }
    final frame = _mainAxis == HWAxis.horizontal
        ? '.frame(maxWidth: .infinity, alignment: .leading)'
        : '.frame(maxHeight: .infinity, alignment: .top)';
    return applySwiftModifier(code, frame, indent);
  }

  /// The context [item] is emitted in, a builder's own [context] creating one
  /// when there is none.
  HWEmitContext _itemContext(HWEmitContext? context) =>
      (context ?? const HWEmitContext()).inItemOf(list!);

  /// Writes the SwiftUI code of this stack's content into [buffer]: its
  /// [children], or a builder's items and [whenEmpty].
  void _emitSwiftChildren(
    StringBuffer buffer,
    int indent,
    String dataExpr,
    HWEmitContext? context,
  ) {
    final item = this.item;
    if (item == null) {
      _emitSwiftFixed(children, buffer, indent, dataExpr, context);
    } else {
      _emitSwiftItems(item, buffer, indent, dataExpr, context);
    }
  }

  /// Writes the SwiftUI code of every one of [children] SwiftUI renders into
  /// [buffer], with the spacers of [mainAxisAlignment] and a gap of [spacing]
  /// before every child but the first.
  void _emitSwiftFixed(
    List<HWWidget> children,
    StringBuffer buffer,
    int indent,
    String dataExpr,
    HWEmitContext? context,
  ) {
    _emitChildrenWithMainAxisAlignment(
      [
        for (final child in children)
          if (!child.swiftRendersNothing) child,
      ],
      buffer,
      indent,
      mainAxisAlignment,
      (child, position) {
        final code =
            child.toSwift(indent, dataExpr: dataExpr, context: context);
        if (!_hasGapAt(position)) return code;
        return _swiftWithGap(code, _mainAxis, '$spacing', indent);
      },
      _swiftSpacer,
    );
  }

  /// Writes a builder's SwiftUI content into [buffer]: [whenEmpty] while the
  /// list is empty, otherwise [item] once per rendered item, with the spacers
  /// of [mainAxisAlignment] around and between the items and a gap of
  /// [spacing] before every item but the first.
  void _emitSwiftItems(
    HWWidget item,
    StringBuffer buffer,
    int indent,
    String dataExpr,
    HWEmitContext? context,
  ) {
    const index = HWListLoop.index;
    final pad = '    ' * indent;
    final entries = '($dataExpr.$list ?? [])';
    final whenEmpty = this.whenEmpty;
    var loopIndent = indent;
    if (whenEmpty != null) {
      buffer.writeln('${pad}if $entries.isEmpty {');
      _emitSwiftFixed([whenEmpty], buffer, indent + 1, dataExpr, context);
      buffer.writeln('$pad} else {');
      loopIndent++;
    }

    final loopPad = '    ' * loopIndent;
    final alignment = mainAxisAlignment;
    if (alignment.hasLeadingSpacer) buffer.writeln('$loopPad$_swiftSpacer');
    if (!item.swiftRendersNothing) {
      final prefix = maxItems == null ? '' : '.prefix($maxItems)';
      buffer.writeln(
        '${loopPad}ForEach(Array($entries$prefix.enumerated()), '
        'id: \\.offset) { $index, ${HWListLoop.item} in',
      );
      if (alignment.hasSpacerBetween) {
        buffer.write('''
$loopPad    if $index > 0 {
$loopPad        $_swiftSpacer
$loopPad    }
''');
      }
      final code = item.toSwift(
        loopIndent + 1,
        dataExpr: dataExpr,
        context: _itemContext(context),
      );
      buffer.writeln(
        spacing > 0
            ? _swiftWithGap(
                code,
                _mainAxis,
                '$index > 0 ? $spacing : 0',
                loopIndent + 1,
              )
            : code,
      );
      buffer.writeln('$loopPad}');
    }
    if (alignment.hasTrailingSpacer) buffer.writeln('$loopPad$_swiftSpacer');

    if (whenEmpty != null) buffer.writeln('$pad}');
  }

  /// Writes the Glance code of every one of [children] Glance renders into
  /// [buffer], with the spacers of [mainAxisAlignment] and a gap of [spacing]
  /// before every child but the first.
  ///
  /// [placement] gives the modifiers of the `Box` a row pads the child at an
  /// index of [children] down to its baseline through, or null for a child it
  /// leaves where the layout puts it.
  void _emitKotlinFixed(
    List<HWWidget> children,
    StringBuffer buffer,
    int indent,
    String dataExpr,
    HWEmitContext? context, {
    List<String>? Function(int index)? placement,
  }) {
    final childContext = (context ?? const HWEmitContext()).inLinear(_mainAxis);
    _emitChildrenWithMainAxisAlignment(
      HWMultiChildWidget._kotlinRendered(children),
      buffer,
      indent,
      mainAxisAlignment,
      (index, position) => children[index]._kotlinInStack(
        indent,
        dataExpr: dataExpr,
        context: childContext,
        slot: _kotlinSlot(
          gap: _kotlinGapAt(position),
          placement: placement?.call(index),
        ),
      ),
      _kotlinSpacer,
    );
  }

  /// Writes a builder's Glance content into [buffer]: [whenEmpty] while the
  /// list is empty, otherwise [item] once per rendered item, with the spacers
  /// of [mainAxisAlignment] around and between the items and a gap of
  /// [spacing] before every item but the first.
  ///
  /// [itemPlacement] holds the modifiers of the `Box` a row pads each item
  /// down to the deepest baseline through, by the ascents [ascent] reads off
  /// each item [HWListLoop.item] into [HWListLoop.ascents], or is null when
  /// the row leaves the items where the layout puts them.
  ///
  /// [whenEmpty] is emitted where the items are not declared yet, so that a
  /// builder inside it declares its own without shadowing them.
  void _emitKotlinItems(
    HWWidget item,
    StringBuffer buffer,
    int indent,
    String dataExpr,
    HWEmitContext? context, {
    List<String>? itemPlacement,
    String? ascent,
  }) {
    const index = HWListLoop.index;
    const items = HWListLoop.items;
    final pad = '    ' * indent;
    final entries = '$dataExpr.$list';
    final whenEmpty = this.whenEmpty;
    var loopIndent = indent;
    if (whenEmpty != null) {
      buffer.writeln('${pad}if ($entries.isNullOrEmpty()) {');
      _emitKotlinFixed([whenEmpty], buffer, indent + 1, dataExpr, context);
      buffer.writeln('$pad} else {');
      loopIndent++;
    }

    final loopPad = '    ' * loopIndent;
    final rendersItems = !item.kotlinRendersNothing;
    if (rendersItems) {
      final take = maxItems == null ? '' : '.take($maxItems)';
      buffer.writeln('${loopPad}val $items = $entries.orEmpty()$take');
      if (ascent != null) {
        buffer.writeln(
          '${loopPad}val ${HWListLoop.ascents} = '
          '$items.map { ${HWListLoop.item} -> $ascent }',
        );
      }
    }
    final alignment = mainAxisAlignment;
    if (alignment.hasLeadingSpacer) buffer.writeln('$loopPad$_kotlinSpacer');
    if (rendersItems) {
      buffer.writeln(
        '$loopPad$items.forEachIndexed { '
        '${_kotlinIndexName(context, places: itemPlacement != null)}, '
        '$_kotlinItemName ->',
      );
      if (alignment.hasSpacerBetween) {
        buffer.writeln('$loopPad    if ($index > 0) $_kotlinSpacer');
      }
      buffer.writeln(
        item._kotlinInStack(
          loopIndent + 1,
          dataExpr: dataExpr,
          context: _itemContext(context).inLinear(_mainAxis),
          slot: _kotlinSlot(gap: _kotlinItemGap, placement: itemPlacement),
        ),
      );
      buffer.writeln('$loopPad}');
    }
    if (alignment.hasTrailingSpacer) buffer.writeln('$loopPad$_kotlinSpacer');

    if (whenEmpty != null) buffer.writeln('$pad}');
  }

  /// The imports of this stack's content: every one of its [children] Glance
  /// renders, [placement] giving the baseline `Box` of each index the way
  /// [_emitKotlinFixed] takes it, or a builder's [item], placed by
  /// [itemPlacement], and [whenEmpty].
  Set<String> _kotlinChildImports({
    List<String>? Function(int index)? placement,
    List<String>? itemPlacement,
  }) {
    final item = this.item;
    if (item == null) {
      return _kotlinFixedImports(children, placement: placement);
    }
    return {
      ...item._kotlinImportsInStack(
        _kotlinSlot(gap: _kotlinItemGap, placement: itemPlacement),
      ),
      if (whenEmpty case final whenEmpty?) ..._kotlinFixedImports([whenEmpty]),
    };
  }

  /// The imports of every one of [children] Glance renders, [placement] giving
  /// the baseline `Box` of each index the way [_emitKotlinFixed] takes it.
  Set<String> _kotlinFixedImports(
    List<HWWidget> children, {
    List<String>? Function(int index)? placement,
  }) {
    final rendered = HWMultiChildWidget._kotlinRendered(children);
    return {
      for (var position = 0; position < rendered.length; position++)
        ...children[rendered[position]]._kotlinImportsInStack(
          _kotlinSlot(
            gap: _kotlinGapAt(position),
            placement: placement?.call(rendered[position]),
          ),
        ),
    };
  }
}

/// The spacer a SwiftUI stack puts where a main-axis alignment asks for room.
///
/// Like a Glance one it takes nothing but the room left over, where a plain
/// `Spacer()` would insist on a gap of its own.
const String _swiftSpacer = 'Spacer(minLength: 0)';

/// The spacer a Glance stack puts where a main-axis alignment asks for room.
const String _kotlinSpacer =
    'Spacer(modifier = GlanceModifier.defaultWeight())';

/// Writes [children] into [buffer], [indent] levels deep, with the spacers
/// [alignment] puts before, between and after them.
///
/// [emit] renders one child, told its position among [children]. A stack
/// emitting its children in a loop writes the same spacers by the getters of
/// [HWMainAxisAlignmentFill].
void _emitChildrenWithMainAxisAlignment<T>(
  List<T> children,
  StringBuffer buffer,
  int indent,
  HWMainAxisAlignment? alignment,
  String Function(T child, int position) emit,
  String spacer,
) {
  final spacerLine = '${'    ' * indent}$spacer';
  if (alignment.hasLeadingSpacer) buffer.writeln(spacerLine);
  for (var position = 0; position < children.length; position++) {
    if (position > 0 && alignment.hasSpacerBetween) {
      buffer.writeln(spacerLine);
    }
    buffer.writeln(emit(children[position], position));
  }
  if (alignment.hasTrailingSpacer) buffer.writeln(spacerLine);
}

/// [code] with [gap] of room before it along [axis], outside whatever it
/// draws.
///
/// [gap] is a Swift expression, so a stack can make it depend on where a child
/// sits.
String _swiftWithGap(String code, HWAxis axis, String gap, int indent) {
  final edge = axis == HWAxis.vertical ? '.top' : '.leading';
  return applySwiftModifier(code, '.padding($edge, $gap)', indent);
}

/// The `spacing` of the stack [obj] holds, which [stack] names in the error a
/// negative one fails with.
double _decodeSpacing(DartObject obj, String stack) {
  final spacing =
      WidgetValueDecoder.getField(obj, 'spacing')?.toDoubleValue() ?? 0;
  if (spacing < 0) {
    throw GeneratorError(
      '$stack spacing must be 0 or more, got ${hwSizeLiteral(spacing)}.',
    );
  }
  return spacing;
}

/// The builder fields of the [stack], `HWColumn` or `HWRow`, [obj] holds, or
/// null when it holds fixed children.
///
/// [HWFlex.item] is decoded in the builder's own item scope, and the builder is
/// rejected inside the item of another one. `spelling` is how the errors of the
/// builder name it, e.g. `HWRow.builder('days')`.
({
  String list,
  String spelling,
  HWWidget item,
  int? maxItems,
  HWWidget? whenEmpty,
})? _decodeBuilder(
  DartObject obj,
  WidgetValueDecoder decoder,
  String stack,
) {
  final list = WidgetValueDecoder.getField(obj, 'list')?.toStringValue();
  if (list == null) return null;

  final spelling = "$stack.builder('$list')";
  if (decoder.itemScope case final enclosing?) {
    throw GeneratorError(
      "Nested lists aren't supported yet: $spelling sits inside the item of "
      '$enclosing.',
    );
  }
  final maxItems = WidgetValueDecoder.getField(obj, 'maxItems')?.toIntValue();
  if (maxItems != null && maxItems < 1) {
    throw GeneratorError(
      '$spelling maxItems must be 1 or more, got $maxItems.',
    );
  }
  final whenEmpty = WidgetValueDecoder.getField(obj, 'whenEmpty');
  return (
    list: list,
    spelling: spelling,
    item: decoder.decodeItem(
      WidgetValueDecoder.getField(obj, 'item'),
      spelling,
    ),
    maxItems: maxItems,
    whenEmpty: whenEmpty == null || whenEmpty.isNull
        ? null
        : decoder.decodeRecursive(whenEmpty),
  );
}
