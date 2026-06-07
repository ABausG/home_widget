import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands/create_command.dart';
import 'commands/generate_command.dart';
import 'util/apply_log_level.dart';
import 'util/exit_codes.dart';
import 'util/logger.dart';

/// Runs the CLI and returns a process exit code.
Future<int> runCli(List<String> args) async {
  final runner = CommandRunner<int>(
    'home_widget',
    'Scaffold native widget parts for the home_widget plugin.',
  )
    ..addCommand(CreateCommand())
    ..addCommand(GenerateCommand());

  runner.argParser
    ..addFlag('version', negatable: false, help: 'Print the CLI version.')
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose output (per-file generated/updated paths).',
    );

  ArgResults results;
  try {
    results = runner.argParser.parse(args);
  } on FormatException catch (e) {
    logger.err(e.message);
    logger.err('');
    logger.err(_usage(runner));
    return ExitCodes.usage;
  }

  applyVerboseFromArgResults(results);

  // Handle global flags (before command parsing).
  if (results['version'] == true) {
    // Keeping version handling simple for now; will be wired to pubspec later.
    logger.info('home_widget_cli 0.0.1');
    return ExitCodes.success;
  }

  try {
    return await runner.run(args) ?? ExitCodes.success;
  } on UsageException catch (e) {
    logger.err(e.message);
    logger.err('');
    logger.err(e.usage);
    return ExitCodes.usage;
  } on FileSystemException catch (e) {
    // coverage:ignore-start
    logger.err('File system error: ${e.message}');
    if (e.path != null) {
      logger.err('Path: ${e.path}');
    }
    return ExitCodes.osFile;
    // coverage:ignore-end
  } catch (e) {
    logger.err('Unexpected error: $e');
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
