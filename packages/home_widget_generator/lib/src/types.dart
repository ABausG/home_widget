/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
abstract class HWDataType {
  const HWDataType();
}

class HWString extends HWDataType {
  const HWString();
}

class HWInt extends HWDataType {
  const HWInt();
}

class HWDouble extends HWDataType {
  const HWDouble();
}

class HWBool extends HWDataType {
  const HWBool();
}
