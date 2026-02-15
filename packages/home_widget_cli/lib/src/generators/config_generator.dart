import 'package:dart_style/dart_style.dart';

import '../models/widget_spec.dart';

/// Generates the configuration file for the widget.
class ConfigGenerator {
  /// The widget specification to generate config for.
  final WidgetSpec spec;

  /// Creates a new [ConfigGenerator] for the given [spec].
  ConfigGenerator(this.spec);

  /// Generates the configuration Dart source code.
  String generate() {
    final buffer = StringBuffer();
    buffer.writeln('// dart format off');
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();
    buffer.writeln(
      "import 'package:home_widget_generator/home_widget_generator.dart';",
    );
    buffer.writeln();

    final dataClassName = '${spec.className}Data';

    buffer.writeln('class $dataClassName {');
    buffer.writeln('  const $dataClassName._();');
    buffer.writeln();

    for (final field in spec.dataFields) {
      final type = field.type.dartType;
      buffer.writeln(
        "  static const HWDataRef<$type> ${field.key} = HWDataRef<$type>('${field.key}');",
      );
    }

    buffer.writeln('}');

    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(buffer.toString());
  }
}
