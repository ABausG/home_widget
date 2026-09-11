import 'package:analyzer/dart/constant/value.dart';
import '../formats.dart';
import '../generator_error.dart';
import '../native_helpers.dart';
import '../parser/widget_value_decoder.dart';
import '../types.dart';
import '../utils/apply_swift_modifier.dart';
import '../utils/inject_glance_modifier.dart';
import '../utils/string_literals.dart';
import 'hw_alignment.dart';
import 'hw_color.dart';
import 'hw_generatable.dart';
import 'hw_text_style.dart';
import 'hw_edge_insets.dart';

part 'hw_column.dart';
part 'hw_row.dart';
part 'hw_text.dart';
part 'hw_image.dart';
part 'hw_data_only.dart';
part 'hw_adaptive.dart';
part 'hw_fill.dart';
part 'hw_colored_box.dart';
part 'hw_decorated_box.dart';
part 'hw_padding.dart';
part 'hw_conditional.dart';

/// Base class for widgets that accept a single child (e.g. Expanded).
sealed class HWSingleChildWidget extends HWWidget {
  final HWWidget child;

  const HWSingleChildWidget({required this.child});

  @override
  Set<String> get kotlinImports => child.kotlinImports;

  @override
  Set<String> get swiftViewModifiers => child.swiftViewModifiers;

  @override
  Set<HWDataType<dynamic>> get dataDependencies => child.dataDependencies;

  @override
  List<HWWidget> get childWidgets => [child];
}

/// Base class for widgets that accept multiple children (e.g. Column, Row).
sealed class HWMultiChildWidget extends HWWidget {
  final List<HWWidget> children;

  const HWMultiChildWidget({required this.children});

  @override
  Set<String> get kotlinImports {
    return children.expand((child) => child.kotlinImports).toSet();
  }

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

  /// The native functions displaying this one widget, before their own
  /// dependencies are resolved.
  ///
  /// Empty for a widget that renders its values as they are stored; the ones
  /// that put a value through a native function — [HWText] formatting a number
  /// or resolving a translation, [HWImage] decoding a picture — name it here,
  /// [HWDataType.renderHelpers] of what they display included, so that a field
  /// declared but never displayed does not drag a render helper in.
  Set<HWNativeHelper> get renderHelpers => const {};

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
  @override
  String toSwift(
    int indent, {
    required String dataExpr,
  });

  /// Generates the Kotlin code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Kotlin expression to access data fields.
  /// [dataFields] maps field keys to their types.
  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
  });
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
