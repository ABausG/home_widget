import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';

import 'logger.dart';

/// Sets [logger.level] from any `--verbose` / `-v` flag on the root or nested
/// command parse results.
void applyVerboseFromArgResults(ArgResults results) {
  var verbose = false;
  for (ArgResults? r = results; r != null; r = r.command) {
    if (r.options.contains('verbose') && r.flag('verbose')) {
      verbose = true;
      break;
    }
  }
  logger.level = verbose ? Level.verbose : Level.info;
}
