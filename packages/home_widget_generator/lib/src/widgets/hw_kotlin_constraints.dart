import '../utils/string_literals.dart';

/// The space a widget renders in, as the generated Kotlin can name it.
///
/// Glance has no `BoxWithConstraints`, so what ancestors take off
/// `LocalSize.current` is folded in here and passed down while the tree is
/// emitted.
class HWKotlinConstraints {
  /// The dp across that ancestors have already taken for themselves: their
  /// padding, and the siblings of a row that render at a size of their own.
  final double horizontalInset;

  /// The dp down that ancestors have already taken for themselves.
  final double verticalInset;

  const HWKotlinConstraints({
    this.horizontalInset = 0,
    this.verticalInset = 0,
  });

  /// The whole widget, before anything in it has taken its share.
  static const HWKotlinConstraints widget = HWKotlinConstraints();

  /// These constraints with [horizontal] dp across and [vertical] dp down
  /// taken by whatever encloses the widget that gets them.
  HWKotlinConstraints deflate({double horizontal = 0, double vertical = 0}) =>
      HWKotlinConstraints(
        horizontalInset: horizontalInset + horizontal,
        verticalInset: verticalInset + vertical,
      );

  /// The Kotlin `Float` expression for the dp available across.
  String get kotlinMaxWidth =>
      _dpExpression(horizontalInset, 'LocalSize.current.width.value');

  /// The Kotlin `Float` expression for the dp available down.
  String get kotlinMaxHeight =>
      _dpExpression(verticalInset, 'LocalSize.current.height.value');

  /// [widgetSize] less [inset], floored at zero: a widget smaller than what its
  /// ancestors took would otherwise ask for a negative size.
  static String _dpExpression(double inset, String widgetSize) {
    if (inset == 0) return widgetSize;
    return 'maxOf(0f, $widgetSize - ${hwSizeLiteral(inset)}f)';
  }
}
