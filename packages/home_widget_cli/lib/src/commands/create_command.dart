import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../scaffold/scaffold.dart';
import '../util/exit_codes.dart';
import '../util/naming.dart';

/// `home_widget create <Name>`
class CreateCommand extends Command<int> {
  @override
  String get name => 'create';

  @override
  String get description =>
      'Create placeholder native structure for a new widget.';

  /// Creates the `create` command.
  CreateCommand() {
    argParser
      ..addFlag(
        'android',
        negatable: false,
        help: 'Create Android widget placeholder structure.',
      )
      ..addFlag(
        'ios',
        negatable: false,
        help: 'Create iOS widget placeholder structure.',
      );
  }

  @override
  Future<int> run() async {
    if (argResults == null) {
      return ExitCodes.software;
    }

    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException(
        'Missing widget name.\n\nExample: home_widget create Example',
        usage,
      );
    }

    final rawName = rest.first;
    final widgetBaseName = toPascalCase(rawName);
    final widgetClassName = '${widgetBaseName}HomeWidget';

    final cwd = Directory.current;
    final androidDir = Directory('${cwd.path}${Platform.pathSeparator}android');
    final iosDir = Directory('${cwd.path}${Platform.pathSeparator}ios');

    final androidFlag = argResults!['android'] == true;
    final iosFlag = argResults!['ios'] == true;

    final shouldAndroid =
        androidFlag || (!androidFlag && !iosFlag && androidDir.existsSync());
    final shouldIos =
        iosFlag || (!androidFlag && !iosFlag && iosDir.existsSync());

    if (!androidFlag && !iosFlag && !shouldAndroid && !shouldIos) {
      stdout.writeln(
        'No platform selected and no android/ or ios/ folder detected in '
        '${cwd.path}. Nothing to do.',
      );
      return ExitCodes.success;
    }

    if (shouldAndroid && !androidDir.existsSync()) {
      stderr.writeln(
        'Warning: requested Android scaffolding but no android/ folder exists '
        'in ${cwd.path}. Skipping Android.',
      );
    }
    if (shouldIos && !iosDir.existsSync()) {
      stderr.writeln(
        'Warning: requested iOS scaffolding but no ios/ folder exists in '
        '${cwd.path}. Skipping iOS.',
      );
    }

    final scaffold = WidgetScaffold(
      projectRoot: cwd,
      widgetClassName: widgetClassName,
    );

    if (shouldAndroid && androidDir.existsSync()) {
      await scaffold.createAndroid();
    }
    if (shouldIos && iosDir.existsSync()) {
      final appGroupId = _promptForIosAppGroupId();
      await scaffold.createIos(appGroupId: appGroupId);
    }

    await _ensureFlutterHomeWidgetDependency(cwd);

    stdout.writeln('Done. Created placeholder structure for $widgetClassName.');
    return ExitCodes.success;
  }
}

Future<void> _ensureFlutterHomeWidgetDependency(Directory projectRoot) async {
  final pubspec = File(p.join(projectRoot.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    stderr.writeln(
      'Warning: pubspec.yaml not found in ${projectRoot.path}; skipping '
      '`flutter pub add home_widget`.',
    );
    return;
  }

  final text = pubspec.readAsStringSync();
  // Cheap idempotency: if the dependency is already present anywhere, skip.
  if (RegExp(r'^\s*home_widget\s*:', multiLine: true).hasMatch(text)) {
    return;
  }

  final result = await Process.run(
    'flutter',
    ['pub', 'add', 'home_widget'],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );

  if (result.stdout != null && result.stdout.toString().trim().isNotEmpty) {
    stdout.write(result.stdout);
    if (!result.stdout.toString().endsWith('\n')) stdout.writeln();
  }
  if (result.stderr != null && result.stderr.toString().trim().isNotEmpty) {
    stderr.write(result.stderr);
    if (!result.stderr.toString().endsWith('\n')) stderr.writeln();
  }

  if (result.exitCode != 0) {
    stderr.writeln(
      'Warning: failed to run `flutter pub add home_widget` (exit code '
      '${result.exitCode}). You can run it manually in your project root.',
    );
  }
}

String _promptForIosAppGroupId() {
  const defaultValue = 'YOUR_APP_GROUP_ID';

  if (!stdin.hasTerminal) {
    stderr.writeln(
      'Note: stdin is not interactive; using default iOS App Group ID: '
      '$defaultValue',
    );
    return defaultValue;
  }

  stdout.writeln(
    'Enter iOS App Group ID (optional). Press Enter to use "$defaultValue".',
  );
  stdout.write('App Group ID [$defaultValue]: ');
  final input = stdin.readLineSync();
  final trimmed = input?.trim();
  if (trimmed == null || trimmed.isEmpty) return defaultValue;
  return trimmed;
}
