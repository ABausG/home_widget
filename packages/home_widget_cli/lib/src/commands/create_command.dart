import 'dart:io';

import 'package:args/command_runner.dart';

import '../scaffold/scaffold.dart';
import '../util/cli_thanks.dart';
import '../util/dependencies.dart';
import '../util/exit_codes.dart';
import '../util/logger.dart';
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
      )
      ..addOption(
        'ios-app-group-id',
        help:
            'iOS App Group ID to write into entitlements and widget placeholder '
            'code. If omitted and stdin is interactive, the CLI will prompt. '
            'If omitted and stdin is non-interactive, it defaults to '
            '"YOUR_APP_GROUP_ID".',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        hide: true,
        help: 'Enable verbose output.',
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
      logger.info(
        'No platform selected and no android/ or ios/ folder detected in '
        '${cwd.path}. Nothing to do.',
      );
      return ExitCodes.success;
    }

    if (shouldAndroid && !androidDir.existsSync()) {
      logger.warn(
        'Requested Android scaffolding but no android/ folder exists '
        'in ${cwd.path}. Skipping Android.',
      );
    }
    if (shouldIos && !iosDir.existsSync()) {
      logger.warn(
        'Requested iOS scaffolding but no ios/ folder exists in '
        '${cwd.path}. Skipping iOS.',
      );
    }

    final scaffold = WidgetScaffold(
      projectRoot: cwd,
      widgetClassName: widgetClassName,
    );

    final steps = <({String label, Future<void> Function() run})>[];
    if (shouldAndroid && androidDir.existsSync()) {
      steps.add(
        (
          label: 'Scaffolding Android widget',
          run: () => scaffold.createAndroid(),
        ),
      );
    }
    if (shouldIos && iosDir.existsSync()) {
      steps.add(
        (
          label: 'Scaffolding iOS widget',
          run: () async {
            final appGroupId = _resolveIosAppGroupId(
              fromArgs: argResults?['ios-app-group-id'] as String?,
            );
            await scaffold.createIos(appGroupId: appGroupId);
          },
        ),
      );
    }
    steps.add(
      (
        label: 'Ensuring home_widget dependency',
        run: () => ensureFlutterHomeWidgetDependency(cwd),
      ),
    );

    final total = steps.length;
    final base = 'Scaffolding $widgetBaseName home_widget';
    final progress = logger.progress(base);
    for (var i = 0; i < steps.length; i++) {
      progress.update('$base · ${i + 1}/$total ${steps[i].label}');
      await steps[i].run();
    }
    progress.complete('Scaffolded $widgetBaseName home_widget');

    logCreateSuccessThanks();
    return ExitCodes.success;
  }
}

String _resolveIosAppGroupId({required String? fromArgs}) {
  const defaultValue = 'YOUR_APP_GROUP_ID';

  final trimmedArg = fromArgs?.trim();
  if (trimmedArg != null && trimmedArg.isNotEmpty) return trimmedArg;

  if (!stdin.hasTerminal) {
    logger.warn(
      'Stdin is not interactive; using default iOS App Group ID: '
      '$defaultValue',
    );
    return defaultValue;
  }

  // coverage:ignore-start
  final input = logger.prompt(
    'Enter iOS App Group ID (optional). Press Enter to use "$defaultValue".',
    defaultValue: defaultValue,
  );
  return input;
  // coverage:ignore-end
}
