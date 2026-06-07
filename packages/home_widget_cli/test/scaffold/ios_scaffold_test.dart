import 'dart:io';

import 'package:home_widget_cli/src/scaffold/ios_scaffold.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.warn(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
  });

  test('IosWidgetScaffold warns when ios/ is missing', () async {
    final root = Directory.systemTemp.createTempSync('hw_ios_scaffold_no_ios');
    addTearDown(() => root.deleteSync(recursive: true));

    await IosWidgetScaffold(projectRoot: root, widgetClassName: 'XHomeWidget')
        .run(appGroupId: 'g');

    verify(
      () => mockLogger.warn(any(that: contains('ios/ not found'))),
    ).called(1);
  });

  test('IosWidgetScaffold warns when Xcode project file is missing', () async {
    final root = Directory.systemTemp.createTempSync(
      'hw_ios_scaffold_no_pbx',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    Directory(p.join(root.path, 'ios')).createSync(recursive: true);

    await IosWidgetScaffold(projectRoot: root, widgetClassName: 'YHomeWidget')
        .run(appGroupId: 'g');

    verify(
      () => mockLogger.warn(
        any(that: contains('project.pbxproj not found')),
      ),
    ).called(1);
  });
}
