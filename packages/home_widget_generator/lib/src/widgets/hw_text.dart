import '../hw_widget.dart';
import '../data_ref.dart';

/// A text widget for use in widgetBuilder.
///
/// Two const constructors:
/// - `HWText.fixed('Hello')` -- hardcoded string literal
/// - `HWText.data(ref)` -- data-bound via HWDataRef
class HWText extends HWWidget {
  // ignore: unused_field
  final String? _fixedContent;
  // ignore: unused_field
  final HWDataRef? _dataRef;

  /// Static/hardcoded text content.
  const HWText.fixed(String content)
      : _fixedContent = content,
        _dataRef = null;

  /// Data-bound text content from a generated HWDataRef.
  const HWText.data(HWDataRef ref)
      : _fixedContent = null,
        _dataRef = ref;
}
