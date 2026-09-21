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

part 'hw_column.dart';
part 'hw_row.dart';
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

/// Base class for widgets that accept a single child (e.g. Expanded).
sealed class HWSingleChildWidget extends HWWidget {
  final HWWidget child;

  const HWSingleChildWidget({required this.child});

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
}

/// Base class for widgets that accept multiple children (e.g. Column, Row).
sealed class HWMultiChildWidget extends HWWidget {
  final List<HWWidget> children;

  const HWMultiChildWidget({required this.children});

  @override
  Set<String> get swiftViewModifiers {
    return children.expand((child) => child.swiftViewModifiers).toSet();
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies {
    return children.expand((child) => child.dataDependencies).toSet();
  }

  @override
  List<HWWidget> get childWidgets => children;
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
  bool get kotlinReportsBaseline => false;

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

  /// [kotlinImports], for a widget emitted directly inside a Glance `Column` or
  /// `Row` running along [enclosingLinearAxis].
  ///
  /// A layout asking for its whole main axis takes a weight instead of a fill
  /// there, and the two need different imports; every widget that passes its
  /// own composable's modifier down forwards the axis, and one emitting a `Box`
  /// of its own clears it.
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => kotlinImports;

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

void _emitChildrenWithMainAxisAlignment(
  List<HWWidget> children,
  StringBuffer buffer,
  int indent,
  String dataExpr,
  HWMainAxisAlignment? alignment,
  String Function(HWWidget child, int indent, String dataExpr) childGenerator,
  String Function(String childPad) spacerGenerator,
) {
  final childPad = '    ' * indent;

  switch (alignment) {
    case HWMainAxisAlignment.center:
      buffer.writeln(spacerGenerator(childPad));
      for (final child in children) {
        buffer.writeln(childGenerator(child, indent, dataExpr));
      }
      buffer.writeln(spacerGenerator(childPad));
    case HWMainAxisAlignment.end:
      buffer.writeln(spacerGenerator(childPad));
      for (final child in children) {
        buffer.writeln(childGenerator(child, indent, dataExpr));
      }
    case HWMainAxisAlignment.spaceBetween:
      for (var i = 0; i < children.length; i++) {
        if (i > 0) {
          buffer.writeln(spacerGenerator(childPad));
        }
        buffer.writeln(childGenerator(children[i], indent, dataExpr));
      }
    case HWMainAxisAlignment.spaceEvenly:
      buffer.writeln(spacerGenerator(childPad));
      for (var i = 0; i < children.length; i++) {
        if (i > 0) {
          buffer.writeln(spacerGenerator(childPad));
        }
        buffer.writeln(childGenerator(children[i], indent, dataExpr));
      }
      buffer.writeln(spacerGenerator(childPad));
    case HWMainAxisAlignment.start:
    case null:
      for (final child in children) {
        buffer.writeln(childGenerator(child, indent, dataExpr));
      }
  }
}
