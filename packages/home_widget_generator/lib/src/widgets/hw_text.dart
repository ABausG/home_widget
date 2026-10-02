part of 'hw_widget.dart';

/// A text widget for use in widgetBuilder.
///
/// Const constructors:
/// - `HWText(HWString('key'))` -- data-bound via HWDataType
/// - `HWText.number(HWInt('key'), format: ...)` -- data-bound number, formatted
///   natively in the device's locale
/// - `HWText.dateTime(HWDateTime('key'), format: ...)` -- data-bound date,
///   formatted in the device's locale and time zone
///
/// Each takes a constant just as well: `HWText(HWString.fixed('Hello'))`,
/// `HWText(HWString.localizedFixed({...}))`,
/// `HWText.number(HWInt.fixed(1234), format: ...)`.
class HWText extends HWWidget with HWFontWidget implements HWDataWidget {
  final HWDataType<dynamic> dataType;

  /// How a number renders, from [HWText.number].
  final HWNumberFormat? numberFormat;

  /// How a date renders, from [HWText.dateTime].
  final HWDateFormat? dateFormat;

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
  Set<HWDataType<dynamic>> get dataDependencies => _dataDependenciesOf([
        dataType,
        if (numberFormat?.dataField case final currency?) currency,
        if (timeZone.dataField case final zone?) zone,
      ]);

  /// Whether rendering this text goes through the native number-formatting
  /// helper.
  ///
  /// True for [HWText.number], and for any number bound to a plain
  /// [HWText.new] -- those render in the default decimal format rather than as
  /// a raw `toString`.
  bool get formatsNumber => numberLeafOf(dataType) != null;

  /// Whether rendering this text goes through the native date-formatting
  /// helper.
  bool get formatsDate => dateTimeLeafOf(dataType) != null;

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
  /// the custom font's, and whatever displaying the bound value itself goes
  /// through.
  @override
  Set<HWNativeHelper> get renderHelpers => {
        if (effectiveNumberFormat case final format?) format.helper,
        if (effectiveDateFormat case final format?) ...[
          format.helper,
          ...timeZone.helpers,
        ],
        if (fontVariant != null) HWNativeHelper.hwFont,
        ...dataType.renderHelpers,
      };

  /// The font file this text renders with, or null when it renders in the
  /// platform's own font.
  @override
  HWFontVariant? get fontVariant => style?.fontVariant;

  /// How Android renders this text: as a Glance `Text`, or as the bitmap a
  /// custom family takes, which is what its imports follow.
  HWKotlinTextRenderer get _kotlinRenderer =>
      (style ?? const HWTextStyle()).kotlinRenderer(textAlign: textAlign);

  @override
  Set<String> get kotlinImports => _kotlinRenderer.kotlinImports;

  /// Text Glance renders itself is a `Text`; a custom family is drawn into a
  /// bitmap and shown as an `Image`, which carries no baseline.
  @override
  bool get kotlinReportsBaseline => _kotlinRenderer is HWGlanceTextRenderer;

  /// Whether Android draws this text into a bitmap rather than letting Glance
  /// render it, which is what the measuring pass is generated for.
  @override
  bool get kotlinRendersBitmapText => _kotlinRenderer is HWBitmapTextRenderer;

  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      _kotlinRenderer.kotlinBaselineText;

  @override
  Set<String> get swiftViewModifiers {
    final modifiers = <String>{};
    if (style != null) {
      modifiers.addAll(style!.swiftViewModifiers);
    }
    return modifiers;
  }

  const HWText(HWDataType<dynamic> data, {this.style, this.textAlign})
      : dataType = data,
        numberFormat = null,
        dateFormat = null,
        timeZone = HWTimeZone.local;

  /// A number from [data], rendered natively in the device's current locale.
  ///
  /// [data] must resolve to an [HWInt] or [HWDouble], wrapped in an
  /// [HWTimedData] or an [HWItemData] or sitting at the leaf of an [HWJson] if
  /// you like. A widget with no value yet renders the type's own default (`0` /
  /// `0.0`) in the same format.
  const HWText.number(
    HWDataType<num> data, {
    HWNumberFormat format = const HWNumberFormat.decimal(),
    this.style,
    this.textAlign,
  })  : dataType = data,
        numberFormat = format,
        dateFormat = null,
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
  })  : dataType = data,
        numberFormat = null,
        dateFormat = format;

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
  }) : dataType = data;

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
      'Could not decode HWText. Fields: dataType=$dataTypeObj, dataTypeType=${dataTypeObj?.type?.element?.name}',
    );
    // coverage:ignore-end
  }

  /// The Swift expression `Text(...)` is handed.
  String _swiftTextValue(String dataExpr) {
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

  /// The Kotlin expression the Glance `Text(text = ...)` argument is set to.
  String _kotlinTextValue(String dataExpr) {
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

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent; // Use 4 spaces per indent level to match tests
    var viewCall = '${pad}Text(${_swiftTextValue(dataExpr)})';

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

    return viewCall;
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) =>
      _kotlinRenderer.toKotlin(
        indent,
        dataExpr: dataExpr,
        text: _kotlinTextValue(dataExpr),
        itemList: context?.itemList,
      );

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
}
