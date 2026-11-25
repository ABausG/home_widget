import 'package:test/test.dart';

import 'helpers/build_scenario_runner.dart';
import 'scenarios/appearance_scenarios.dart';
import 'scenarios/platform_split_scenarios.dart';
import 'scenarios/shared_scenarios.dart';

void main() {
  final scenarios = [
    ...sharedBuildScenarios,
    ...appearanceBuildScenarios,
    ...platformSplitBuildScenarios,
  ];

  for (final scenario in scenarios) {
    test(
      'generates and builds ios app: ${scenario.description}',
      () => runIosBuildScenario(scenario),
      timeout: const Timeout(Duration(minutes: 10)),
      tags: ['integration', 'integration_ios'],
    );
  }
}
