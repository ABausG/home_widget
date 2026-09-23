/// Where a child sits inside the room it is given, Flutter's
/// `AlignmentDirectional`.
///
/// Only the directional constants: SwiftUI has `.topLeading`, Glance
/// `Alignment.TopStart`, and neither has a left that stays left in a
/// right-to-left layout.
enum HWAlignment {
  topStart,
  topCenter,
  topEnd,
  centerStart,
  center,
  centerEnd,
  bottomStart,
  bottomCenter,
  bottomEnd,
}

/// The constants an [HWAlignment] places a child by on each platform.
extension HWAlignmentPlacement on HWAlignment {
  /// The SwiftUI `Alignment` literal.
  String get swiftAlignment => switch (this) {
        HWAlignment.topStart => '.topLeading',
        HWAlignment.topCenter => '.top',
        HWAlignment.topEnd => '.topTrailing',
        HWAlignment.centerStart => '.leading',
        HWAlignment.center => '.center',
        HWAlignment.centerEnd => '.trailing',
        HWAlignment.bottomStart => '.bottomLeading',
        HWAlignment.bottomCenter => '.bottom',
        HWAlignment.bottomEnd => '.bottomTrailing',
      };

  /// The Glance `Alignment` expression.
  String get kotlinAlignment => switch (this) {
        HWAlignment.topStart => 'Alignment.TopStart',
        HWAlignment.topCenter => 'Alignment.TopCenter',
        HWAlignment.topEnd => 'Alignment.TopEnd',
        HWAlignment.centerStart => 'Alignment.CenterStart',
        HWAlignment.center => 'Alignment.Center',
        HWAlignment.centerEnd => 'Alignment.CenterEnd',
        HWAlignment.bottomStart => 'Alignment.BottomStart',
        HWAlignment.bottomCenter => 'Alignment.BottomCenter',
        HWAlignment.bottomEnd => 'Alignment.BottomEnd',
      };
}

/// How an [HWStack] sizes itself and its children, Flutter's `StackFit`
/// without `passthrough`.
enum HWStackFit {
  /// The stack is as large as its largest child, each child at its own size.
  loose,

  /// The stack takes every pixel it is offered, and gives that same room to
  /// every child, which the alignment then places in it.
  expand,
}

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

/// How a stack carries out a main-axis alignment: with spacers, which need
/// more room than the children take.
extension HWMainAxisAlignmentFill on HWMainAxisAlignment? {
  /// Whether the alignment is carried by spacers, which only take room in a
  /// layout that fills its main axis.
  bool get fillsMainAxis => switch (this) {
        HWMainAxisAlignment.center ||
        HWMainAxisAlignment.end ||
        HWMainAxisAlignment.spaceBetween ||
        HWMainAxisAlignment.spaceEvenly =>
          true,
        HWMainAxisAlignment.start || null => false,
      };

  /// Whether a spacer goes before the first child.
  bool get hasLeadingSpacer => switch (this) {
        HWMainAxisAlignment.center ||
        HWMainAxisAlignment.end ||
        HWMainAxisAlignment.spaceEvenly =>
          true,
        HWMainAxisAlignment.start ||
        HWMainAxisAlignment.spaceBetween ||
        null =>
          false,
      };

  /// Whether a spacer goes between every two adjacent children.
  bool get hasSpacerBetween => switch (this) {
        HWMainAxisAlignment.spaceBetween ||
        HWMainAxisAlignment.spaceEvenly =>
          true,
        HWMainAxisAlignment.start ||
        HWMainAxisAlignment.center ||
        HWMainAxisAlignment.end ||
        null =>
          false,
      };

  /// Whether a spacer goes after the last child.
  bool get hasTrailingSpacer => switch (this) {
        HWMainAxisAlignment.center || HWMainAxisAlignment.spaceEvenly => true,
        HWMainAxisAlignment.start ||
        HWMainAxisAlignment.end ||
        HWMainAxisAlignment.spaceBetween ||
        null =>
          false,
      };

  /// How many spacers the alignment puts among [children] children.
  ///
  /// Glance counts every spacer as a child of the stack, so a stack holds
  /// `children + spacerCount(children)` of them.
  int spacerCount(int children) =>
      (hasLeadingSpacer ? 1 : 0) +
      (hasSpacerBetween && children > 1 ? children - 1 : 0) +
      (hasTrailingSpacer ? 1 : 0);
}
