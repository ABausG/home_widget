part of 'hw_widget.dart';

/// A text widget for use in widgetBuilder.
///
/// Two const constructors:
/// - `HWText.fixed('Hello')` -- hardcoded string literal
/// - `HWText(HWString('key'))` -- data-bound via HWDataType
class HWText extends HWWidget implements HWDataWidget {
  final String? fixedContent;

  final HWDataType<dynamic>? dataType;

  /// Raw locale map from [HWText.localized]. See [effectiveDataType].
  final Map<String, String>? localizedContent;

  final HWTextStyle? style;
  final HWTextAlign? textAlign;

  /// The data type this text renders from, wrapping [localizedContent] when the
  /// widget was built with [HWText.localized].
  HWDataType<dynamic>? get effectiveDataType {
    final dataType = this.dataType;
    if (dataType != null) return dataType;
    final content = localizedContent;
    if (content == null) return null;
    return HWLocalizedString.constant(defaultTranslations: content);
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies {
    final data = effectiveDataType;
    return {if (data != null) data};
  }

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      'import androidx.glance.text.Text',
      'import androidx.glance.text.TextStyle',
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
        dataType = null,
        localizedContent = null;

  /// Static text translated at build time.
  ///
  /// [content] maps locale tag to text and must include the widget's
  /// `defaultLocale`. Unlike [HWText.new] with [HWString.localized], this
  /// creates no data field and cannot be overridden at runtime.
  ///
  /// The map is held raw rather than wrapped in an [HWLocalizedString] because
  /// a const constructor cannot build another object from a parameter.
  /// [effectiveDataType] does the wrapping, and the parser replaces it with a
  /// locale-resolved instance.
  const HWText.localized(
    Map<String, String> content, {
    this.style,
    this.textAlign,
  })  : fixedContent = null,
        dataType = null,
        localizedContent = content;

  const HWText(HWDataType<dynamic> data, {this.style, this.textAlign})
      : fixedContent = null,
        dataType = data,
        localizedContent = null;

  static HWText fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    var style = WidgetValueDecoder.decodeTextStyle(obj.getField('style'));
    var textAlign =
        WidgetValueDecoder.decodeTextAlign(obj.getField('textAlign'));

    // Check for fixed content
    final fixedContent = obj.getField('fixedContent')?.toStringValue();
    if (fixedContent != null) {
      return HWText.fixed(fixedContent, style: style, textAlign: textAlign);
    }

    // Check for an inline locale map (HWText.localized)
    final localizedContent =
        WidgetValueDecoder.decodeStringMap(obj.getField('localizedContent'));
    if (localizedContent != null) {
      return HWText(
        HWLocalizedString.resolved(
          '',
          defaultTranslations: localizedContent,
          isConstant: true,
          defaultLocale: decoder.defaultLocale,
          resourcePrefix: decoder.resourcePrefix,
        ),
        style: style,
        textAlign: textAlign,
      );
    }

    // Check for data type
    final dataTypeObj = obj.getField('dataType');
    final dataType = WidgetValueDecoder.decodeDataType(
      dataTypeObj,
      defaultLocale: decoder.defaultLocale,
      resourcePrefix: decoder.resourcePrefix,
    );
    if (dataType != null) {
      return HWText(dataType, style: style, textAlign: textAlign);
    }

    // coverage:ignore-start
    throw GeneratorError(
      'Could not decode HWText. Fields: fixedContent=$fixedContent, dataType=${obj.getField('dataType')}, dataTypeType=${obj.getField('dataType')?.type?.element?.name}',
    );
    // coverage:ignore-end
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    final fixedContent = this.fixedContent;

    var viewCall = '';
    if (fixedContent != null) {
      viewCall = '${pad}Text("${escapeSwiftStringLiteral(fixedContent)}")';
    } else if (effectiveDataType != null) {
      final bound = effectiveDataType!;
      if (bound is HWJson) {
        final expr = bound.swiftGlanceJsonTextInterpolation(dataExpr);
        viewCall = '${pad}Text($expr)';
      } else {
        final outerValue = bound.swiftAccess(dataExpr);
        final innerValue = '${outerValue.replaceAll('?.', '!.')}!';
        final textValue = bound.iosToString(
          outerValue: outerValue,
          innerValue: innerValue,
        );
        viewCall = '${pad}Text($textValue)';
      }
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
      textArgs = 'text = "${escapeKotlinStringLiteral(fixedContent)}"';
    } else if (effectiveDataType != null) {
      final bound = effectiveDataType!;
      if (bound is HWJson) {
        textArgs =
            'text = ${bound.kotlinGlanceJsonTextInterpolation(dataExpr)}';
      } else {
        final access = bound.kotlinAccess(dataExpr);
        final textValue = bound.androidToString(
          outerValue: access,
          innerValue: access,
        );
        textArgs = 'text = $textValue';
      }
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
}
