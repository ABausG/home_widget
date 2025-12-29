/// Converts an arbitrary string into PascalCase suitable for class names.
String toPascalCase(String input) {
  final parts = input
      .trim()
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'Widget';
  }

  return parts.map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join();
}

/// Converts a PascalCase or camelCase string into snake_case.
String toSnakeCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return 'widget';

  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    final char = trimmed[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i != 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}
