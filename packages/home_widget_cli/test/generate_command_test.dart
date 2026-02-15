import 'package:args/command_runner.dart';
import 'package:home_widget_cli/src/commands/generate_command.dart';
import 'package:home_widget_cli/src/util/exit_codes.dart';
import 'package:test/test.dart';

void main() {
  late CommandRunner<int> runner;

  setUp(() {
    runner = CommandRunner<int>('test', 'test')..addCommand(GenerateCommand());
  });

  test('fails if input path does not exist', () async {
    final result =
        await runner.run(['generate', '--input', 'non_existent_path']);
    expect(result, ExitCodes.noInput);
  });
}
