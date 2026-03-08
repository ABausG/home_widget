import 'hw_color.dart';
import 'hw_generatable.dart';

/// A class representing text styling options, such as color, for `HWText`.
class HWTextStyle implements HWGeneratable {
  final HWColor? color;

  const HWTextStyle({this.color});

  /// Generates the Kotlin TextStyle declaration string.
  /// Returns `null` if the style provides no properties.
  @override
  Set<String> get kotlinImports => color?.kotlinImports ?? {};

  @override
  Set<String> get swiftViewModifiers => color?.swiftViewModifiers ?? {};

  @override
  String toSwift(int indent, {required String dataExpr}) {
    if (color == null) return '';
    return '.foregroundColor(${color!.toSwift(indent, dataExpr: dataExpr)})';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    if (color == null) return '';
    return 'TextStyle(color = ${color!.toKotlin(indent, dataExpr: dataExpr)})';
  }
}
