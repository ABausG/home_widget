part of 'hw_widget.dart';

/// A vertical layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI VStack and Glance Column.
class HWColumn extends HWMultiChildWidget {
  final HWCrossAxisAlignment? crossAxisAlignment;

  const HWColumn({
    required super.children,
    this.crossAxisAlignment,
    super.mainAxisAlignment,
    super.spacing = 0,
  });

  /// A column rendering [item] once per entry of the list saved under [list],
  /// in the order the entries were saved.
  ///
  /// [item] is the only subtree an [HWItemData] reads from; every other field
  /// read inside it still reads the widget's own data. At most [maxItems]
  /// entries render, and [whenEmpty] is the column's only child while there
  /// is none. The alignments and [spacing] apply to the items exactly as they
  /// do to fixed children.
  const HWColumn.builder(
    super.list, {
    required super.item,
    super.maxItems,
    super.whenEmpty,
    this.crossAxisAlignment,
    super.mainAxisAlignment,
    super.spacing = 0,
  }) : super.builder();

  @override
  HWAxis get _mainAxis => HWAxis.vertical;

  /// The alignment this column renders with, always emitted so that neither
  /// platform falls back to its own default.
  ///
  /// `baseline` lines up along a horizontal cross axis, which a column has no
  /// baseline on; [fromDartObject] rejects it, and both emitters centre on it.
  HWCrossAxisAlignment get effectiveCrossAxisAlignment =>
      crossAxisAlignment ?? HWCrossAxisAlignment.center;

  /// The cross axis is the horizontal one, so the column keeps its own
  /// alignment there; a main axis alignment other than start is emitted as
  /// `Spacer()`s expanding the `VStack`, which leaves the vertical one moot.
  @override
  String get swiftFrameAlignment => switch (effectiveCrossAxisAlignment) {
        HWCrossAxisAlignment.start => '.topLeading',
        HWCrossAxisAlignment.end => '.topTrailing',
        HWCrossAxisAlignment.center || HWCrossAxisAlignment.baseline => '.top',
      };

  /// A column filling the height of the column it sits in would leave its
  /// siblings nothing, so along that axis it asks for the room by weight.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) {
    if (!mainAxisAlignment.fillsMainAxis) return const HWKotlinRoom();
    return enclosingLinearAxis == HWAxis.vertical
        ? const HWKotlinRoom(weight: true)
        : const HWKotlinRoom(fillsHeight: true);
  }

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.layout.Column',
        'import androidx.glance.layout.Alignment',
        if (mainAxisAlignment != null) 'import androidx.glance.layout.Spacer',
        ...kotlinRoomIn(enclosingLinearAxis).kotlinImports,
        ..._kotlinChildImports(),
      };

  static HWColumn fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final builder = _decodeBuilder(obj, decoder, 'HWColumn');
    final children = builder == null
        ? _decodeChildren(obj, decoder, 'HWColumn')
        : const <HWWidget>[];

    final crossAxisAlignmentField =
        WidgetValueDecoder.getField(obj, 'crossAxisAlignment');
    final mainAxisAlignmentField =
        WidgetValueDecoder.getField(obj, 'mainAxisAlignment');

    final crossAxisAlignment = WidgetValueDecoder.decodeEnum(
      crossAxisAlignmentField,
      HWCrossAxisAlignment.values,
    );
    if (crossAxisAlignment == HWCrossAxisAlignment.baseline) {
      throw GeneratorError(
        'HWColumn cannot use HWCrossAxisAlignment.baseline. Baseline alignment '
        'lines up the text baselines along a horizontal cross axis, so it only '
        'applies to HWRow.',
      );
    }
    final mainAxisAlignment = WidgetValueDecoder.decodeEnum(
      mainAxisAlignmentField,
      HWMainAxisAlignment.values,
    );

    if (builder != null) {
      return HWColumn.builder(
        builder.list,
        item: builder.item,
        maxItems: builder.maxItems,
        whenEmpty: builder.whenEmpty,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        spacing: _decodeSpacing(obj, builder.spelling),
      );
    }
    return HWColumn(
      children: children,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      spacing: _decodeSpacing(obj, 'HWColumn'),
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
    final swiftAlign = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start => '.leading',
      HWCrossAxisAlignment.end => '.trailing',
      HWCrossAxisAlignment.center || HWCrossAxisAlignment.baseline => '.center',
    };

    buffer.writeln('${pad}VStack(alignment: $swiftAlign, spacing: 0) {');

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
    final pad = '    ' * indent;
    final buffer = StringBuffer();
    final align = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start => 'Alignment.Start',
      HWCrossAxisAlignment.end => 'Alignment.End',
      HWCrossAxisAlignment.center ||
      HWCrossAxisAlignment.baseline =>
        'Alignment.CenterHorizontally',
    };

    final room = kotlinRoomIn(context?.enclosingLinearAxis).modifiers;
    final arguments = [
      if (room.isNotEmpty) 'modifier = GlanceModifier.${room.join('.')}',
      'horizontalAlignment = $align',
    ].join(', ');
    buffer.writeln('${pad}Column($arguments) {');

    final item = this.item;
    if (item == null) {
      _emitKotlinFixed(children, buffer, indent + 1, dataExpr, context);
    } else {
      _emitKotlinItems(item, buffer, indent + 1, dataExpr, context);
    }

    buffer.write('$pad}');
    return buffer.toString();
  }
}
