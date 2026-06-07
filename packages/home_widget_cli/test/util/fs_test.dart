import 'dart:io';

import 'package:home_widget_cli/src/util/fs.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger mockLogger;
  late Directory tempDir;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);

    tempDir = Directory.systemTemp.createTempSync('hw_cli_fs_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
  });

  test('writeFileIfMissing skips when file exists and preserves content',
      () async {
    final file = File('${tempDir.path}/skip_me.txt');
    const first = 'first';
    const second = 'second';

    await writeFileIfMissing(file, first);
    await writeFileIfMissing(file, second);

    verify(
      () => mockLogger.detail('Skipping existing file: ${file.path}'),
    ).called(1);
    verify(() => mockLogger.detail('Created: ${file.path}')).called(1);
    expect(file.readAsStringSync(), first);
  });
}
