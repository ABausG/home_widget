import 'dart:io';

import 'package:home_widget_cli/src/util/entitlements.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  late Directory tempDir;
  late _MockLogger mockLogger;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hw_entitlements_');
    mockLogger = _MockLogger();
    logger = mockLogger;
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  File entitlementsFile() => File(p.join(tempDir.path, 'Runner.entitlements'));

  group('ensureAppGroupEntitlement', () {
    test('creates a new entitlements file when missing', () async {
      final file = entitlementsFile();
      expect(file.existsSync(), isFalse);

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('com.apple.security.application-groups'));
      expect(content, contains('<string>group.example</string>'));
    });

    test('does nothing for empty appGroupId', () async {
      final file = entitlementsFile();
      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: '   ',
      );
      expect(file.existsSync(), isFalse);
    });

    test('appends new array to existing dict without app-groups key', () async {
      final file = entitlementsFile();
      file.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>com.apple.developer.something</key>
\t<true/>
</dict>
</plist>
''');

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );

      final content = file.readAsStringSync();
      expect(content, contains('com.apple.developer.something'));
      expect(content, contains('com.apple.security.application-groups'));
      expect(content, contains('<string>group.example</string>'));
      verify(
        () => mockLogger.detail(any(that: contains('Updated entitlements'))),
      ).called(1);
    });

    test('adds string to existing app-groups array', () async {
      final file = entitlementsFile();
      file.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>com.apple.security.application-groups</key>
\t<array>
\t\t<string>group.existing</string>
\t</array>
</dict>
</plist>
''');

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.new',
      );

      final content = file.readAsStringSync();
      expect(content, contains('<string>group.existing</string>'));
      expect(content, contains('<string>group.new</string>'));
    });

    test('does not duplicate id when already present and is stable on re-run',
        () async {
      final file = entitlementsFile();
      file.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>com.apple.security.application-groups</key>
\t<array>
\t\t<string>group.example</string>
\t</array>
</dict>
</plist>
''');

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );
      final afterFirst = file.readAsStringSync();
      expect(
        '<string>group.example</string>'.allMatches(afterFirst).length,
        1,
      );

      // Second invocation must be a true no-op: same content, no log.
      clearInteractions(mockLogger);
      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );
      expect(file.readAsStringSync(), equals(afterFirst));
      verifyNever(
        () => mockLogger.detail(any(that: contains('Updated entitlements'))),
      );
    });

    test('warns and leaves file unchanged when XML is malformed', () async {
      final file = entitlementsFile();
      const garbage = 'not xml at all';
      file.writeAsStringSync(garbage);

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );

      expect(file.readAsStringSync(), equals(garbage));
      verify(
        () => mockLogger.warn(
          any(that: contains('Could not parse entitlements as XML')),
        ),
      ).called(1);
    });

    test('warns when plist has no <dict>', () async {
      final file = entitlementsFile();
      const noDict = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
</plist>
''';
      file.writeAsStringSync(noDict);

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );

      expect(file.readAsStringSync(), equals(noDict));
      verify(
        () => mockLogger.warn(
          any(that: contains('Entitlements plist missing <dict>')),
        ),
      ).called(1);
    });
  });
}
