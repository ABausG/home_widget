import 'package:analyzer/dart/constant/value.dart';
import '../generator_error.dart';
import '../parser/widget_value_decoder.dart';
import '../types.dart';
import '../utils/apply_swift_modifier.dart';
import '../utils/inject_glance_modifier.dart';
import 'hw_alignment.dart';
import 'hw_color.dart';
import 'hw_generatable.dart';
import 'hw_text_style.dart';
import 'hw_edge_insets.dart';

part 'hw_column.dart';
part 'hw_row.dart';
part 'hw_text.dart';
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
