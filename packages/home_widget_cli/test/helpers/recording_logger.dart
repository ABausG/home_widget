import 'package:mason_logger/mason_logger.dart';

/// [Logger] that records the last [level] assignment (for CLI tests).
class RecordingLogger extends Logger {
  RecordingLogger() : super();

  Level lastAppliedLevel = Level.info;

  @override
  set level(Level value) {
    lastAppliedLevel = value;
    super.level = value;
  }
}
