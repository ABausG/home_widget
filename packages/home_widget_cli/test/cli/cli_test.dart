import 'package:home_widget_cli/src/cli.dart';
import 'package:home_widget_cli/src/util/exit_codes.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/fake_progress.dart';
import '../helpers/recording_logger.dart';
import '../helpers/run_cli_in_project.dart';
import '../helpers/test_flutter_project.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.err(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);
    when(() => mockLogger.success(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.progress(any())).thenReturn(FakeProgress());
    when(() => mockLogger.progress(any(), options: any(named: 'options')))
        .thenReturn(FakeProgress());
  });

  test('--version exits success', () async {
    final code = await runCli(['--version']);
    expect(code, ExitCodes.success);
    verify(() => mockLogger.info('home_widget_cli 0.0.1')).called(1);
  });

  test('-v and --verbose set log level to verbose before --version', () async {
    final recording = RecordingLogger();
    logger = recording;
    final code = await runCli(['-v', '--version']);
    expect(code, ExitCodes.success);
    expect(recording.lastAppliedLevel, Level.verbose);
  });

  test('--verbose sets log level to verbose', () async {
    final recording = RecordingLogger();
    logger = recording;
    final code = await runCli(['--verbose', '--version']);
    expect(code, ExitCodes.success);
    expect(recording.lastAppliedLevel, Level.verbose);
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

  test('unknown global flag returns usage exit code and prints help', () async {
    final code = await runCli(['--definitely-not-a-flag']);
    expect(code, ExitCodes.usage);
    verify(
      () => mockLogger.err(
        any(that: contains('Usage: home_widget <command> [arguments]')),
      ),
    ).called(1);
  });

  test('unknown command-level flag returns usage exit code', () async {
    final code = await runCli(['create', '--definitely-not-a-flag']);
    expect(code, ExitCodes.usage);
    verify(() => mockLogger.err(any())).called(greaterThanOrEqualTo(1));
  });

  test('create without widget name prints usage and exits 64', () async {
    final code = await runCli(['create']);
    expect(code, ExitCodes.usage);
    verify(
      () => mockLogger.err(
        any(that: contains('Missing widget name')),
      ),
    ).called(1);
  });

  test(
    'create --ios uses default app group when stdin is not interactive',
    () async {
      final project = await TestFlutterProject.create(includeAndroid: false);
      final code = await runCliWithProjectRoot(
        project.root,
        ['create', 'Plop', '--ios'],
      );
      expect(code, ExitCodes.success);
      verify(
        () => mockLogger.warn(
          any(that: contains('YOUR_APP_GROUP_ID')),
        ),
      ).called(1);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
