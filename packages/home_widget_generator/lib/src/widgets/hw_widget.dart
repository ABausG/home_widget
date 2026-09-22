import 'package:analyzer/dart/constant/value.dart';
import '../annotations.dart';
import '../fonts.dart';
import '../formats.dart';
import '../generator_error.dart';
import '../native_helpers.dart';
import '../parser/widget_value_decoder.dart';
import '../types.dart';
import '../utils/apply_swift_modifier.dart';
import '../utils/inject_glance_modifier.dart';
import '../utils/map_equals.dart';
import '../utils/string_literals.dart';
import 'hw_alignment.dart';
import 'hw_color.dart';
import 'hw_emit_context.dart';
import 'hw_generatable.dart';
import 'hw_size.dart';
import 'hw_text_style.dart';
import 'hw_edge_insets.dart';

part 'hw_flex.dart';
part 'hw_column.dart';
part 'hw_row.dart';
part 'hw_stack.dart';
part 'hw_align.dart';
part 'hw_text.dart';
part 'hw_image.dart';
part 'hw_icon.dart';
part 'hw_data_only.dart';
part 'hw_adaptive.dart';
part 'hw_sized_box.dart';
part 'hw_colored_box.dart';
part 'hw_decorated_box.dart';
part 'hw_padding.dart';
part 'hw_conditional.dart';
part 'hw_size_adaptive.dart';
part 'hw_android_size_range.dart';
part 'hw_android_size_grid.dart';

/// Base class for widgets that accept a single child (e.g. Expanded).
sealed class HWSingleChildWidget extends HWWidget {
  final HWWidget child;

  const HWSingleChildWidget({required this.child});

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// None when [child] renders nothing: this wrapper emits no Glance code of
  /// its own around it either.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) =>
      child.kotlinRendersNothing
          ? const {}
          : _kotlinImportsAroundChild(enclosingLinearAxis);

  /// The imports of the Glance code this wrapper puts around [child]'s, laid
  /// out inside a `Column` or `Row` running along [enclosingLinearAxis].
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis);

  @override
  Set<String> get swiftViewModifiers => child.swiftViewModifiers;

  @override
  Set<HWDataType<dynamic>> get dataDependencies => child.dataDependencies;

  @override
  List<HWWidget> get childWidgets => [child];

  /// The child's, for the wrappers that inject their modifier into the child's
  /// own composable; one emitting a `Box` of its own answers false instead.
  @override
  bool get kotlinReportsBaseline => child.kotlinReportsBaseline;

  /// The child's, since a wrapper is laid out around whatever the child does.
  @override
  String get swiftFrameAlignment => child.swiftFrameAlignment;

  /// The child's, for the wrappers whose own drawing a clip at the frame
  /// leaves alone or cuts no further than Flutter would; one drawing past its
  /// bounds, like a stroked border, answers false instead.
  @override
  bool get swiftClipsFrame => child.swiftClipsFrame;

  /// The child's, for the wrappers that inject their modifier into the child's
  /// own composable.
  @override
  bool get kotlinPaddingAddsRoom => child.kotlinPaddingAddsRoom;

  /// The child's: a wrapper around a child rendering nothing has nothing to
  /// put its modifier on, so it renders nothing itself.
  @override
  bool get swiftRendersNothing => child.swiftRendersNothing;

  /// The child's, as [swiftRendersNothing].
  @override
  bool get kotlinRendersNothing => child.kotlinRendersNothing;

  /// The child's, for the wrappers that inject their modifier into the child's
  /// own composable.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) =>
      child.kotlinRoomIn(enclosingLinearAxis);

  /// Whether this wrapper's Glance output is [child]'s with a modifier put on
  /// the child's own composable, rather than a composable of its own.
  bool get _kotlinInjectsIntoChild => true;

  /// This wrapper around [widget] in place of [child].
  HWSingleChildWidget _wrapping(HWWidget widget);

  /// [widget] as this wrapper's modifier lands on it: wrapped, unless it
  /// renders nothing for the modifier to go on.
  HWWidget _kotlinWrapping(HWWidget widget) =>
      widget.kotlinRendersNothing ? widget : _wrapping(widget);

  /// A modifier injected into a choice goes on whichever widget it lands on,
  /// so this wrapper sits on each of them.
  @override
  List<HWWidget>? _kotlinChoices(HWEmitContext? context) {
    if (!_kotlinInjectsIntoChild) return null;
    return child._kotlinChoices(context)?.map(_kotlinWrapping).toList();
  }

  @override
  String? _kotlinChoice(
    int indent, {
    required String dataExpr,
    required HWEmitContext? context,
    required String Function(HWWidget widget, int indent) emit,
  }) {
    if (!_kotlinInjectsIntoChild) return null;
    return child._kotlinChoice(
      indent,
      dataExpr: dataExpr,
      context: context,
      emit: (widget, indent) => emit(_kotlinWrapping(widget), indent),
    );
  }

  @override
  Set<String> get _kotlinChoiceImports => child._kotlinChoiceImports;

  /// Nothing when [child] renders nothing, which is what
  /// [kotlinRendersNothing] answers for this wrapper: the modifier or `Box` of
  /// its own would otherwise render where the model says nothing does.
  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) =>
      child.kotlinRendersNothing
          ? ''
          : _kotlinAroundChild(indent, dataExpr: dataExpr, context: context);

  /// The Glance code this wrapper puts around [child]'s, which renders
  /// something.
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  });
}

