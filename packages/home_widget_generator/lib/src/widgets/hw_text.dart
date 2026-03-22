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
  final HWTextAlign? textAlign;

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
    if (textAlign != null) {
      imports.add('import androidx.glance.text.TextAlign');
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
  const HWText.fixed(String content, {this.style, this.textAlign})
      : fixedContent = content,
        dataType = null;

  const HWText(HWDataType data, {this.style, this.textAlign})
      : fixedContent = null,
        dataType = data;

  static HWText fromDartObject(DartObject obj) {
    var style = WidgetValueDecoder.decodeTextStyle(obj.getField('style'));
    var textAlign =
        WidgetValueDecoder.decodeTextAlign(obj.getField('textAlign'));

    // Check for fixed content
    final fixedContent = obj.getField('fixedContent')?.toStringValue();
    if (fixedContent != null) {
      return HWText.fixed(fixedContent, style: style, textAlign: textAlign);
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
        switch (typeName) {
          case 'HWString':
            return HWText(HWString(key), style: style, textAlign: textAlign);
          case 'HWInt':
            return HWText(HWInt(key), style: style, textAlign: textAlign);
          case 'HWDouble':
            return HWText(HWDouble(key), style: style, textAlign: textAlign);
          case 'HWBool':
            return HWText(HWBool(key), style: style, textAlign: textAlign);
        }
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

    if (viewCall.isNotEmpty) {
      if (style != null) {
        final styleCode = style!.toSwift(indent, dataExpr: dataExpr);
        if (styleCode.isNotEmpty) {
          viewCall += '\n$pad    $styleCode';
        }
      }
      if (textAlign != null) {
        viewCall +=
            '\n$pad    .multilineTextAlignment(${_swiftTextAlign(textAlign!)})';
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
      final styleCode = style?.toKotlin(indent, dataExpr: dataExpr) ?? '';

      if (textAlign != null) {
        final alignCode = 'textAlign = ${_kotlinTextAlign(textAlign!)}';
        if (styleCode.isEmpty) {
          textArgs += ', style = TextStyle($alignCode)';
        } else {
          final newStyleCode = styleCode.replaceFirst(')', ', $alignCode)');
          textArgs += ', style = $newStyleCode';
        }
      } else if (styleCode.isNotEmpty) {
        textArgs += ', style = $styleCode';
      }

      return '${pad}Text($textArgs)';
    }

    return '';
  }

  String _swiftTextAlign(HWTextAlign align) {
    switch (align) {
      case HWTextAlign.start:
        return '.leading';
      case HWTextAlign.end:
        return '.trailing';
      case HWTextAlign.center:
        return '.center';
      case HWTextAlign.justify:
        return '.leading'; // default LTR fallback
    }
  }

  String _kotlinTextAlign(HWTextAlign align) {
    switch (align) {
      case HWTextAlign.start:
        return 'TextAlign.Start';
      case HWTextAlign.end:
        return 'TextAlign.End';
      case HWTextAlign.center:
        return 'TextAlign.Center';
      case HWTextAlign.justify:
        return 'TextAlign.Start'; // default fallback
    }
  }

  String _escapeSwiftString(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  String _escapeKotlinString(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\$', '\\\$');
}
