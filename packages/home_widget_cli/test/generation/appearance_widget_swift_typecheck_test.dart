@Tags(['integration', 'integration_ios'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'helpers/build_scenario_runner.dart';
import 'scenarios/appearance_scenarios.dart';
import 'scenarios/platform_split_scenarios.dart';

String? _unavailable() {
  try {
    final result = Process.runSync('xcrun', ['--find', 'swiftc']);
    if (result.exitCode != 0) return 'xcrun cannot find swiftc';
    return null;
  } on ProcessException {
    return 'xcrun is not available';
  }
}

void main() {
  final skip = _unavailable();

  for (final scenario in [
    ...appearanceBuildScenarios,
    ...platformSplitBuildScenarios,
  ]) {
    test(
      'type-checks the generated Swift: ${scenario.description}',
      () => typecheckIosScenario(scenario),
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skip,
    );
  }
}