/// Base class for widgets that accept multiple children (e.g. Column, Row).
sealed class HWMultiChildWidget extends HWWidget {
  /// The children this widget lays out, empty for a builder.
  final List<HWWidget> children;

  const HWMultiChildWidget({required this.children});

  @override
  Set<String> get swiftViewModifiers {
    return childWidgets.expand((child) => child.swiftViewModifiers).toSet();
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies =>
      children.expand((child) => child.dataDependencies).toSet();

  @override
  List<HWWidget> get childWidgets => children;

  /// The indices of the [children] Glance renders, which are the ones it
  /// counts as children of the stack.
  static List<int> _kotlinRendered(List<HWWidget> children) => [
        for (var index = 0; index < children.length; index++)
          if (!children[index].kotlinRendersNothing) index,
      ];
}

/// Interface for widgets that hold data dependencies.
abstract interface class HWDataWidget {
  Set<HWDataType<dynamic>> get dataDependencies;
}

/// A widget that renders in a font file of its own.
mixin HWFontWidget {
  /// The font file this one widget renders with, or null when it renders in
  /// the platform's own font.
  HWFontVariant? get fontVariant;
}

/// Abstract base class for all DSL widgets used in widgetBuilder.
/// Subclasses: HWText (v3), HWColumn, HWRow (v4).
sealed class HWWidget implements HWGeneratable {
  const HWWidget();

  // coverage:ignore-start
  @override
  Set<String> get kotlinImports => {};

  @override
  Set<String> get swiftViewModifiers => {};

  /// The set of data dependencies required by this widget.
  Set<HWDataType<dynamic>> get dataDependencies => {};
  // coverage:ignore-end

  /// The widgets this one renders, if any.
  ///
  /// Recurses the same way [dataDependencies] does, branches of a conditional
  /// and both sides of an [HWAdaptive] included, and is what [descendants]
  /// walks.
  List<HWWidget> get childWidgets => const [];

  /// The widgets this one renders on Android.
  ///
  /// [childWidgets] for everything but an [HWAdaptive], which renders its
  /// Android branch alone there, and is what [androidDescendants] walks.
  List<HWWidget> get androidChildWidgets => childWidgets;

  /// Whether this widget's Glance output is a `Text`, and so reports a text
  /// baseline to the horizontal `LinearLayout` a Glance `Row` becomes.
  ///
  /// [HWRow] reads this to decide which children to wrap in a bare `Box`, whose
  /// `getBaseline()` is -1, which is what turns `LinearLayout`'s baseline
  /// correction off for a top- or bottom-aligned row. A widget that emits a
  /// `Box`, an `Image` or a `Spacer` has no baseline and answers false.
  ///
  /// Like [kotlinRoomIn] and [kotlinPaddingAddsRoom], this is never asked of a
  /// widget whose Glance output is picked where it sits — a conditional, an
  /// [HWSizeAdaptive]: a stack asks each widget it can land on instead.
  bool get kotlinReportsBaseline => false;

