import 'dart:io';

import 'package:home_widget_cli/src/cli.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runCli(args);
  // Ensure stdout flushes before exiting on some shells/CI.
  await stdout.flush();
  await stderr.flush();
  exit(exitCode);
}
