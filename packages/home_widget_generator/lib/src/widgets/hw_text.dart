part of 'hw_widget.dart';

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

  @override
  String toSwift(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    if (_fixedContent != null) {
      return '${pad}Text("${_escapeSwiftString(_fixedContent)}")';
    } else if (_dataRef != null) {
      final key = _dataRef.key;
      final type = dataFields[key];

      switch (type) {
        case HWString():
          return '${pad}Text($dataExpr.$key ?? "")';
        case HWInt():
          return '${pad}Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "0")';
        case HWDouble():
          return '${pad}Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "0.0")';
        case HWBool():
          return '${pad}Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "false")';
        case null:
          // Fallback or error? For now fallback to string assumption
          return '${pad}Text($dataExpr.$key ?? "")';
      }
    }
    return '';
  }

  @override
  String toKotlin(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    if (_fixedContent != null) {
      return '${pad}Text(text = "${_escapeKotlinString(_fixedContent)}")';
    } else if (_dataRef != null) {
      final key = _dataRef.key;
      final type = dataFields[key];

      switch (type) {
        case HWString():
          return '${pad}Text(text = $dataExpr.$key ?: "")';
        case HWInt():
          return '${pad}Text(text = ($dataExpr.$key?.toString() ?: "0"))';
        case HWDouble():
          return '${pad}Text(text = ($dataExpr.$key?.toString() ?: "0.0"))';
        case HWBool():
          return '${pad}Text(text = ($dataExpr.$key?.toString() ?: "false"))';
        case null:
          return '${pad}Text(text = $dataExpr.$key ?: "")';
      }
    }
    return '';
  }

  String _escapeSwiftString(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  String _escapeKotlinString(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\$', '\\\$');
}
