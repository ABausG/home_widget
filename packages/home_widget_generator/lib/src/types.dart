/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
sealed class HWDataType {
  final String key;
  const HWDataType(this.key);

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
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}

class HWString extends HWDataType {
  const HWString(super.key);

  @override
  String get dartType => 'String';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  String androidReadValue({required String store, required String key}) {
    return '$store.getString("$key", null)';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return '$store?.string(forKey: "$key")';
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

class HWInt extends HWDataType {
  const HWInt(super.key);

  @override
  String get dartType => 'int';

  @override
  String get kotlinType => 'Int';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({required String store, required String key}) {
    return 'if ($store.contains("$key")) $store.getInt("$key", 0) else null';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return '$store?.object(forKey: "$key") as? Int';
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

class HWDouble extends HWDataType {
  const HWDouble(super.key);

  @override
  String get dartType => 'double';

  @override
  String get kotlinType => 'Double';

  @override
  String get swiftType => 'Double';

  @override
  String androidReadValue({required String store, required String key}) {
    return 'if ($store.contains("$key")) $store.getFloat("$key", 0f).toDouble() else null';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return '$store?.object(forKey: "$key") as? Double';
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

class HWBool extends HWDataType {
  const HWBool(super.key);

  @override
  String get dartType => 'bool';

  @override
  String get kotlinType => 'Boolean';

  @override
  String get swiftType => 'Bool';

  @override
  String androidReadValue({required String store, required String key}) {
    return 'if ($store.contains("$key")) $store.getBoolean("$key", false) else null';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return '$store?.object(forKey: "$key") as? Bool';
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
