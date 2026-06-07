import 'package:test/test.dart';

import 'helpers/build_scenario_runner.dart';
import 'scenarios/shared_scenarios.dart';

void main() {
  final scenarios = [...sharedBuildScenarios];

  for (final scenario in scenarios) {
    test(
      'generates and builds ios app: ${scenario.description}',
      () => runIosBuildScenario(scenario),
      timeout: const Timeout(Duration(minutes: 10)),
      tags: ['integration', 'integration_ios'],
    );
  }
}
