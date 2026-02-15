import 'hw_alignment.dart';
import '../hw_widget.dart';

/// A horizontal layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI HStack and Glance Row.
class HWRow extends HWWidget {
  final List<HWWidget> children;
  final HWCrossAxisAlignment? crossAxisAlignment;
  final HWMainAxisAlignment? mainAxisAlignment;

  const HWRow({
    required this.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });
}
