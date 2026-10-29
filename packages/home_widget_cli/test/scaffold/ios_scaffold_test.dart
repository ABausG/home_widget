import 'dart:io';

import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/scaffold/ios_scaffold.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/xcode_project.dart';

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

  test('IosWidgetScaffold fails without an Xcode project and writes nothing',
      () async {
    final root = Directory.systemTemp.createTempSync(
      'hw_ios_scaffold_no_pbx',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    final iosDir = Directory(p.join(root.path, 'ios'))
      ..createSync(recursive: true);
    final scaffold =
        IosWidgetScaffold(projectRoot: root, widgetClassName: 'YHomeWidget');
    final noProject = throwsA(
      isA<GeneratorError>().having(
        (e) => e.message,
        'message',
        startsWith('No Xcode project found in ${iosDir.path}.'),
      ),
    );

    await expectLater(scaffold.check(), noProject);
    await expectLater(scaffold.run(appGroupId: 'g'), noProject);

    expect(iosDir.listSync(), isEmpty);
    verifyNever(() => mockLogger.warn(any()));
  });

  test('IosWidgetScaffold writes the entitlements next to the app Info.plist',
      () async {
    final root = Directory.systemTemp.createTempSync('hw_ios_scaffold_app');
    addTearDown(() => root.deleteSync(recursive: true));
    final pbxprojFile = File(
      p.join(root.path, 'ios', 'App.xcodeproj', 'project.pbxproj'),
    )
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        flavoredPbxproj(const [])
            .replaceAll('Runner/Info.plist', 'App/Info.plist'),
      );
    when(() => mockLogger.detail(any())).thenReturn(null);

    await IosWidgetScaffold(projectRoot: root, widgetClassName: 'ZHomeWidget')
        .run(appGroupId: 'group.app');

    expect(
      File(p.join(root.path, 'ios', 'App', 'App.entitlements'))
          .readAsStringSync(),
      contains('<string>group.app</string>'),
    );
    expect(Directory(p.join(root.path, 'ios', 'Runner')).existsSync(), isFalse);
    expect(
      pbxprojFile.readAsStringSync(),
      contains('CODE_SIGN_ENTITLEMENTS = App/App.entitlements;'),
    );
  });
}
