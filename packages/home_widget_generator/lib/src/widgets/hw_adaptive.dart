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
  List<HWWidget> get childWidgets => [ios, android];

  @override
  Set<String> get kotlinImports => android.kotlinImports;

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) =>
      android.kotlinImportsIn(enclosingLinearAxis);

  @override
  bool get kotlinReportsBaseline => android.kotlinReportsBaseline;

  @override
  bool get kotlinPaddingAddsRoom => android.kotlinPaddingAddsRoom;

  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) =>
      android.kotlinRoomIn(enclosingLinearAxis);

  @override
  bool get swiftRendersNothing => ios.swiftRendersNothing;

  @override
  bool get kotlinRendersNothing => android.kotlinRendersNothing;

  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      android.kotlinBaselineText(context);

  /// A stack lays out the Android side, and whatever it picks from in turn.
  @override
  List<HWWidget> _kotlinChoices(HWEmitContext? context) => [android];

  @override
  String _kotlinChoice(
    int indent, {
    required String dataExpr,
    required HWEmitContext? context,
    required String Function(HWWidget widget, int indent) emit,
  }) =>
      emit(android, indent);

  @override
  Set<String> get swiftViewModifiers => ios.swiftViewModifiers;

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    return ios.toSwift(indent, dataExpr: dataExpr, context: context);
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    return android.toKotlin(indent, dataExpr: dataExpr, context: context);
  }
}
