part of 'hw_widget.dart';

/// Abstract base class for conditional widgets.
abstract class HWConditional extends HWWidget implements HWDataWidget {
  const HWConditional();

  /// The widget to render if the condition is met.
  HWWidget get firstBranch;

  /// The widget to render if the condition is not met.
  HWWidget get secondBranch;

  /// Returns the Swift condition expression.
  String conditionSwift({required String dataExpr});

  /// Returns the Kotlin condition expression.
  String conditionKotlin({required String dataExpr});

  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        ...firstBranch.dataDependencies,
        ...secondBranch.dataDependencies,
      };

  @override
  Set<String> get kotlinImports => {
        ...firstBranch.kotlinImports,
        ...secondBranch.kotlinImports,
      };

  @override
  Set<String> get swiftViewModifiers => {
        ...firstBranch.swiftViewModifiers,
        ...secondBranch.swiftViewModifiers,
      };

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final spaces = '    ' * indent; // Use 4 spaces per indent level
    final cond = conditionSwift(dataExpr: dataExpr);
    final first = firstBranch.toSwift(indent + 1, dataExpr: dataExpr);
    final second = secondBranch.toSwift(indent + 1, dataExpr: dataExpr);

    return '${spaces}if $cond {\n$first\n$spaces} else {\n$second\n$spaces}';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final spaces = '    ' * indent; // Use 4 spaces per indent level
    final cond = conditionKotlin(dataExpr: dataExpr);
    final first = firstBranch.toKotlin(indent + 1, dataExpr: dataExpr);
    final second = secondBranch.toKotlin(indent + 1, dataExpr: dataExpr);

    return '${spaces}if ($cond) {\n$first\n$spaces} else {\n$second\n$spaces}';
  }
}

/// Renders a widget depending on whether a data field exists in the preferences.
class HWDataExists extends HWConditional {
  final HWDataType<dynamic> data;
  final HWWidget whenPresent;
  final HWWidget whenAbsent;

  const HWDataExists({
    required this.data,
    required this.whenPresent,
    required this.whenAbsent,
  });

  static HWDataExists fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final dataObj = WidgetValueDecoder.getField(obj, 'data');
    final data = WidgetValueDecoder.decodeDataType(dataObj);
    if (data == null) {
      // coverage:ignore-start
      throw GeneratorError('HWDataExists requires data');
      // coverage:ignore-end
    }

    final whenPresentObj = WidgetValueDecoder.getField(obj, 'whenPresent');
    final whenAbsentObj = WidgetValueDecoder.getField(obj, 'whenAbsent');

    return HWDataExists(
      data: data,
      whenPresent: decoder.decodeRecursive(whenPresentObj),
      whenAbsent: decoder.decodeRecursive(whenAbsentObj),
    );
  }

  @override
  HWWidget get firstBranch => whenPresent;

  @override
  HWWidget get secondBranch => whenAbsent;

  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        data,
        ...super.dataDependencies,
      };

  @override
  String conditionSwift({required String dataExpr}) {
    return '${data.swiftAccess(dataExpr)} != nil';
  }

  @override
  String conditionKotlin({required String dataExpr}) {
    return '${data.kotlinAccess(dataExpr)} != null';
  }
}

/// Renders a widget depending on a boolean data field.
/// The provided HWBool must have a default value.
class HWBoolConditional extends HWConditional {
  final HWDataType<dynamic> data;
  final HWWidget whenTrue;
  final HWWidget whenFalse;

  const HWBoolConditional({
    required this.data,
    required this.whenTrue,
    required this.whenFalse,
  });
  static HWBoolConditional fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final dataObj = WidgetValueDecoder.getField(obj, 'data');
    final data = WidgetValueDecoder.decodeDataType(dataObj);
    if (data == null || !_isSupportedBoolData(data)) {
      // coverage:ignore-start
      throw GeneratorError('HWBoolConditional requires data');
      // coverage:ignore-end
    }
    if (_boolDefaultValue(data) == null) {
      // coverage:ignore-start
      throw GeneratorError(
        'HWBool must have a non-null defaultValue for HWBoolConditional',
      );
      // coverage:ignore-end
    }

    final whenTrueObj = WidgetValueDecoder.getField(obj, 'whenTrue');
    final whenFalseObj = WidgetValueDecoder.getField(obj, 'whenFalse');

    return HWBoolConditional(
      data: data,
      whenTrue: decoder.decodeRecursive(whenTrueObj),
      whenFalse: decoder.decodeRecursive(whenFalseObj),
    );
  }

  @override
  HWWidget get firstBranch => whenTrue;

  @override
  HWWidget get secondBranch => whenFalse;

  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        data,
        ...super.dataDependencies,
      };

  @override
  String conditionSwift({required String dataExpr}) {
    if (_boolDefaultValue(data) == null) {
      throw ArgumentError(
        'HWBoolConditional requires a defaultValue to be set on its data type.',
      );
    }
    return '${data.swiftReadExpr(dataExpr)} == true';
  }

  @override
  String conditionKotlin({required String dataExpr}) {
    if (_boolDefaultValue(data) == null) {
      throw ArgumentError(
        'HWBoolConditional requires a defaultValue to be set on its data type.',
      );
    }
    return '${data.kotlinReadExpr(dataExpr)} == true';
  }

  static bool _isSupportedBoolData(HWDataType<dynamic> data) {
    if (data is HWBool) return true;
    if (data is HWJson && data.leafType is HWBool) return true;
    return false;
  }

  static bool? _boolDefaultValue(HWDataType<dynamic> data) {
    if (data is HWBool) return data.defaultValue;
    if (data is HWJson && data.leafType is HWBool) {
      return (data.leafType as HWBool).defaultValue;
    }
    return null;
  }
}