  /// Whether a SwiftUI frame around this widget has to cut off what it draws
  /// past the frame.
  ///
  /// SwiftUI lets a view draw outside the frame it was given, where Flutter
  /// would have sized this widget to it: a widget clipping its own bounds
  /// answers true, and the frame clips too so that both platforms show the
  /// same thing.
  bool get swiftClipsFrame => false;

  /// The place a SwiftUI frame wider or taller than this widget puts it, as an
  /// `Alignment` literal.
  ///
  /// A frame only has a say while the widget does not fill it, and it then puts
  /// it where the widget's own alignment would, so a bounded child renders the
  /// way Flutter's tight constraints render it.
  String get swiftFrameAlignment => '.topLeading';

  /// Whether this widget's Glance output is a bitmap the core plugin draws the
  /// text into, rather than something Glance renders itself.
  ///
  /// A bitmap needs the room it may take measured before it is composed, which
  /// is what [HWBitmapTextRenderer] describes; only a widget emitting one
  /// answers true.
  bool get kotlinRendersBitmapText => false;

  /// The text a baseline-aligned [HWRow] lines this child up by, or null when
  /// the emitted view is not one it can place.
  ///
  /// Only a widget whose Glance output *is* the text answers with one: the row
  /// pads the child from the top of the box it sits in, so anything drawn above
  /// the glyphs would carry the baseline with it. A child answering null — an
  /// icon, a picture, a column of several texts — is left at the top.
  ///
  /// [context] names the families the widget can be shown in, which is what
  /// decides the slots of an [HWSizeAdaptive] the row has to line up; without
  /// one every slot written counts.
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) => null;

  /// Whether Android draws any text of this subtree into a bitmap.
  ///
  /// Such a text is an `Image` whose room is measured under a bounds key, and
  /// inside the item of a builder that key carries the item's index, so the
  /// loop has to name it.
  ///
  /// Follows what Android renders the way [kotlinBaselineText] does: an
  /// [HWAdaptive]'s Android side, and the slots of an [HWSizeAdaptive] the
  /// [context] can show, which is what [_kotlinChoices] answers.
  bool kotlinRendersBitmapTextIn(HWEmitContext? context) {
    if (_kotlinChoices(context) case final choices?) {
      return choices.any((choice) => choice.kotlinRendersBitmapTextIn(context));
    }
    if (kotlinRendersBitmapText) return true;
    return childWidgets
        .any((child) => child.kotlinRendersBitmapTextIn(context));
  }

  /// [kotlinImports], for a widget emitted directly inside a Glance `Column` or
  /// `Row` running along [enclosingLinearAxis].
  ///
  /// A layout asking for its whole main axis takes a weight instead of a fill
  /// there, and the two need different imports; every widget that passes its
  /// own composable's modifier down forwards the axis, and one emitting a `Box`
  /// of its own clears it.
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => kotlinImports;

