part of 'hw_widget.dart';

/// A widget that contributes data fields but renders nothing.
/// Useful for passing background data or non-visual fields.
class HWDataOnly extends HWWidget implements HWDataWidget {
  final List<HWDataType> data;

  const HWDataOnly(this.data);

  static HWDataOnly fromDartObject(DartObject obj) {
    final dataField = obj.getField('data');
    final data = dataField?.toListValue()?.map((d) {
          var key = d.getField('key')?.toStringValue();
          if (key == null) {
            // Fallback for when key is in super class
            final superClass = d.getField('(super)');
            if (superClass != null) {
              key = superClass.getField('key')?.toStringValue();
            }
          }
          final typeName = d.type?.element3?.name3;

          if (key != null) {
            if (typeName == 'HWString') return HWString(key);
            if (typeName == 'HWInt') return HWInt(key);
            if (typeName == 'HWDouble') return HWDouble(key);
            if (typeName == 'HWBool') return HWBool(key);
          }
          throw GeneratorError('Unknown data type in HWDataOnly: $typeName');
        }).toList() ??
        [];

    return HWDataOnly(data);
  }

  @override
  Set<HWDataType> get dataDependencies => data.toSet();

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
