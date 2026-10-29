/// Exit codes used by the CLI.
///
/// These align with common Unix `sysexits.h` conventions where applicable.
abstract final class ExitCodes {
  /// Successful termination.
  static const int success = 0;

  /// Command line usage error.
  static const int usage = 64;

  /// Software error.
  static const int software = 70;

  /// OS / file system error.
  static const int osFile = 72;

  /// Input file did not exist or was not readable.
  static const int noInput = 66;
}
