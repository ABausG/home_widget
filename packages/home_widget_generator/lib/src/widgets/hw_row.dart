part of 'hw_widget.dart';

/// A horizontal layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI HStack and Glance Row.
class HWRow extends HWMultiChildWidget {
  final HWCrossAxisAlignment? crossAxisAlignment;

  const HWRow({
    required super.children,
    this.crossAxisAlignment,
    super.mainAxisAlignment,
    super.spacing = 0,
  });

  /// A row rendering [item] once per entry of the list saved under [list], in
  /// the order the entries were saved.
  ///
  /// [item] is the only subtree an [HWItemData] reads from; every other field
  /// read inside it still reads the widget's own data. At most [maxItems]
  /// entries render, and [whenEmpty] is the row's only child while there is
  /// none. The alignments and [spacing] apply to the items exactly as they do
  /// to fixed children.
  const HWRow.builder(
    super.list, {
    required super.item,
    super.maxItems,
    super.whenEmpty,
    this.crossAxisAlignment,
    super.mainAxisAlignment,
    super.spacing = 0,
  }) : super.builder();

  @override
  HWAxis get _mainAxis => HWAxis.horizontal;

  /// The alignment this row renders with, always emitted so that neither
  /// platform falls back to its own default.
  HWCrossAxisAlignment get effectiveCrossAxisAlignment =>
      crossAxisAlignment ?? HWCrossAxisAlignment.center;

  /// The cross axis is the vertical one, so the row keeps its own alignment
  /// there; a main axis alignment other than start is emitted as `Spacer()`s
  /// expanding the `HStack`, which leaves the horizontal one moot.
  @override
  String get swiftFrameAlignment => switch (effectiveCrossAxisAlignment) {
        HWCrossAxisAlignment.start ||
        HWCrossAxisAlignment.baseline =>
          '.topLeading',
        HWCrossAxisAlignment.center => '.leading',
        HWCrossAxisAlignment.end => '.bottomLeading',
      };

  /// Whether a text child has to lose its baseline for the alignment to hold,
  /// which a bare `Box` around it does: its `getBaseline()` is -1.
  ///
  /// `LinearLayout` corrects a top- or bottom-aligned child by its baseline,
  /// which renders both as baseline alignment; it leaves a centred one alone.
  @override
  bool get _kotlinDefeatsBaseline => switch (effectiveCrossAxisAlignment) {
        HWCrossAxisAlignment.start || HWCrossAxisAlignment.end => true,
        HWCrossAxisAlignment.center || HWCrossAxisAlignment.baseline => false,
      };

  /// The text of every child this row places itself, by child index, or null
  /// when the layout already lines the children up.
  ///
  /// A Glance `Row` is a `LinearLayout` with `baselineAligned` on, so an
  /// `Alignment.Top` row of Glance `Text`s is baseline-aligned by the framework
  /// already. Only a text reporting no baseline needs placing: a bitmap text,
  /// which is an `Image`, or a text the row lays out through a `Box` of its
  /// own to carry a gap it cannot take itself. Either would stay at the top
  /// while its siblings moved, so the row places every text then. Two texts
  /// are the least there is to line up, and a child rendering none — an icon, a
  /// picture — stays at the top either way.
  Map<int, HWKotlinBaselineText>? _kotlinBaselineChildren(
    HWEmitContext? context,
  ) {
    if (effectiveCrossAxisAlignment != HWCrossAxisAlignment.baseline) {
      return null;
    }
    final texts = <int, HWKotlinBaselineText>{};
    for (var index = 0; index < children.length; index++) {
      if (children[index].kotlinBaselineText(context) case final text?) {
        texts[index] = text;
      }
    }
    if (texts.length < 2) return null;
    if (texts.values.any((text) => text.isBitmap)) return texts;

    final rendered = HWMultiChildWidget._kotlinRendered(children);
    final boxesText = texts.keys.any(
      (index) => children[index]._kotlinBoxesTextInStack(
        _kotlinSlot(gap: _kotlinGapAt(rendered.indexOf(index))),
        context,
      ),
    );
    return boxesText ? texts : null;
  }

  /// The text every item of this builder is padded down to a shared baseline
  /// by, or null when the row leaves the items where the layout puts them.
  ///
  /// The items are one widget rendered once each, so their texts only differ
  /// in what they read of their item: one whose ascent reads no item field
  /// sits at the same depth in every item, and each padding would be 0. As
  /// with fixed children, a text reporting its baseline is lined up by the
  /// layout already.
  HWKotlinBaselineText? _kotlinBaselineItem(
    HWWidget item,
    HWEmitContext? context,
  ) {
    if (effectiveCrossAxisAlignment != HWCrossAxisAlignment.baseline) {
      return null;
    }
    final text = item.kotlinBaselineText(context);
    if (text == null) return null;
    if (!text.isBitmap &&
        !item._kotlinBoxesTextInStack(
          _kotlinSlot(gap: _kotlinItemGap),
          context,
        )) {
      return null;
    }
    if (!text.readsItem) return null;
    return text;
  }

  /// The modifiers of the `Box` this row pads the child at [index] down to the
  /// row's baseline through, or null for a child it does not place.
  List<String>? _kotlinPlacement(
    int index,
    Map<int, HWKotlinBaselineText>? texts,
    String dataExpr,
  ) {
    if (texts == null || !texts.containsKey(index)) return null;

    final ascents =
        texts.values.map((text) => text.ascent(dataExpr)).join(', ');
    final place = texts.keys.toList().indexOf(index);
    return [
      'padding(top = HomeWidgetFonts.baselinePadding(context, '
          'listOf($ascents), $place))',
    ];
  }

