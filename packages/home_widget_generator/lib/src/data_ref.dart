/// A typed reference to a data field, used in widgetBuilder (v3+).
/// The generic type T matches the Dart type of the field.
class HWDataRef<T> {
  final String key;
  const HWDataRef(this.key);
}
