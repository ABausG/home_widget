part of 'hw_widget.dart';

/// A text widget for use in widgetBuilder.
///
/// Two const constructors:
/// - `HWText.fixed('Hello')` -- hardcoded string literal
/// - `HWText(HWString('key'))` -- data-bound via HWDataType
class HWText extends HWWidget implements HWDataWidget {
  final String? fixedContent;

  final HWDataType? dataType;

  @override
  List<HWDataType> get dataDependencies => [if (dataType != null) dataType!];

  /// Static/hardcoded text content.
  const HWText.fixed(String content)
      : fixedContent = content,
        dataType = null;

  const HWText(HWDataType data)
      : fixedContent = null,
        dataType = data;

  static HWText fromDartObject(DartObject obj) {
    // Check for fixed content
    final fixedContent = obj.getField('fixedContent')?.toStringValue();
    if (fixedContent != null) {
      return HWText.fixed(fixedContent);
    }

    // Check for data type
    final dataType = obj.getField('dataType');
    if (dataType != null && !dataType.isNull) {
      var key = dataType.getField('key')?.toStringValue();
      if (key == null) {
        // key lives on HWDataType (super), so analyzer may store it under (super)
        final superClass = dataType.getField('(super)');
        if (superClass != null) {
          key = superClass.getField('key')?.toStringValue();
        }
      }
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
        'Could not decode HWText. Fields: fixedContent=$fixedContent, dataType=${obj.getField('dataType')}, dataTypeType=${obj.getField('dataType')?.type?.element3?.name3}');
  }

  @override
  String toSwift(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    final fixedContent = this.fixedContent;
    if (fixedContent != null) {
      return '${pad}Text("${_escapeSwiftString(fixedContent)}")';
    } else if (dataType?.key != null) {
      final key = dataType!.key;
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
    final fixedContent = this.fixedContent;
    if (fixedContent != null) {
      return '${pad}Text(text = "${_escapeKotlinString(fixedContent)}")';
    } else if (dataType?.key != null) {
      final key = dataType!.key;
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