  /// The room this widget's outermost Glance composable asks for, emitted
  /// directly inside a Glance `Column` or `Row` running along
  /// [enclosingLinearAxis].
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) =>
      const HWKotlinRoom();

  /// Whether a padding put on this widget's outermost Glance composable adds
  /// room around what it draws.
  ///
  /// Glance pads a view inside its own bounds: a background covers the
  /// padding too, and a fixed size gives it up out of the content. A stack
  /// puts the gap before a child answering false on a `Box` around it instead.
  bool get kotlinPaddingAddsRoom => true;

  /// Whether this widget's SwiftUI output is empty.
  ///
  /// A stack gives such a child neither a gap nor spacers of its own.
  bool get swiftRendersNothing => false;

  /// Whether this widget's Glance output is empty.
  ///
  /// A stack gives such a child neither a gap nor spacers of its own, and
  /// Glance does not count it among the stack's children.
  bool get kotlinRendersNothing => false;

  /// The widgets this one's Glance output is picked from where it sits, or
  /// null when it renders one of its own.
  ///
  /// A stack lays each of them out on its own, with the gap, room and baseline
  /// `Box` that one needs, so a branch rendering nothing gets none of them.
  /// [context] decides the slots of an [HWSizeAdaptive]; without one every slot
  /// Android can render counts.
  List<HWWidget>? _kotlinChoices(HWEmitContext? context) => null;

  /// This widget's Glance code with [emit] writing each of [_kotlinChoices] at
  /// the indent it sits at, or null when it renders one widget of its own.
  String? _kotlinChoice(
    int indent, {
    required String dataExpr,
    required HWEmitContext? context,
    required String Function(HWWidget widget, int indent) emit,
  }) =>
      null;

  /// The imports [_kotlinChoice] needs itself, besides those of the widgets it
  /// picks from.
  Set<String> get _kotlinChoiceImports => const {};

  /// This widget's Glance code as a child of a Glance `Column` or `Row`, laid
  /// out through [slot] in the [context] the stack emits its children in.
  ///
  /// A choice lays out each widget it can land on through the slot; any other
  /// widget takes the gap on its own composable, or is laid out through a `Box`
  /// of the stack's carrying its room.
  String _kotlinInStack(
    int indent, {
    required String dataExpr,
    required HWEmitContext context,
    required _HWKotlinStackSlot slot,
  }) {
    final choice = _kotlinChoice(
      indent,
      dataExpr: dataExpr,
      context: context,
      emit: (widget, indent) => widget._kotlinInStack(
        indent,
        dataExpr: dataExpr,
        context: context,
        slot: slot,
      ),
    );
    if (choice != null) return choice;
    if (kotlinRendersNothing) return '';
    return slot.lay(
      indent,
      context: context,
      emit: (indent, context) =>
          toKotlin(indent, dataExpr: dataExpr, context: context),
      reportsBaseline: kotlinReportsBaseline,
      paddingAddsRoom: kotlinPaddingAddsRoom,
      room: kotlinRoomIn(slot.axis),
    );
  }

  /// The imports [_kotlinInStack] needs through [slot].
  Set<String> _kotlinImportsInStack(_HWKotlinStackSlot slot) {
    if (_kotlinChoices(null) case final choices?) {
      return {
        ..._kotlinChoiceImports,
        for (final choice in choices) ...choice._kotlinImportsInStack(slot),
      };
    }
    if (kotlinRendersNothing) return const {};
    return slot.imports(
      importsIn: kotlinImportsIn,
      reportsBaseline: kotlinReportsBaseline,
      paddingAddsRoom: kotlinPaddingAddsRoom,
      room: kotlinRoomIn(slot.axis),
    );
  }

  /// Whether a Glance `Text` this widget renders, laid out through [slot],
  /// ends up in a `Box` of the stack's, which reports no baseline.
  bool _kotlinBoxesTextInStack(
    _HWKotlinStackSlot slot,
    HWEmitContext? context,
  ) {
    if (_kotlinChoices(context) case final choices?) {
      return choices
          .any((choice) => choice._kotlinBoxesTextInStack(slot, context));
    }
    return kotlinReportsBaseline &&
        slot.boxes(
          reportsBaseline: true,
          paddingAddsRoom: kotlinPaddingAddsRoom,
        );
  }

  /// Every widget in this subtree, [this] first, in render order.
  ///
  /// Lets callers ask a question of a whole tree — which texts format a number,
  /// say — without pattern-matching every container along the way.
  Iterable<HWWidget> get descendants sync* {
    yield this;
    for (final child in childWidgets) {
      yield* child.descendants;
    }
  }

  /// Every widget Android renders in this subtree, [this] first, in render
  /// order.
  ///
  /// [descendants] walked through [androidChildWidgets], for the questions only
  /// the Glance output answers; the branch of an [HWAdaptive] only iOS renders
  /// is not one of them.
  Iterable<HWWidget> get androidDescendants sync* {
    yield this;
    for (final child in androidChildWidgets) {
      yield* child.androidDescendants;
    }
  }

  /// The native functions displaying this one widget, before their own
  /// dependencies are resolved.
  ///
  /// Empty for a widget that renders its values as they are stored; the ones
  /// that put a value through a native function — [HWText] formatting a number
  /// or resolving a translation, [HWImage] decoding a picture — name it here,
  /// [HWDataType.renderHelpers] of what they display included, so that a field
  /// declared but never displayed does not drag a render helper in.
  Set<HWNativeHelper> get renderHelpers => const {};

  /// The icon glyphs this one widget can render, per icon font.
  ///
  /// A constant [HWIcon] contributes its single codepoint, one bound to an
  /// [HWIconData] every codepoint that field may hold — which is what decides
  /// the glyphs the icon font is subset down to.
  Map<HWIconFont, Set<int>> get ownIconCodePoints => const {};

  /// Every custom font file this subtree renders text with.
  ///
  /// One file per family, weight and slant actually used, which is what
  /// `home_widget_cli` copies into the native projects and generates a layout
  /// for on Android.
  Set<HWFontVariant> get fontVariants {
    final variants = <HWFontVariant>{};
    for (final widget in descendants.whereType<HWFontWidget>()) {
      if (widget.fontVariant case final variant?) variants.add(variant);
    }
    return variants;
  }

  /// Whether anything in this subtree draws its text into a bitmap on Android.
  ///
  /// Held apart from [fontVariants]: a style can name a family for iOS and
  /// still ask Glance to render the Android text itself, in which case the file
  /// is bundled but no measuring pass is needed.
  bool get rendersAndroidBitmapText =>
      androidDescendants.any((widget) => widget.kotlinRendersBitmapText);

  /// Every icon glyph this subtree can render, per icon font.
  ///
  /// The union of what each [HWIcon] contributes, so a font shared by several
  /// icons is subset to all of their glyphs at once.
  Map<HWIconFont, Set<int>> get iconCodePoints {
    final glyphs = <HWIconFont, Set<int>>{};
    for (final widget in descendants) {
      widget.ownIconCodePoints.forEach((font, codePoints) {
        glyphs.putIfAbsent(font, () => <int>{}).addAll(codePoints);
      });
    }
    return glyphs;
  }

  /// The native functions this subtree calls, before their own dependencies
  /// are resolved.
  ///
  /// Two things ask for one: reading a value back — every data dependency in
  /// the subtree, whether or not anything displays it — and rendering one,
  /// which each widget answers for itself through [renderHelpers].
  Set<HWNativeHelper> get nativeHelpers {
    final helpers = <HWNativeHelper>{};
    for (final widget in descendants) {
      for (final dependency in widget.dataDependencies) {
        helpers.addAll(dependency.nativeHelpers);
      }
      helpers.addAll(widget.renderHelpers);
    }
    return helpers;
  }

  /// Generates the SwiftUI code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Swift expression to access data fields (e.g. "entry.widgetData").
  /// [dataFields] maps field keys to their types (e.g. 'title' -> HWString()).
  /// [context] carries what the platform decides rather than the tree, and is
  /// forwarded unchanged to every child.
  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  });

  /// Generates the Kotlin code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Kotlin expression to access data fields.
  /// [dataFields] maps field keys to their types.
  /// [context] carries what the platform decides rather than the tree, and is
  /// forwarded unchanged to every child.
  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  });
}

