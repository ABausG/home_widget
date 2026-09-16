/// Cross-axis alignment for HWColumn/HWRow.
///
/// For HWColumn (vertical), cross-axis is horizontal.
/// For HWRow (horizontal), cross-axis is vertical.
///
/// Defaults to [center] on both platforms when left unset.
enum HWCrossAxisAlignment {
  start,
  center,
  end,

  /// Aligns the first text baselines of the children.
  ///
  /// Only meaningful on an HWRow: a column's cross axis is horizontal and has
  /// no baseline, so an HWColumn asking for it fails generation.
  baseline,
}

/// Main-axis alignment for HWColumn/HWRow.
///
/// For HWColumn (vertical), main-axis is vertical.
/// For HWRow (horizontal), main-axis is horizontal.
enum HWMainAxisAlignment {
  start,
  center,
  end,
  spaceBetween,
  spaceEvenly,
}
