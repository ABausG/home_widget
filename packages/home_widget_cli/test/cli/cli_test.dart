import 'package:home_widget_cli/src/cli.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/util/exit_codes.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
  });

  test('--version exits success', () async {
    final code = await runCli(['--version']);
    expect(code, ExitCodes.success);
    verify(() => mockLogger.info('home_widget_cli 0.1.0')).called(1);
  });

  test('missing command returns usage', () async {
    final code = await runCli([]);
    expect(code, ExitCodes.success);
    verifyNever(() => mockLogger.err(any()));
  });

  test('unknown command prints usage and returns error', () async {
    final code = await runCli(['unknown']);
    expect(code, ExitCodes.usage);
    verify(
      () => mockLogger.err(
        any(that: contains('Could not find a command named "unknown".')),
      ),
    ).called(1);
    verify(
      () => mockLogger.err(
        any(that: contains('Usage: home_widget <command> [arguments]')),
      ),
    ).called(1);
  });
}
