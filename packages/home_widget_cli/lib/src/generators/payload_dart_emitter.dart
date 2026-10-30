import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';

/// Emits the Dart side of a payload: the class holding the values a tap sent,
/// built from the URL native code wrote them into and written back into one.
///
/// What it reads is what `HWPayloadUrl.toSwift` and `HWPayloadUrl.toKotlin`
/// write, so the three stay in step: the values as query parameters under
/// their names, percent-encoded, a date as its milliseconds since the epoch.
class PayloadDartEmitter {
  /// The URL the payload travels in.
  final HWPayloadUrl url;

  /// Creates a [PayloadDartEmitter] for [url].
  const PayloadDartEmitter(this.url);

  /// The function matching a URL against the one a class stands for.
  static const String matcher = r'_$matchesPayloadUrl';

  /// The function writing a payload into a URL.
  static const String writer = r'_$payloadUri';

  /// The members every class [classDeclaration] writes has, which a field of
  /// the same name would redeclare.
  static const Set<String> memberNames = {
    'fromUri',
    'hashCode',
    'noSuchMethod',
    'runtimeType',
    'toString',
    'toUri',
  };

  /// The names the body of a class [classDeclaration] writes refers to, which
  /// a field of the same name would hide. The name of the class is one more.
  static const Set<String> referencedNames = {
    'ArgumentError',
    'DateTime',
    'FormatException',
    'Object',
    'String',
    'Uri',
    'bool',
    'double',
    'int',
    'override',
  };

  /// The class [className] extending [superClass], which holds the payload
  /// and is [description] in its doc comment.
  ///
  /// Besides its fields it declares `_$fromUri`, answering null for a URL
  /// that is not [url], `toUri`, and value equality.
  String classDeclaration({
    required String className,
    required String superClass,
    required String description,
  }) {
    final payload = url.payload;
    final buffer = StringBuffer();
    buffer.write('''
/// $description
final class $className extends $superClass {
  const $className(${_constructorParameters()});
''');
    if (payload.isNotEmpty) buffer.writeln();
    for (final entry in payload) {
      buffer.writeln('  final ${_fieldType(entry)} ${entry.name};');
    }

    final arguments = [
      for (final entry in payload) '${entry.name}: ${_decode(entry)}',
    ].join(', ');
    buffer.write('''

  static final Uri _\$url = Uri.parse('${escapeDartStringLiteral(url.staticUrl)}');

  static $className? _\$fromUri(Uri uri) {
    try {
      if (!$matcher(uri, _\$url)) return null;
''');
    if (payload.isEmpty) {
      buffer.writeln('      return const $className();');
    } else {
      buffer.write('''
      final query = uri.queryParameters;
      return $className($arguments);
''');
    }
    buffer.write('''
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Uri toUri() => ${_toUri()};

  @override
  bool operator ==(Object other) => ${_equality(className)};

  @override
  int get hashCode => ${_hashCode(className)};

  @override
  String toString() => '$className(${_description()})';
}
''');
    return buffer.toString();
  }

  /// The file-level functions the classes of [urls] call, each written once
  /// and only where one of them calls it.
  static String helpers(Iterable<HWPayloadUrl> urls) {
    final types = <HWPayloadType>{
      for (final url in urls)
        for (final entry in url.payload)
          if (entry.type case final type?) type,
    };
    final buffer = StringBuffer();
    buffer.write('''
/// Whether [uri] is the URL [url] with any payload: scheme, authority, path
/// and fragment are the same, and every query parameter of [url] is there.
bool $matcher(Uri uri, Uri url) {
  if (uri.scheme != url.scheme ||
      uri.authority != url.authority ||
      uri.path != url.path ||
      uri.fragment != url.fragment) {
    return false;
  }
  final query = uri.queryParametersAll;
  for (final entry in url.queryParametersAll.entries) {
    if (entry.key == '${HWPayloadUrl.marker}') continue;
    final values = query[entry.key];
    if (values == null || values.length != entry.value.length) return false;
    for (var index = 0; index < values.length; index++) {
      if (values[index] != entry.value[index]) return false;
    }
  }
  return true;
}
''');
    if (urls.any((url) => url.payload.isNotEmpty)) {
      buffer.write('''

/// [head] with every value of [payload] that is there appended as a query
/// parameter, then [marker] and [fragment].
Uri $writer(String head, Map<String, String?> payload, String marker, String fragment) {
  final url = StringBuffer(head);
  var separator = head.contains('?') ? '&' : '?';
  payload.forEach((name, value) {
    if (value == null) return;
    url.write('\$separator\$name=\${Uri.encodeComponent(value)}');
    separator = '&';
  });
  if (marker.isNotEmpty) url.write('\$separator\$marker');
  url.write(fragment);
  return Uri.parse(url.toString());
}
''');
    }
    if (types.contains(HWPayloadType.int)) {
      buffer.write('''

int? _\$payloadInt(String? value) => value == null ? null : int.tryParse(value);
''');
    }
    if (types.contains(HWPayloadType.double)) {
      buffer.write('''

double? _\$payloadDouble(String? value) => value == null ? null : double.tryParse(value);
''');
    }
    if (types.contains(HWPayloadType.bool)) {
      buffer.write('''

bool? _\$payloadBool(String? value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};
''');
    }
    if (types.contains(HWPayloadType.dateTime)) {
      buffer.write('''

DateTime? _\$payloadDateTime(String? value) {
  final millis = value == null ? null : int.tryParse(value);
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
''');
    }
    return buffer.toString();
  }

