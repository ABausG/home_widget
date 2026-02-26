import 'package:analyzer/dart/constant/value.dart';
import '../generator_error.dart';
import '../parser/widget_value_decoder.dart';
import '../types.dart';
import '../utils/glance_utils.dart';
import 'hw_alignment.dart';

part 'hw_column.dart';
part 'hw_row.dart';
part 'hw_text.dart';
part 'hw_data_only.dart';
part 'hw_adaptive.dart';
part 'hw_fill.dart';

/// Base class for widgets that accept a single child (e.g. Expanded).
sealed class HWSingleChildWidget extends HWWidget {
  final HWWidget child;

  const HWSingleChildWidget({required this.child});

  @override
  Set<String> get kotlinImports => child.kotlinImports;

  @override
  Set<HWDataType> get dataDependencies => child.dataDependencies;
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
  Set<HWDataType> get dataDependencies {
    return children.expand((child) => child.dataDependencies).toSet();
  }
}

/// Interface for widgets that hold data dependencies.
abstract interface class HWDataWidget {
  Set<HWDataType> get dataDependencies;
}

/// Abstract base class for all DSL widgets used in widgetBuilder.
/// Subclasses: HWText (v3), HWColumn, HWRow (v4).
sealed class HWWidget {
  const HWWidget();

  /// The set of Kotlin imports required by this widget.
  Set<String> get kotlinImports => {};

  /// The set of data dependencies required by this widget.
  Set<HWDataType> get dataDependencies => {};

  /// Generates the SwiftUI code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Swift expression to access data fields (e.g. "entry.widgetData").
  /// [dataFields] maps field keys to their types (e.g. 'title' -> HWString()).
  String toSwift(
    int indent, {
    required String dataExpr,
  });

  /// Generates the Kotlin code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Kotlin expression to access data fields.
  /// [dataFields] maps field keys to their types.
  String toKotlin(
    int indent, {
    required String dataExpr,
  });
}