  /// The modifiers of the `Box` this row pads every item of a builder down to
  /// the deepest ascent among the rendered ones through, or null without a
  /// [text] to line up by.
  static List<String>? _kotlinItemPlacement(HWKotlinBaselineText? text) =>
      text == null
          ? null
          : [
              'padding(top = HomeWidgetFonts.baselinePadding(context, '
                  '${HWListLoop.ascents}, ${HWListLoop.index}))',
            ];

  /// A row filling the width of the row it sits in would leave its siblings
  /// nothing, so along that axis it asks for the room by weight.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) {
    if (!mainAxisAlignment.fillsMainAxis) return const HWKotlinRoom();
    return enclosingLinearAxis == HWAxis.horizontal
        ? const HWKotlinRoom(weight: true)
        : const HWKotlinRoom(fillsWidth: true);
  }

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) {
    final texts = _kotlinBaselineChildren(null);
    final item = this.item;
    final itemText = item == null ? null : _kotlinBaselineItem(item, null);
    return {
      'import androidx.glance.layout.Row',
      'import androidx.glance.layout.Alignment',
      if (mainAxisAlignment != null) 'import androidx.glance.layout.Spacer',
      ...kotlinRoomIn(enclosingLinearAxis).kotlinImports,
      if (texts != null || itemText != null) ...{
        'import androidx.glance.layout.padding',
        'import es.antonborri.home_widget.HomeWidgetFonts',
        for (final text in [...?texts?.values, if (itemText != null) itemText])
          ...text.kotlinImports,
      },
      ..._kotlinChildImports(
        placement: (index) => _kotlinPlacement(index, texts, _ascentProbe),
        itemPlacement: _kotlinItemPlacement(itemText),
      ),
    };
  }

  static HWRow fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final builder = _decodeBuilder(obj, decoder, 'HWRow');
    final children = builder == null
        ? _decodeChildren(obj, decoder, 'HWRow')
        : const <HWWidget>[];

    final crossAxisAlignmentField =
        WidgetValueDecoder.getField(obj, 'crossAxisAlignment');
    final mainAxisAlignmentField =
        WidgetValueDecoder.getField(obj, 'mainAxisAlignment');

    final crossAxisAlignment = WidgetValueDecoder.decodeEnum(
      crossAxisAlignmentField,
      HWCrossAxisAlignment.values,
    );
    final mainAxisAlignment = WidgetValueDecoder.decodeEnum(
      mainAxisAlignmentField,
      HWMainAxisAlignment.values,
    );

    if (builder != null) {
      return HWRow.builder(
        builder.list,
        item: builder.item,
        maxItems: builder.maxItems,
        whenEmpty: builder.whenEmpty,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        spacing: _decodeSpacing(obj, builder.spelling),
      );
    }
    return HWRow(
      children: children,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      spacing: _decodeSpacing(obj, 'HWRow'),
    );
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent;
    final buffer = StringBuffer();

    // `.firstTextBaseline` rather than `.lastTextBaseline`: a TextView reports
    // its first line's baseline, and so does Flutter's CrossAxisAlignment.
    final swiftAlign = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start => '.top',
      HWCrossAxisAlignment.center => '.center',
      HWCrossAxisAlignment.end => '.bottom',
      HWCrossAxisAlignment.baseline => '.firstTextBaseline',
    };

    buffer.writeln('${pad}HStack(alignment: $swiftAlign, spacing: 0) {');

    _emitSwiftChildren(buffer, indent + 1, dataExpr, context);

    buffer.write('$pad}');
    return _swiftFillingMainAxis(buffer.toString(), indent);
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final texts = _kotlinBaselineChildren(context);
    final item = this.item;
    final itemText = item == null ? null : _kotlinBaselineItem(item, context);
    for (final text in [...?texts?.values, if (itemText != null) itemText]) {
      if (text.conflict case final conflict?) throw GeneratorError(conflict);
    }
    final pad = '    ' * indent;
    final buffer = StringBuffer();

    final align = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start ||
      HWCrossAxisAlignment.baseline =>
        'Alignment.Top',
      HWCrossAxisAlignment.center => 'Alignment.CenterVertically',
      HWCrossAxisAlignment.end => 'Alignment.Bottom',
    };

    final room = kotlinRoomIn(context?.enclosingLinearAxis).modifiers;
    final arguments = [
      if (room.isNotEmpty) 'modifier = GlanceModifier.${room.join('.')}',
      'verticalAlignment = $align',
    ].join(', ');
    buffer.writeln('${pad}Row($arguments) {');

    if (item == null) {
      _emitKotlinFixed(
        children,
        buffer,
        indent + 1,
        dataExpr,
        context,
        placement: (index) => _kotlinPlacement(index, texts, dataExpr),
      );
    } else {
      _emitKotlinItems(
        item,
        buffer,
        indent + 1,
        dataExpr,
        context,
        itemPlacement: _kotlinItemPlacement(itemText),
        ascent: itemText?.ascent(dataExpr),
      );
    }

    buffer.write('$pad}');
    return buffer.toString();
  }
}