  String _fieldType(HWPayloadEntry entry) =>
      '${entry.type!.dartType}${entry.isNullable ? '?' : ''}';

  /// The Dart literal an entry that is never null falls back on: its constant
  /// or its default value. Null for a nullable one.
  String? _fallback(HWPayloadEntry entry) {
    if (entry.isNullable) return null;
    final leaf = entry.leaf;
    if (leaf is HWDateTime) {
      final millis = leaf.fixedDateTime!.toUtc().millisecondsSinceEpoch;
      return 'DateTime.fromMillisecondsSinceEpoch($millis, isUtc: true)';
    }
    final value = entry.isFixed ? entry.fixedWireValue! : leaf.defaultValue;
    if (entry.type == HWPayloadType.string) {
      return "'${escapeDartStringLiteral('$value')}'";
    }
    return '$value';
  }

  /// Whether the fallback of [entry] can be a constructor default, which a
  /// `DateTime` cannot: it has no const constructor.
  bool _hasConstFallback(HWPayloadEntry entry) =>
      !entry.isNullable && entry.type != HWPayloadType.dateTime;

  String _constructorParameters() {
    final payload = url.payload;
    if (payload.isEmpty) return '';
    final parameters = [
      for (final entry in payload)
        if (entry.isNullable)
          'this.${entry.name}'
        else if (_hasConstFallback(entry))
          'this.${entry.name} = ${_fallback(entry)}'
        else
          'required this.${entry.name}',
    ].join(', ');
    return '{$parameters}';
  }

  /// The expression reading [entry] out of `query`, the decoded query
  /// parameters. A value that is missing or unreadable is null, or the
  /// fallback of an entry that is never null.
  String _decode(HWPayloadEntry entry) {
    final raw = "query['${entry.name}']";
    final read = switch (entry.type!) {
      HWPayloadType.string => raw,
      HWPayloadType.int => '_\$payloadInt($raw)',
      HWPayloadType.double => '_\$payloadDouble($raw)',
      HWPayloadType.bool => '_\$payloadBool($raw)',
      HWPayloadType.dateTime => '_\$payloadDateTime($raw)',
    };
    final fallback = _fallback(entry);
    return fallback == null ? read : '$read ?? $fallback';
  }

  /// The expression for the text [entry] travels as, null while it holds no
  /// value.
  String _encode(HWPayloadEntry entry) {
    final access = entry.isNullable ? '${entry.name}?' : entry.name;
    return switch (entry.type!) {
      HWPayloadType.string => entry.name,
      HWPayloadType.dateTime =>
        '$access.toUtc().millisecondsSinceEpoch.toString()',
      _ => '$access.toString()',
    };
  }

  String _toUri() {
    if (url.payload.isEmpty) return '_\$url';
    final entries = [
      for (final entry in url.payload) "'${entry.name}': ${_encode(entry)}",
    ].join(', ');
    return "$writer('${escapeDartStringLiteral(url.head)}', {$entries}, "
        "'${url.appendedMarker}', "
        "'${escapeDartStringLiteral(url.fragment)}')";
  }

  /// What two instances compare [entry] by, read off [owner]: the value, and
  /// for a date the millisecond it travels as, which is all `toUri` keeps.
  String _identity(HWPayloadEntry entry, String owner) {
    final field = '$owner.${entry.name}';
    if (entry.type != HWPayloadType.dateTime) return field;
    return '$field${entry.isNullable ? '?' : ''}.millisecondsSinceEpoch';
  }

  String _equality(String className) => [
        'other is $className',
        for (final entry in url.payload)
          '${_identity(entry, 'other')} == ${_identity(entry, 'this')}',
      ].join(' && ');

  String _hashCode(String className) {
    final payload = url.payload;
    if (payload.isEmpty) return '($className).hashCode';
    final fields = payload.map((entry) => _identity(entry, 'this')).join(', ');
    return 'Object.hashAll([$className, $fields])';
  }

  String _description() => [
        for (final entry in url.payload) '${entry.name}: \$${entry.name}',
      ].join(', ');
}
