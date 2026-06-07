part of 'hw_widget.dart';

/// A widget that conditionally renders different widgets for iOS and Android.
class HWAdaptive extends HWWidget {
  final HWWidget ios;
  final HWWidget android;

  const HWAdaptive({
    required this.ios,
    required this.android,
  });

  static HWAdaptive fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final iosField = obj.getField('ios');
    final androidField = obj.getField('android');

    if (iosField == null || iosField.isNull) {
      // coverage:ignore-start
      throw GeneratorError('HWAdaptive: ios parameter is required');
      // coverage:ignore-end
    }
    if (androidField == null || androidField.isNull) {
      // coverage:ignore-start
      throw GeneratorError('HWAdaptive: android parameter is required');
      // coverage:ignore-end
    }

    return HWAdaptive(
      ios: decoder.decodeRecursive(iosField),
      android: decoder.decodeRecursive(androidField),
    );
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        ...ios.dataDependencies,
        ...android.dataDependencies,
      };

  @override
  Set<String> get kotlinImports => android.kotlinImports;

  @override
  Set<String> get swiftViewModifiers => ios.swiftViewModifiers;

  @override
  String toSwift(int indent, {required String dataExpr}) {
    return ios.toSwift(indent, dataExpr: dataExpr);
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    return android.toKotlin(indent, dataExpr: dataExpr);
  }
}
