import 'package:home_widget_generator/home_widget_generator_cli.dart';

import '../models/payload_field.dart';

/// Emits the Dart side of a payload: the class holding the values a tap sent,
/// built from the URL native code wrote them into and written back into one.
///
/// What it reads is what `HWPayloadUrl.toSwift` and `HWPayloadUrl.toKotlin`
/// write, so the three stay in step: the values as query parameters under
/// their names, percent-encoded, a date as its milliseconds since the epoch.
class PayloadDartEmitter {
  /// The URL the payload travels in. Its payload is left to [fields].
  final HWPayloadUrl url;

  /// The fields of the class, one per value a tap may send.
  final List<PayloadField> fields;

  /// Creates a [PayloadDartEmitter] for [url], with [fields] holding the
  /// payload of every target the class stands for, or the payload of [url]
  /// without them.
  PayloadDartEmitter(this.url, {List<PayloadField>? fields})
      : fields = fields ?? PayloadField.listOf(url.payload);

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
    final buffer = StringBuffer();
    buffer.write('''
/// $description
final class $className extends $superClass {
  const $className(${_constructorParameters()});
''');
    if (fields.isNotEmpty) buffer.writeln();
    for (final field in fields) {
      buffer.writeln('  final ${_fieldType(field)} ${field.name};');
    }

    final arguments = [
      for (final field in fields) '${field.name}: ${_decode(field)}',
    ].join(', ');
    buffer.write('''

  static final Uri _\$url = Uri.parse('${escapeDartStringLiteral(url.staticUrl)}');

  static $className? _\$fromUri(Uri uri) {
    try {
      if (!$matcher(uri, _\$url)) return null;
''');
    if (fields.isEmpty) {
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

  /// The file-level functions the classes of [emitters] call, each written
  /// once and only where one of them calls it.
  static String helpers(Iterable<PayloadDartEmitter> emitters) {
    final types = <HWPayloadType>{
      for (final emitter in emitters)
        for (final field in emitter.fields) field.type,
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
    if (emitters.any((emitter) => emitter.fields.isNotEmpty)) {
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
  if (millis == null || millis < -8640000000000000 || millis > 8640000000000000) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
''');
    }
    return buffer.toString();
  }

  String _fieldType(PayloadField field) =>
      '${field.type.dartType}${field.isNullable ? '?' : ''}';

  /// Whether the fallback of [field] can be a constructor default, which a
  /// `DateTime` cannot: it has no const constructor.
  bool _hasConstFallback(PayloadField field) =>
      !field.isNullable && field.type != HWPayloadType.dateTime;

  String _constructorParameters() {
    if (fields.isEmpty) return '';
    final parameters = [
      for (final field in fields)
        if (field.isNullable)
          'this.${field.name}'
        else if (_hasConstFallback(field))
          'this.${field.name} = ${field.fallback}'
        else
          'required this.${field.name}',
    ].join(', ');
    return '{$parameters}';
  }

  /// The expression reading [field] out of `query`, the decoded query
  /// parameters. A value that is missing or unreadable is null, or the
  /// fallback of a field that is never null.
  String _decode(PayloadField field) {
    final raw = "query['${field.name}']";
    final read = switch (field.type) {
      HWPayloadType.string => raw,
      HWPayloadType.int => '_\$payloadInt($raw)',
      HWPayloadType.double => '_\$payloadDouble($raw)',
      HWPayloadType.bool => '_\$payloadBool($raw)',
      HWPayloadType.dateTime => '_\$payloadDateTime($raw)',
    };
    final fallback = field.fallback;
    return fallback == null ? read : '$read ?? $fallback';
  }

  /// The expression for the text [field] travels as, null while it holds no
  /// value.
  String _encode(PayloadField field) {
    final access = field.isNullable ? '${field.name}?' : field.name;
    return switch (field.type) {
      HWPayloadType.string => field.name,
      HWPayloadType.dateTime =>
        '$access.toUtc().millisecondsSinceEpoch.toString()',
      _ => '$access.toString()',
    };
  }

  String _toUri() {
    if (fields.isEmpty) return '_\$url';
    final entries = [
      for (final field in fields) "'${field.name}': ${_encode(field)}",
    ].join(', ');
    return "$writer('${escapeDartStringLiteral(url.head)}', {$entries}, "
        "'${url.appendedMarker}', "
        "'${escapeDartStringLiteral(url.fragment)}')";
  }

  /// What two instances compare [field] by, read off [owner]: the value, and
  /// for a date the millisecond it travels as, which is all `toUri` keeps.
  String _identity(PayloadField field, String owner) {
    final access = '$owner.${field.name}';
    if (field.type != HWPayloadType.dateTime) return access;
    return '$access${field.isNullable ? '?' : ''}.millisecondsSinceEpoch';
  }

  String _equality(String className) => [
        'other is $className',
        for (final field in fields)
          '${_identity(field, 'other')} == ${_identity(field, 'this')}',
      ].join(' && ');

  String _hashCode(String className) {
    if (fields.isEmpty) return '($className).hashCode';
    final identities =
        fields.map((field) => _identity(field, 'this')).join(', ');
    return 'Object.hashAll([$className, $identities])';
  }

  String _description() => [
        for (final field in fields) '${field.name}: \$${field.name}',
      ].join(', ');
}
