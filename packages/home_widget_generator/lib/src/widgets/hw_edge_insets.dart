/// Represents padding around a widget.
class HWEdgeInsets {
  final double top;
  final double bottom;
  final double left;
  final double right;

  const HWEdgeInsets.all(double value)
      : top = value,
        bottom = value,
        left = value,
        right = value;

  const HWEdgeInsets.symmetric({
    double vertical = 0.0,
    double horizontal = 0.0,
  })  : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  const HWEdgeInsets.only({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWEdgeInsets &&
          top == other.top &&
          bottom == other.bottom &&
          left == other.left &&
          right == other.right;

  @override
  int get hashCode =>
      top.hashCode ^ bottom.hashCode ^ left.hashCode ^ right.hashCode;
}
