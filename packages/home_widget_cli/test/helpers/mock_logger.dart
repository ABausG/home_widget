import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

/// Installs a [MockLogger] that accepts `detail`, `info` and `warn` calls as
/// the CLI's [logger] until the current test ends.
MockLogger useMockLogger() {
  final saved = logger;
  final mock = MockLogger();
  when(() => mock.detail(any())).thenReturn(null);
  when(() => mock.info(any())).thenReturn(null);
  when(() => mock.warn(any())).thenReturn(null);
  logger = mock;
  addTearDown(() => logger = saved);
  return mock;
}
