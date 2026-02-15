import 'package:dart_style/dart_style.dart';
import '../models/widget_spec.dart';

/// Generates a Dart helper class with type-safe accessors for widget data.
class DartHelperGenerator {
  /// The widget specification to generate helpers for.
  final WidgetSpec spec;

  /// Creates a new [DartHelperGenerator] for the given [spec].
  DartHelperGenerator(this.spec);

  /// Generates the Dart helper source code.
  String generate() {
    final buffer = StringBuffer();
    buffer.writeln('// dart format off');
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();
    buffer.writeln("import 'package:home_widget/home_widget.dart';");
    buffer.writeln();

    if (spec.interactivity != null) {
      buffer.writeln("import '${spec.interactivity!.import}';");
      buffer.writeln();
    }

    final className = '${spec.className}HomeWidget';

    buffer.writeln('class $className {');
    buffer.writeln('  const $className._();');
    buffer.writeln();
    buffer.writeln(
      "  static const String _paramPrefix = 'home_widget.${spec.className}.';",
    );
    buffer.writeln();

    buffer.writeln('  static Future<void> ensureInitialized() async {');
    if (spec.data.iOS != null) {
      buffer.writeln(
        "    await HomeWidget.setAppGroupId('${spec.data.iOS!.groupId}');",
      );
    }
    if (spec.interactivity != null) {
      buffer.writeln(
        "    await HomeWidget.registerInteractivityCallback(${spec.interactivity!.callback});",
      );
    }
    buffer.writeln('  }');
    buffer.writeln();

    if (spec.dataFields.isNotEmpty) {
      buffer.writeln('  static Future<void> saveData({');
      for (final field in spec.dataFields) {
        final type = field.type.dartType;
        buffer.writeln('    $type? ${field.key},');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in spec.dataFields) {
        final type = field.type.dartType;
        buffer.writeln(
          "      if (${field.key} != null) HomeWidget.saveWidgetData<$type>('\$_paramPrefix${field.key}', ${field.key}),",
        );
      }
      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln();

      buffer.writeln('  static Future<void> deleteData({');
      for (final field in spec.dataFields) {
        buffer.writeln('    bool ${field.key} = false,');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in spec.dataFields) {
        buffer.writeln(
          "      if (${field.key}) HomeWidget.saveWidgetData('\$_paramPrefix${field.key}', null),",
        );
      }
      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln();

      final recordFields =
          spec.dataFields.map((f) => '${f.type.dartType}? ${f.key}').join(', ');
      buffer.writeln(
        '  static Future<({$recordFields})> getData() async {',
      );
      buffer.writeln('    return (');
      for (final field in spec.dataFields) {
        final type = field.type.dartType;
        buffer.writeln(
          "      ${field.key}: await HomeWidget.getWidgetData<$type>('\$_paramPrefix${field.key}'),",
        );
      }
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln();
    buffer.writeln('  static Future<bool?> updateWidget() {');

    String? androidName;
    final receiverName = '${spec.className}HomeWidgetReceiver';
    if (spec.data.android != null && spec.data.android!.packageName != null) {
      androidName = '${spec.data.android!.packageName}.$receiverName';
    } else {
      androidName = receiverName;
    }

    final iosName =
        spec.data.iOS != null ? '${spec.className}HomeWidget' : null;

    buffer.writeln('    return HomeWidget.updateWidget(');
    buffer.writeln("      androidName: '$androidName',");
    if (iosName != null) {
      buffer.writeln("      iOSName: '$iosName',");
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln('}');

    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(buffer.toString());
  }
}
