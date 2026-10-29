import 'package:analyzer/dart/constant/value.dart';

/// A size in dp, as declared to Glance on Android.
class HWSize {
  /// The width in dp.
  final double width;

  /// The height in dp.
  final double height;

  const HWSize(this.width, this.height);

  /// The size of a [columns] × [rows] home-screen cell footprint, `70 × n − 30`
  /// per axis.
  ///
  /// Deliberately conservative: real launcher cells are larger, so a declared
  /// size fits its cell footprint on every launcher.
  const HWSize.cells(int columns, int rows)
      : width = 70.0 * columns - 30.0,
        height = 70.0 * rows - 30.0;

  /// The dp extent of [cells] home-screen cells along one axis.
  static double cellExtent(int cells) => 70.0 * cells - 30.0;

  /// Reads an `HWSize` constant, or null when [obj] is absent or carries no
  /// dimensions.
  static HWSize? fromDartObject(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final width = dimensionOf(obj, 'width');
    final height = dimensionOf(obj, 'height');
    if (width == null || height == null) return null;

    return HWSize(width, height);
  }

  /// The dp field [name] of [obj], written as either an `int` or a `double`
  /// literal, or null when it carries neither.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code. Not
  /// marked `@internal` because that package is a separate one and would then
  /// fail its own analyze.
  static double? dimensionOf(DartObject obj, String name) {
    final field = obj.getField(name);
    return field?.toDoubleValue() ?? field?.toIntValue()?.toDouble();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'HWSize(${dimension(width)}, ${dimension(height)})';

  /// This size as the Kotlin `DpSize` the generated widget declares and
  /// compares against.
  String toKotlin() =>
      'DpSize(${dimension(width)}.dp, ${dimension(height)}.dp)';

  /// [value] without the trailing `.0` of a whole number, so a dp literal and
  /// a `toString` read the way they were written.
  static String dimension(double value) {
    final rounded = value.round();
    return value == rounded ? '$rounded' : '$value';
  }
}
