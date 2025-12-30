import 'package:home_widget_cli/src/cli.dart';
import 'package:home_widget_cli/src/util/exit_codes.dart';
import 'package:test/test.dart';

void main() {
  test('--version exits success', () async {
    final code = await runCli(['--version']);
    expect(code, ExitCodes.success);
  });

  test('missing command returns usage', () async {
    final code = await runCli([]);
    // args.CommandRunner prints usage for missing command but still returns 0.
    expect(code, ExitCodes.success);
  });
}


