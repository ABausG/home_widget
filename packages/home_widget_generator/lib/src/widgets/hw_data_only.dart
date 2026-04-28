part of 'hw_widget.dart';

/// A widget that contributes data fields but renders nothing.
/// Useful for passing background data or non-visual fields.
class HWDataOnly extends HWWidget implements HWDataWidget {
  final List<HWDataType<dynamic>> data;

  const HWDataOnly(this.data);

  static HWDataOnly fromDartObject(DartObject obj) {
    final dataField = obj.getField('data');
    final data = dataField?.toListValue()?.map<HWDataType<dynamic>>((d) {
      final decoded = WidgetValueDecoder.decodeDataType(d);
      // coverage:ignore-start
      if (decoded == null) {
        throw GeneratorError('Unknown data type in HWDataOnly: $d');
      }
      // coverage:ignore-end
      return decoded;
    }).toList();

    return HWDataOnly(data ?? []);
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies => data.toSet();

  @override
  Set<String> get kotlinImports => {};

  @override
  String toSwift(int indent, {required String dataExpr}) {
    return '';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    return '';
  }
}
