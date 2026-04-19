/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
sealed class HWDataType<T> {
  final String key;
  const HWDataType(this.key);

  /// The default value.
  T? get defaultValue => null;

  /// The Dart type string.
  String get dartType;

  /// The Kotlin type string.
  String get kotlinType;

  /// The Swift type string.
  String get swiftType;

  /// Returns the Kotlin code to read this value from SharedPreferences.
  /// [store] is the variable name of the SharedPreferences instance (e.g. "prefs").
  /// [key] is the full key string (e.g. "${PREFERENCES_PREFIX}.count").
  String androidReadValue({required String store, required String key});

  /// Returns the Swift code to read this value from UserDefaults.
  /// [store] is the variable name of the UserDefaults instance (e.g. "defaults").
  /// [key] is the full key string.
  String iosReadValue({required String store, required String key});

  /// Returns the Kotlin code to stringify this value for display.
  /// [outerValue] is the nullable value expression (e.g. "data.count").
  /// [innerValue] is the non-null value expression (e.g. "data.count").
  String androidToString(
      {required String outerValue, required String innerValue});

  /// Returns the Swift code to stringify this value for display.
  /// [outerValue] is the nullable value expression (e.g. "entry.data.count").
  /// [innerValue] is the non-null value expression (e.g. "entry.data.count!").
  String iosToString({required String outerValue, required String innerValue});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWDataType &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(key, defaultValue);
}

class HWString extends HWDataType<String> {
  @override
  final String? defaultValue;

  const HWString(super.key, {this.defaultValue});

  @override
  String get dartType => 'String';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue != null ? '"$defaultValue"' : 'null';
    return '$store.getString("$key", $fallback)';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.string(forKey: "$key")';
    if (defaultValue != null) return '($read ?? "$defaultValue")';
    return read;
  }

  @override
  String androidToString(
      {required String outerValue, required String innerValue}) {
    return '$outerValue ?: ""';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue ?? ""';
  }
}

class HWInt extends HWDataType<int> {
  @override
  final int? defaultValue;

  const HWInt(super.key, {this.defaultValue});

  @override
  String get dartType => 'int';

  @override
  String get kotlinType => 'Int';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue?.toString() ?? 'null';
    return 'if ($store.contains("$key")) $store.getInt("$key", 0) else $fallback';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.object(forKey: "$key") as? Int';
    if (defaultValue != null) return '($read ?? $defaultValue)';
    return read;
  }

  @override
  String androidToString(
      {required String outerValue, required String innerValue}) {
    return '($outerValue?.toString() ?: "0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0"';
  }
}

class HWDouble extends HWDataType<double> {
  @override
  final double? defaultValue;

  const HWDouble(super.key, {this.defaultValue});

  @override
  String get dartType => 'double';

  @override
  String get kotlinType => 'Double';

  @override
  String get swiftType => 'Double';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue?.toString() ?? 'null';
    return 'if ($store.contains("$key")) $store.getFloat("$key", 0f).toDouble() else $fallback';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.object(forKey: "$key") as? Double';
    if (defaultValue != null) return '($read ?? $defaultValue)';
    return read;
  }

  @override
  String androidToString(
      {required String outerValue, required String innerValue}) {
    return '($outerValue?.toString() ?: "0.0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0.0"';
  }
}

class HWBool extends HWDataType<bool> {
  @override
  final bool? defaultValue;

  const HWBool(super.key, {this.defaultValue});

  @override
  String get dartType => 'bool';

  @override
  String get kotlinType => 'Boolean';

  @override
  String get swiftType => 'Bool';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue?.toString() ?? 'null';
    return 'if ($store.contains("$key")) $store.getBoolean("$key", false) else $fallback';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.object(forKey: "$key") as? Bool';
    if (defaultValue != null) return '($read ?? $defaultValue)';
    return read;
  }

  @override
  String androidToString(
      {required String outerValue, required String innerValue}) {
    return '($outerValue?.toString() ?: "false")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "false"';
  }
}
