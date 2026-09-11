part of 'hw_widget.dart';

/// A text widget for use in widgetBuilder.
///
/// Const constructors:
/// - `HWText.fixed('Hello')` -- hardcoded string literal
/// - `HWText.localized({...})` -- hardcoded string, translated at build time
/// - `HWText(HWString('key'))` -- data-bound via HWDataType
/// - `HWText.number(HWInt('key'), format: ...)` -- data-bound number, formatted
///   natively in the device's locale
/// - `HWText.fixedNumber(1234, format: ...)` -- hardcoded number, formatted the
///   same way
/// - `HWText.dateTime(HWDateTime('key'), format: ...)` -- data-bound date,
///   formatted in the device's locale and time zone
class HWText extends HWWidget implements HWDataWidget {
  final String? fixedContent;

  final HWDataType<dynamic>? dataType;

  /// Raw locale map from [HWText.localized], as written in the annotation.
  ///
  /// Only ever set on the const instance living inside the annotation: the
  /// parser reads it and hands back an [HWText] bound to a locale-resolved
  /// [HWLocalizedString] instead, so a parsed tree always carries [dataType].
  final Map<String, String>? localizedContent;

  /// How a number renders, from [HWText.number] or [HWText.fixedNumber].
  final HWNumberFormat? numberFormat;

  /// How a date renders, from [HWText.dateTime].
  final HWDateFormat? dateFormat;

  /// The hardcoded number from [HWText.fixedNumber].
  final num? fixedNumber;

  /// The zone a date is displayed in, from [HWText.dateTime].
  final HWTimeZone timeZone;

  final HWTextStyle? style;
  final HWTextAlign? textAlign;

  /// The bound value plus whatever the format itself reads.
  ///
  /// A data-bound currency or time zone is a data field like any other, and a
  /// text is the only place it is named, so it has to be surfaced here or the
  /// generated data class would never carry it.
  @override
  Set<HWDataType<dynamic>> get dataDependencies {
    final data = dataType;
    return {
      if (data != null) data,
      if (numberFormat?.dataField case final currency?) currency,
      if (timeZone.dataField case final zone?) zone,
    };
  }

  /// Whether rendering this text goes through the native number-formatting
  /// helper.
  ///
  /// True for [HWText.number] and [HWText.fixedNumber], and for any number
  /// bound to a plain [HWText.new] -- those render in the default decimal
  /// format rather than as a raw `toString`.
  bool get formatsNumber {
    if (fixedNumber != null) return true;
    final data = dataType;
    return data != null && numberLeafOf(data) != null;
  }

  /// Whether rendering this text goes through the native date-formatting
  /// helper.
  bool get formatsDate {
    final data = dataType;
    return data != null && dateTimeLeafOf(data) != null;
  }

  /// The number format this text actually renders with, or null when it
  /// renders no number.
  ///
  /// A plain [HWText.new] bound to a number carries no [numberFormat] but still
  /// renders through the default decimal format, so this is what the emitted
  /// call and [renderHelpers] both follow.
  HWNumberFormat? get effectiveNumberFormat {
    if (numberFormat != null) return numberFormat;
    return formatsNumber ? HWNumberFormat.defaultFormat : null;
  }

  /// The date format this text actually renders with, or null when it renders
  /// no date.
  ///
  /// Defaults the same way [effectiveNumberFormat] does.
  HWDateFormat? get effectiveDateFormat {
    if (dateFormat != null) return dateFormat;
    return formatsDate ? HWDateFormat.defaultFormat : null;
  }

  /// The native functions rendering this text: the format's, the time zone's,
  /// and whatever displaying the bound value itself goes through.
  @override
  Set<HWNativeHelper> get renderHelpers => {
        if (effectiveNumberFormat case final format?) format.helper,
        if (effectiveDateFormat case final format?) ...[
          format.helper,
          ...timeZone.helpers,
        ],
        ...?dataType?.renderHelpers,
      };

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
        localizedContent = null,
        numberFormat = null,
        dateFormat = null,
        fixedNumber = null,
        timeZone = HWTimeZone.local;

  /// Static text translated at build time.
  ///
  /// [content] maps locale tag to text and must include the widget's
  /// `defaultLocale`. Unlike [HWText.new] with [HWString.localized], this
  /// creates no data field and cannot be overridden at runtime.
  ///
  /// The map is held raw: a const constructor cannot build an
  /// [HWLocalizedString] from a parameter, so [fromDartObject] wraps it.
  const HWText.localized(
    Map<String, String> content, {
    this.style,
    this.textAlign,
  })  : fixedContent = null,
        dataType = null,
        localizedContent = content,
        numberFormat = null,
        dateFormat = null,
        fixedNumber = null,
        timeZone = HWTimeZone.local;

