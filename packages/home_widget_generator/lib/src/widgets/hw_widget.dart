import 'package:analyzer/dart/constant/value.dart';
import '../generator_error.dart';
import '../parser/widget_value_decoder.dart';
import '../data_ref.dart';
import '../types.dart';
import 'hw_alignment.dart';

part 'hw_column.dart';
part 'hw_row.dart';
part 'hw_text.dart';
part 'hw_data_only.dart';

/// Base class for widgets that accept multiple children (e.g. Column, Row).
sealed class HWMultiChildWidget extends HWWidget {
  final List<HWWidget> children;

  const HWMultiChildWidget({required this.children});
}

/// Interface for widgets that hold data dependencies.
abstract interface class HWDataWidget {
  List<HWDataType> get dataDependencies;
}

/// Abstract base class for all DSL widgets used in widgetBuilder.
/// Subclasses: HWText (v3), HWColumn, HWRow (v4).
sealed class HWWidget {
  const HWWidget();

  /// Generates the SwiftUI code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Swift expression to access data fields (e.g. "entry.widgetData").
  /// [dataFields] maps field keys to their types (e.g. 'title' -> HWString()).
  String toSwift(
    int indent, {
    required String dataExpr,
    Map<String, HWDataType> dataFields = const {},
  });

  /// Generates the Kotlin code for this widget.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Kotlin expression to access data fields.
  /// [dataFields] maps field keys to their types.
  String toKotlin(
    int indent, {
    required String dataExpr,
    Map<String, HWDataType> dataFields = const {},
  });
}
