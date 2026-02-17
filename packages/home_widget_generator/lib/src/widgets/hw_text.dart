part of 'hw_widget.dart';

/// A text widget for use in widgetBuilder.
///
/// Two const constructors:
/// - `HWText.fixed('Hello')` -- hardcoded string literal
/// - `HWText.data(ref)` -- data-bound via HWDataRef
class HWText extends HWWidget implements HWDataWidget {
  final String? _fixedContent;

  final HWDataRef? dataRef;

  final HWDataType? dataType;

  @override
  List<HWDataType> get dataDependencies => [if (dataType != null) dataType!];

  /// Static/hardcoded text content.
  const HWText.fixed(String content)
      : _fixedContent = content,
        dataRef = null,
        dataType = null;

  /// Data-bound text content from a generated HWDataRef.
  const HWText.data(HWDataRef ref)
      : _fixedContent = null,
        dataRef = ref,
        dataType = null;

  const HWText(HWDataType data)
      : _fixedContent = null,
        dataRef = null,
        dataType = data;

  static HWText fromDartObject(DartObject obj) {
    // Check for fixed content
    final fixedContent = obj.getField('_fixedContent')?.toStringValue();
    if (fixedContent != null) {
      return HWText.fixed(fixedContent);
    }

    // Check for data ref
    final dataRef = obj.getField('dataRef');
    if (dataRef != null && !dataRef.isNull) {
      final key = dataRef.getField('key')?.toStringValue();
      if (key != null) {
        return HWText.data(HWDataRef(key));
      }
    }

    // Check for data type
    final dataType = obj.getField('dataType');
    if (dataType != null && !dataType.isNull) {
      final key = dataType.getField('key')?.toStringValue();
      final typeName = dataType.type?.element3?.name3;

      if (key != null) {
        if (typeName == 'HWString') return HWText(HWString(key));
        if (typeName == 'HWInt') return HWText(HWInt(key));
        if (typeName == 'HWDouble') return HWText(HWDouble(key));
        if (typeName == 'HWBool') return HWText(HWBool(key));
      }
    }

    // Fallback/Error?
    throw GeneratorError(
        'Could not decode HWText. Fields: fixedContent=$fixedContent, dataRef=${obj.getField('dataRef')}, dataType=${obj.getField('dataType')}, dataTypeType=${obj.getField('dataType')?.type?.element3?.name3}');
  }

  @override
  String toSwift(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    if (_fixedContent != null) {
      return '${pad}Text("${_escapeSwiftString(_fixedContent)}")';
    } else if (dataRef != null || dataType?.key != null) {
      final key = dataRef?.key ?? dataType!.key;
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
    } else if (dataRef != null || dataType?.key != null) {
      final key = dataRef?.key ?? dataType!.key;
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
