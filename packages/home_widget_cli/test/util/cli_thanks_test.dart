import 'package:home_widget_cli/src/util/cli_thanks.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

void main() {
  group('CLI thanks note', () {
    late MockLogger mockLogger;
    late List<String> infos;

    setUp(() {
      final saved = logger;
      mockLogger = MockLogger();
      infos = [];
      when(() => mockLogger.info(any())).thenAnswer((invocation) {
        infos.add(invocation.positionalArguments.first as String);
      });
      when(() => mockLogger.success(any())).thenReturn(null);
      when(() => mockLogger.write(any())).thenReturn(null);
      logger = mockLogger;
      addTearDown(() => logger = saved);
    });

    test('links to GitHub Sponsors without styling when ANSI is off', () {
      overrideAnsiOutput(false, logGenerateSuccessThanks);

      verify(() => mockLogger.success('Widgets generated successfully.'))
          .called(1);
      expect(infos.single, contains('github.com/sponsors/ABausG'));
      expect(
        infos.single,
        contains('supporting the project on GitHub Sponsors'),
      );
      expect(infos.single, isNot(contains(styleUnderlined.escape)));
    });

    test('underlines the anchor text when ANSI is on', () {
      overrideAnsiOutput(true, logCreateSuccessThanks);

      verify(() => mockLogger.success('Widget scaffolded successfully.'))
          .called(1);
      expect(infos.single, contains('github.com/sponsors/ABausG'));
      expect(infos.single, contains(styleUnderlined.escape));
      expect(infos.single, contains(lightBlue.escape));
    });
  });
}