/// The [HWWidget.swiftFrameAlignment] every one of [widgets] answers with, or
/// `.topLeading` while they disagree and only the runtime knows which renders.
String _sharedSwiftFrameAlignment(Iterable<HWWidget> widgets) {
  final alignments = widgets.map((w) => w.swiftFrameAlignment).toSet();
  return alignments.length == 1 ? alignments.single : '.topLeading';
}

/// The room a widget filling the width and/or the height of what it is offered
/// asks for inside a Glance `Column` or `Row` running along [axis].
///
/// A widget filling the main axis of a `LinearLayout` takes every pixel and
/// leaves its siblings none, so along that axis it asks for the same room by
/// weight instead.
HWKotlinRoom _kotlinFillingRoom(
  HWAxis? axis, {
  bool fillsWidth = true,
  bool fillsHeight = true,
}) =>
    HWKotlinRoom(
      weight: (fillsWidth && axis == HWAxis.horizontal) ||
          (fillsHeight && axis == HWAxis.vertical),
      fillsWidth: fillsWidth && axis != HWAxis.horizontal,
      fillsHeight: fillsHeight && axis != HWAxis.vertical,
    );

/// The fixed children of the [stack], `HWColumn`, `HWRow` or `HWStack`, [obj]
/// holds.
List<HWWidget> _decodeChildren(
  DartObject obj,
  WidgetValueDecoder decoder,
  String stack,
) {
  final listValue = WidgetValueDecoder.getField(obj, 'children')?.toListValue();
  if (listValue == null) {
    // coverage:ignore-start
    throw GeneratorError('$stack: children parameter is required');
    // coverage:ignore-end
  }
  return listValue.map(decoder.decodeRecursive).toList();
}