  const HWText(HWDataType<dynamic> data, {this.style, this.textAlign})
      : fixedContent = null,
        dataType = data,
        localizedContent = null,
        numberFormat = null,
        dateFormat = null,
        fixedNumber = null,
        timeZone = HWTimeZone.local;

  /// A number from [data], rendered natively in the device's current locale.
  ///
  /// [data] must resolve to an [HWInt] or [HWDouble], wrapped in an
  /// [HWTimedData] or sitting at the leaf of an [HWJson] if you like. A widget
  /// with no value yet renders the type's own default (`0` / `0.0`) in the
  /// same format.
  const HWText.number(
    HWDataType<num> data, {
    HWNumberFormat format = const HWNumberFormat.decimal(),
    this.style,
    this.textAlign,
  })  : fixedContent = null,
        dataType = data,
        localizedContent = null,
        numberFormat = format,
        dateFormat = null,
        fixedNumber = null,
        timeZone = HWTimeZone.local;

  /// A hardcoded number, rendered natively in the device's current locale.
  ///
  /// Unlike [HWText.fixed] with a pre-rendered string, this follows a language
  /// or region change on the device.
  const HWText.fixedNumber(
    num value, {
    HWNumberFormat format = const HWNumberFormat.decimal(),
    this.style,
    this.textAlign,
  })  : fixedContent = null,
        dataType = null,
        localizedContent = null,
        numberFormat = format,
        dateFormat = null,
        fixedNumber = value,
        timeZone = HWTimeZone.local;

  /// A date from [data], rendered in the device's current locale and, by
  /// default, its own time zone.
  ///
  /// [data] must resolve to an [HWDateTime]. A widget with no value yet renders
  /// empty text.
  ///
  /// The stored value is always the same instant; [timeZone] only decides which
  /// wall clock it is shown on.
  const HWText.dateTime(
    HWDataType<DateTime> data, {
    HWDateFormat format = HWDateFormat.defaultFormat,
    this.timeZone = HWTimeZone.local,
    this.style,
    this.textAlign,
  })  : fixedContent = null,
        dataType = data,
        localizedContent = null,
        numberFormat = null,
        dateFormat = format,
        fixedNumber = null;

  /// The shape [fromDartObject] rebuilds a decoded text in.
  ///
  /// The public constructors type their data parameter by what they render, so
  /// a mistake in an annotation is a compile error; the decoder starts from an
  /// analyzer constant whose type argument is always `dynamic`, and the
  /// validator re-checks the leaf for it.
  const HWText._formatted(
    HWDataType<dynamic> data, {
    this.numberFormat,
    this.dateFormat,
    this.timeZone = HWTimeZone.local,
    this.style,
    this.textAlign,
  })  : fixedContent = null,
        dataType = data,
        localizedContent = null,
        fixedNumber = null;

  static HWText fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    var style = WidgetValueDecoder.decodeTextStyle(obj.getField('style'));
    var textAlign =
        WidgetValueDecoder.decodeTextAlign(obj.getField('textAlign'));

    final numberFormat = WidgetValueDecoder.decodeNumberFormat(
      obj.getField('numberFormat'),
      defaultLocale: decoder.defaultLocale,
      resourcePrefix: decoder.resourcePrefix,
    );
    final dateFormat =
        WidgetValueDecoder.decodeDateFormat(obj.getField('dateFormat'));
    final timeZone = WidgetValueDecoder.decodeTimeZone(
      obj.getField('timeZone'),
      defaultLocale: decoder.defaultLocale,
      resourcePrefix: decoder.resourcePrefix,
    );

