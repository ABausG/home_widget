part of 'hw_widget.dart';

/// A text widget for use in widgetBuilder.
///
/// Two const constructors:
/// - `HWText.fixed('Hello')` -- hardcoded string literal
/// - `HWText(HWString('key'))` -- data-bound via HWDataType
class HWText extends HWWidget implements HWDataWidget {
  final String? fixedContent;

  final HWDataType? dataType;
  final HWTextStyle? style;

  @override
  Set<HWDataType> get dataDependencies => {if (dataType != null) dataType!};

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      'import androidx.glance.text.Text',
      'import androidx.glance.text.TextStyle'
    };
    if (style != null) {
      imports.addAll(style!.kotlinImports);
    }
    return imports;
  }

  @override
  Set<String> get swiftViewModifiers {
    final modifiers = <String>{};
    if (style != null) {
      modifiers.addAll(style!.swiftViewModifiers);
    }
    return modifiers;
  }

  /// Static/hardcoded text content.
  const HWText.fixed(String content, {this.style})
      : fixedContent = content,
        dataType = null;

  const HWText(HWDataType data, {this.style})
      : fixedContent = null,
        dataType = data;

  static HWText fromDartObject(DartObject obj) {
    HWTextStyle? style;
    final styleObj = obj.getField('style');
    if (styleObj != null && !styleObj.isNull) {
      final color = WidgetValueDecoder.decodeColor(styleObj.getField('color'));
      style = HWTextStyle(color: color);
    }

    // Check for fixed content
    final fixedContent = obj.getField('fixedContent')?.toStringValue();
    if (fixedContent != null) {
      return HWText.fixed(fixedContent, style: style);
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
        if (typeName == 'HWString') return HWText(HWString(key), style: style);
        if (typeName == 'HWInt') return HWText(HWInt(key), style: style);
        if (typeName == 'HWDouble') return HWText(HWDouble(key), style: style);
        if (typeName == 'HWBool') return HWText(HWBool(key), style: style);
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

    var viewCall = '';
    if (fixedContent != null) {
      viewCall = '${pad}Text("${_escapeSwiftString(fixedContent)}")';
    } else if (dataType != null) {
      final key = dataType!.key;
      final textValue = dataType!.iosToString(
        outerValue: '$dataExpr.$key',
        innerValue: '$dataExpr.$key!',
      );
      viewCall = '${pad}Text($textValue)';
    }

    if (viewCall.isNotEmpty && style != null) {
      final styleCode = style!.toSwift(indent, dataExpr: dataExpr);
      if (styleCode.isNotEmpty) {
        viewCall += '\n$pad    $styleCode';
      }
    }

    return viewCall;
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level
    final fixedContent = this.fixedContent;

    var textArgs = '';
    if (fixedContent != null) {
      textArgs = 'text = "${_escapeKotlinString(fixedContent)}"';
    } else if (dataType != null) {
      final key = dataType!.key;
      final textValue = dataType!.androidToString(
        outerValue: '$dataExpr.$key',
        innerValue: '$dataExpr.$key',
      );
      textArgs = 'text = $textValue';
    }

    if (textArgs.isNotEmpty) {
      final styleCode = style?.toKotlin(indent, dataExpr: dataExpr);
      if (styleCode != null && styleCode.isNotEmpty) {
        return '${pad}Text($textArgs, style = $styleCode)';
      }
      return '${pad}Text($textArgs)';
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