/// How a Glance `Column` or `Row` lays out one of its children.
///
/// The stack hands it down through every widget whose Glance output is picked
/// where it sits, to the composable each of them renders, which then takes
/// the gap itself or is laid out through a `Box` of the stack's.
class _HWKotlinStackSlot {
  /// The axis the stack lays its children out along.
  final HWAxis axis;

  /// The room before the child, a Kotlin `Dp` expression so that a stack can
  /// make it depend on where the child sits, or null for none.
  ///
  /// It is padding, which Glance does not count as a child the way it counts
  /// a `Spacer`.
  final String? gap;

  /// The modifiers of the `Box` a baseline-aligned row pads the child down to
  /// its baseline through, or null for a child the row leaves where the layout
  /// puts it.
  final List<String>? placement;

  /// Whether the row turns `LinearLayout`'s baseline correction off, which a
  /// child reporting a baseline loses through a bare `Box`.
  final bool defeatsBaseline;

  const _HWKotlinStackSlot({
    required this.axis,
    this.gap,
    this.placement,
    this.defeatsBaseline = false,
  });

  /// Whether a composable answering [reportsBaseline] and [paddingAddsRoom]
  /// is laid out through a `Box` of the stack's: to be placed, to lose its
  /// baseline, or to carry a gap it cannot take itself.
  bool boxes({required bool reportsBaseline, required bool paddingAddsRoom}) =>
      placement != null ||
      (defeatsBaseline && reportsBaseline) ||
      (gap != null && !paddingAddsRoom);

  /// The code [emit] writes laid out through this slot: with the gap injected
  /// into its composable, or inside a `Box` asking for its [room] and carrying
  /// the placement and the gap.
  ///
  /// [emit] is handed the context the composable is emitted in, which a `Box`
  /// lays out rather than the stack.
  String lay(
    int indent, {
    required HWEmitContext context,
    required String Function(int indent, HWEmitContext context) emit,
    required bool reportsBaseline,
    required bool paddingAddsRoom,
    required HWKotlinRoom room,
  }) {
    final gap = _gapModifier;
    if (!boxes(
      reportsBaseline: reportsBaseline,
      paddingAddsRoom: paddingAddsRoom,
    )) {
      final code = emit(indent, context);
      return gap == null ? code : injectGlanceModifier(code, gap);
    }

    final pad = '    ' * indent;
    final modifiers = [...room.modifiers, ...?placement, if (gap != null) gap];
    final open = modifiers.isEmpty
        ? 'Box {'
        : 'Box(modifier = GlanceModifier.${modifiers.join('.')}) {';
    return '''
$pad$open
${emit(indent + 1, context.inLinear(null))}
$pad}''';
  }

  /// The imports [lay] needs, [importsIn] reporting those of the composable
  /// for the axis of the stack laying it out.
  Set<String> imports({
    required Set<String> Function(HWAxis? enclosingLinearAxis) importsIn,
    required bool reportsBaseline,
    required bool paddingAddsRoom,
    required HWKotlinRoom room,
  }) {
    final boxed = boxes(
      reportsBaseline: reportsBaseline,
      paddingAddsRoom: paddingAddsRoom,
    );
    return {
      ...importsIn(boxed ? null : axis),
      if (gap != null) ...{
        'import androidx.compose.ui.unit.dp',
        'import androidx.glance.layout.padding',
        // `injectGlanceModifier` wraps code opening with no composable of its
        // own in a `Box`.
        'import androidx.glance.layout.Box',
      },
      if (boxed) ...{
        'import androidx.glance.layout.Box',
        ...room.kotlinImports,
      },
    };
  }

  /// The padding the gap is, or null without one.
  String? get _gapModifier {
    final gap = this.gap;
    if (gap == null) return null;
    final edge = axis == HWAxis.vertical ? 'top' : 'start';
    return 'padding($edge = $gap)';
  }
}
