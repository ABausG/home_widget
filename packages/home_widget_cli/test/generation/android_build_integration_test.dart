import 'package:test/test.dart';

import 'helpers/build_scenario_runner.dart';
import 'scenarios/android_scenarios.dart';
import 'scenarios/appearance_scenarios.dart';
import 'scenarios/platform_split_scenarios.dart';
import 'scenarios/shared_scenarios.dart';

void main() {
  final scenarios = [
    ...androidBuildScenarios,
    ...sharedBuildScenarios,
    ...appearanceBuildScenarios,
    ...platformSplitBuildScenarios,
  ];

  for (final scenario in scenarios) {
    test(
      'generates and builds android app: ${scenario.description}',
      () => runAndroidBuildScenario(scenario),
      timeout: const Timeout(Duration(minutes: 5)),
      tags: ['integration', 'integration_android'],
    );
  }
}
