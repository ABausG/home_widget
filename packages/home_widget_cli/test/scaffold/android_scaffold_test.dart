import 'dart:io';

import 'package:home_widget_cli/src/scaffold/android_scaffold.dart';
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
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.success(any())).thenReturn(null);
  });

  test('AndroidWidgetScaffold warns when android/app/ is missing', () async {
    final root = Directory.systemTemp.createTempSync('hw_android_scaffold_no');
    addTearDown(() => root.deleteSync(recursive: true));

    await AndroidWidgetScaffold(
      projectRoot: root,
      widgetClassName: 'XHomeWidget',
    ).run();

    verify(
      () => mockLogger.warn(any(that: contains('android/app/ not found'))),
    ).called(1);
  });

  test('the placeholder widget imports everything its preview names', () async {
    final root = Directory.systemTemp.createTempSync('hw_android_scaffold');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory(p.join(root.path, 'android', 'app')).createSync(recursive: true);

    await AndroidWidgetScaffold(
      projectRoot: root,
      widgetClassName: 'FooHomeWidget',
    ).run();

    final source = File(
      p.join(
        root.path,
        'android/app/src/main/kotlin/com/example/FooHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(source, contains('override suspend fun providePreview('));
    expect(source, contains('HomeWidgetPlugin.getData(context)'));
    expect(
      source,
      contains('import es.antonborri.home_widget.HomeWidgetPlugin'),
    );
    expect(source, isNot(contains('HomeWidgetPreviews')));
  });
}
