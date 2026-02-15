import 'hw_alignment.dart';
import '../hw_widget.dart';

/// A vertical layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI VStack and Glance Column.
class HWColumn extends HWWidget {
  final List<HWWidget> children;
  final HWCrossAxisAlignment? crossAxisAlignment;
  final HWMainAxisAlignment? mainAxisAlignment;

  const HWColumn({
    required this.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });
}
