/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
abstract class HWDataType {
  final String? key;
  const HWDataType([this.key]);
}

class HWString extends HWDataType {
  const HWString([super.key]);
}

class HWInt extends HWDataType {
  const HWInt([super.key]);
}

class HWDouble extends HWDataType {
  const HWDouble([super.key]);
}

class HWBool extends HWDataType {
  const HWBool([super.key]);
}