    // Check for a hardcoded number (HWText.fixedNumber)
    final fixedNumberField = obj.getField('fixedNumber');
    final fixedNumber =
        fixedNumberField?.toIntValue() ?? fixedNumberField?.toDoubleValue();
    if (fixedNumber != null) {
      return HWText.fixedNumber(
        fixedNumber,
        format: numberFormat ?? const HWNumberFormat.decimal(),
        style: style,
        textAlign: textAlign,
      );
    }

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
      if (dateFormat != null) {
        return HWText._formatted(
          dataType,
          dateFormat: dateFormat,
          timeZone: timeZone ?? HWTimeZone.local,
          style: style,
          textAlign: textAlign,
        );
      }
      if (numberFormat != null) {
        return HWText._formatted(
          dataType,
          numberFormat: numberFormat,
          style: style,
          textAlign: textAlign,
        );
      }
      return HWText(dataType, style: style, textAlign: textAlign);
    }

    // coverage:ignore-start
    throw GeneratorError(
      'Could not decode HWText. Fields: fixedContent=$fixedContent, dataType=${obj.getField('dataType')}, dataTypeType=${obj.getField('dataType')?.type?.element?.name}',
    );
    // coverage:ignore-end
  }

  /// The Swift expression `Text(...)` is handed, or null when this text renders
  /// nothing.
  String? _swiftTextValue(String dataExpr) {
    final fixedContent = this.fixedContent;
    if (fixedContent != null) {
      return '"${escapeSwiftStringLiteral(fixedContent)}"';
    }

    final numberFormat = this.numberFormat;
    final fixedNumber = this.fixedNumber;
    if (fixedNumber != null) {
      return numberFormat!.swiftCall(
        'NSNumber(value: ${_nativeDoubleLiteral(fixedNumber)})',
        dataExpr: dataExpr,
      );
    }

    final dataType = this.dataType;
    if (dataType == null) return null;
    final bound = dataType.unwrapped;

    final effectiveNumberFormat = this.effectiveNumberFormat;
    if (effectiveNumberFormat != null) {
      return _numberLeaf(dataType).iosFormattedValue(
        bound.swiftAccess(dataExpr),
        effectiveNumberFormat,
        dataExpr: dataExpr,
      );
    }

    final dateFormat = effectiveDateFormat;
    if (dateFormat != null) {
      return _dateLeaf(dataType).iosFormattedValue(
        bound.swiftAccess(dataExpr),
        dateFormat,
        timeZone: timeZone,
        dataExpr: dataExpr,
      );
    }

    if (bound is HWJson) {
      return bound.swiftGlanceJsonTextInterpolation(dataExpr);
    }

    final outerValue = bound.swiftAccess(dataExpr);
    final innerValue = '${outerValue.replaceAll('?.', '!.')}!';
    return bound.iosToString(outerValue: outerValue, innerValue: innerValue);
  }

  /// The Kotlin expression the Glance `Text(text = ...)` argument is set to, or
  /// null when this text renders nothing.
  String? _kotlinTextValue(String dataExpr) {
    final fixedContent = this.fixedContent;
    if (fixedContent != null) {
      return '"${escapeKotlinStringLiteral(fixedContent)}"';
    }

    final numberFormat = this.numberFormat;
    final fixedNumber = this.fixedNumber;
    if (fixedNumber != null) {
      return numberFormat!.kotlinCall(
        _nativeDoubleLiteral(fixedNumber),
        dataExpr: dataExpr,
      );
    }

    final dataType = this.dataType;
    if (dataType == null) return null;
    final bound = dataType.unwrapped;

    final effectiveNumberFormat = this.effectiveNumberFormat;
    if (effectiveNumberFormat != null) {
      return _numberLeaf(dataType).androidFormattedValue(
        bound.kotlinAccess(dataExpr),
        effectiveNumberFormat,
        dataExpr: dataExpr,
      );
    }

    final dateFormat = effectiveDateFormat;
    if (dateFormat != null) {
      return _dateLeaf(dataType).androidFormattedValue(
        bound.kotlinAccess(dataExpr),
        dateFormat,
        timeZone: timeZone,
        dataExpr: dataExpr,
      );
    }

    if (bound is HWJson) {
      return bound.kotlinGlanceJsonTextInterpolation(dataExpr);
    }

    final access = bound.kotlinAccess(dataExpr);
    return bound.androidToString(outerValue: access, innerValue: access);
  }

  static HWNumericDataType<num> _numberLeaf(HWDataType<dynamic> data) {
    final leaf = numberLeafOf(data);
    if (leaf == null) {
      // coverage:ignore-start
      throw GeneratorError(
        'HWText.number needs an HWInt or HWDouble, but "${data.key}" is '
        '${data.unwrapped.runtimeType}.',
      );
      // coverage:ignore-end
    }
    return leaf;
  }

  static HWDateTime _dateLeaf(HWDataType<dynamic> data) {
    final leaf = dateTimeLeafOf(data);
    if (leaf == null) {
      // coverage:ignore-start
      throw GeneratorError(
        'HWText.dateTime needs an HWDateTime, but "${data.key}" is '
        '${data.unwrapped.runtimeType}.',
      );
      // coverage:ignore-end
    }
    return leaf;
  }

  /// [value] as a literal both Swift and Kotlin read as a floating point
  /// number, which Kotlin needs spelled out for whole numbers.
  static String _nativeDoubleLiteral(num value) =>
      value is int ? '$value.0' : '$value';

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    final textValue = _swiftTextValue(dataExpr);

    var viewCall = textValue == null ? '' : '${pad}Text($textValue)';

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
    final textValue = _kotlinTextValue(dataExpr);

    var textArgs = textValue == null ? '' : 'text = $textValue';

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
