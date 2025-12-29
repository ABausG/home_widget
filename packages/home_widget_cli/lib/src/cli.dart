import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands/create_command.dart';
import 'util/exit_codes.dart';

/// Runs the CLI and returns a process exit code.
Future<int> runCli(List<String> args) async {
  final runner = CommandRunner<int>(
    'home_widget',
    'Scaffold native widget parts for the home_widget plugin.',
  )..addCommand(CreateCommand());

  runner.argParser
    ..addFlag('version', negatable: false, help: 'Print the CLI version.')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose output.');

  ArgResults results;
  try {
    results = runner.argParser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('');
    stderr.writeln(_usage(runner));
    return ExitCodes.usage;
  }

  // Handle global flags (before command parsing).
  if (results['version'] == true) {
    // Keeping version handling simple for now; will be wired to pubspec later.
    stdout.writeln('home_widget_cli 0.1.0');
    return ExitCodes.success;
  }

  try {
    return await runner.run(args) ?? ExitCodes.success;
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('');
    stderr.writeln(e.usage);
    return ExitCodes.usage;
  } on FileSystemException catch (e) {
    stderr.writeln('File system error: ${e.message}');
    if (e.path != null) {
      stderr.writeln('Path: ${e.path}');
    }
    return ExitCodes.osFile;
  } catch (e) {
    stderr.writeln('Unexpected error: $e');
    return ExitCodes.software;
  }
}

String _usage(CommandRunner<int> runner) {
  final buffer = StringBuffer();
  buffer.writeln('Usage: home_widget <command> [arguments]');
  buffer.writeln('');
  buffer.writeln('Global options:');
  buffer.writeln(runner.argParser.usage);
  buffer.writeln('');
  buffer.writeln('Available commands:');
  buffer.writeln(runner.usage);
  return buffer.toString();
}
