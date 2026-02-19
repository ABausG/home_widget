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
  Set<HWDataType> get dataDependencies => {if (dataType != null) dataType!};

  @override
  Set<String> get kotlinImports => {
        'import androidx.glance.text.Text',
        'import androidx.glance.text.TextStyle'
      };

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
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    final fixedContent = this.fixedContent;
    if (fixedContent != null) {
      return '${pad}Text("${_escapeSwiftString(fixedContent)}")';
    } else if (dataType?.key != null) {
      final key = dataType!.key;
      final textValue = dataType!.iosToString(
        outerValue: '$dataExpr.$key',
        innerValue: '$dataExpr.$key!',
      );
      return '${pad}Text($textValue)';
    }
    return '';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final fixedContent = this.fixedContent;
    if (fixedContent != null) {
      return '${pad}Text(text = "${_escapeKotlinString(fixedContent)}")';
    } else if (dataType?.key != null) {
      final key = dataType!.key;
      final textValue = dataType!.androidToString(
        outerValue: '$dataExpr.$key',
        innerValue: '$dataExpr.$key',
      );
      return '${pad}Text(text = $textValue)';
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
