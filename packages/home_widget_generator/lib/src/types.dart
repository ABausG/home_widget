/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
sealed class HWDataType<T> {
  final String key;
  const HWDataType(this.key);

  /// The default value.
  T? get defaultValue;

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
  String androidToString({
    required String outerValue,
    required String innerValue,
  });

  /// Returns the Swift code to stringify this value for display.
  /// [outerValue] is the nullable value expression (e.g. "entry.data.count").
  /// [innerValue] is the non-null value expression (e.g. "entry.data.count!").
  String iosToString({required String outerValue, required String innerValue});

  /// Returns the Swift access expression for this value from [dataExpr].
  String swiftAccess(String dataExpr) => '$dataExpr.$key';

  /// Returns the Kotlin access expression for this value from [dataExpr].
  String kotlinAccess(String dataExpr) => '$dataExpr.$key';

  /// Kotlin expression applying widget JSON leaf defaults ([HWJson] only).
  String kotlinReadExpr(String dataExpr) => kotlinAccess(dataExpr);

  /// Swift expression applying widget JSON leaf defaults ([HWJson] only).
  String swiftReadExpr(String dataExpr) => swiftAccess(dataExpr);

  /// Kotlin literal representing [defaultValue] for generated native code,
  /// or null when there is no default.
  String? codegenKotlinDefaultLiteral() => null;

  /// Swift literal representing [defaultValue] for generated native code,
  /// or null when there is no default.
  String? codegenSwiftDefaultLiteral() => null;

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
    final fallback = defaultValue != null
        ? '"${_escapeKotlinStringLiteral(defaultValue!)}"'
        : 'null';
    return '$store.getString("$key", $fallback)';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.string(forKey: "$key")';
    if (defaultValue != null) {
      return '($read ?? "${_escapeSwiftStringLiteral(defaultValue!)}")';
    }
    return read;
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '$outerValue ?: ""';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue ?? ""';
  }

  @override
  String? codegenKotlinDefaultLiteral() {
    final d = defaultValue;
    if (d == null) return null;
    return '"${_escapeKotlinStringLiteral(d)}"';
  }

  @override
  String? codegenSwiftDefaultLiteral() {
    final d = defaultValue;
    if (d == null) return null;
    return '"${_escapeSwiftStringLiteral(d)}"';
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
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0"';
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';
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
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "0.0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0.0"';
  }

  @override
  String? codegenKotlinDefaultLiteral() => defaultValue?.toString();

  @override
  String? codegenSwiftDefaultLiteral() => defaultValue?.toString();
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
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "false")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "false"';
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : '$defaultValue';

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';
}

class HWJson extends HWDataType<dynamic> {
  final HWDataType<dynamic> child;

  const HWJson(super.key, this.child);

  List<String> get pathSegments {
    if (child is HWJson) {
      final nested = child as HWJson;
      return [nested.key, ...nested.pathSegments];
    }
    return [child.key];
  }

  HWDataType<dynamic> get leafType {
    if (child is HWJson) return (child as HWJson).leafType;
    return child;
  }

  @override
  dynamic get defaultValue => leafType.defaultValue;

  @override
  String get dartType => 'Map<String, dynamic>';

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
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return leafType.androidToString(
      outerValue: outerValue,
      innerValue: innerValue,
    );
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return leafType.iosToString(outerValue: outerValue, innerValue: innerValue);
  }

  @override
  String swiftAccess(String dataExpr) {
    return '$dataExpr.$key?.${pathSegments.join('?.')}';
  }

  @override
  String kotlinAccess(String dataExpr) {
    return '$dataExpr.$key?.${pathSegments.join('?.')}';
  }

  @override
  String kotlinReadExpr(String dataExpr) {
    final base = kotlinAccess(dataExpr);
    final literal = leafType.codegenKotlinDefaultLiteral();
    if (literal == null) return base;
    return '($base ?: $literal)';
  }

  @override
  String swiftReadExpr(String dataExpr) {
    final base = swiftAccess(dataExpr);
    final literal = leafType.codegenSwiftDefaultLiteral();
    if (literal == null) return base;
    return '((($base) ?? ($literal)))';
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      leafType.codegenKotlinDefaultLiteral();

  @override
  String? codegenSwiftDefaultLiteral() => leafType.codegenSwiftDefaultLiteral();

  /// Kotlin `text = ...` argument for Glance Text when bound to nested JSON data.
  String kotlinGlanceJsonTextInterpolation(String dataExpr) =>
      leafType.androidToString(
        outerValue: kotlinReadExpr(dataExpr),
        innerValue: kotlinReadExpr(dataExpr),
      );

  /// Swift `Text(...)` argument when bound to nested JSON data.
  String swiftGlanceJsonTextInterpolation(String dataExpr) {
    final read = swiftReadExpr(dataExpr);
    final leaf = leafType;

    // Keep string handling compatible with iosToString quoting rules.
    if (leaf is HWString) {
      return leaf.iosToString(
        outerValue: read,
        innerValue: read,
      );
    }

    return 'String(describing: ($read))';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWJson &&
          key == other.key &&
          child == other.child &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(key, child, defaultValue);
}

String _escapeKotlinStringLiteral(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll(r'$', r'\$').replaceAll('"', r'\"');

String _escapeSwiftStringLiteral(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
