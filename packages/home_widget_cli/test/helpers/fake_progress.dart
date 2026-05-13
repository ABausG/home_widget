import 'package:mason_logger/mason_logger.dart';

/// No-op [Progress] for tests that mock [Logger.progress].
class FakeProgress implements Progress {
  @override
  void cancel() {}

  @override
  void complete([String? update]) {}

  @override
  void fail([String? update]) {}

  @override
  void update(String update) {}
}
