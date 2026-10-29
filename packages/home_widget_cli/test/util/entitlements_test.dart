import 'dart:io';

import 'package:home_widget_cli/src/util/entitlements.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

void main() {
  late Directory tempDir;
  late MockLogger mockLogger;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hw_entitlements_');
    mockLogger = MockLogger();
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

    test('leaves a file that already holds the group byte for byte', () async {
      final file = entitlementsFile();

      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );
      final written = file.readAsStringSync();

      clearInteractions(mockLogger);
      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: 'group.example',
      );

      expect(file.readAsStringSync(), written);
      verifyNever(
        () => mockLogger.detail(any(that: contains('Updated entitlements'))),
      );
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

  group('removeAppGroupEntitlements', () {
    const twoGroups = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.example</string>
		<string>group.example.dev</string>
	</array>
</dict>
</plist>
''';

    test('removes only the given groups', () async {
      final file = entitlementsFile()..writeAsStringSync(twoGroups);

      await removeAppGroupEntitlements(
        entitlementsFile: file,
        appGroupIds: {'group.example.dev'},
      );

      final content = file.readAsStringSync();
      expect(content, isNot(contains('group.example.dev')));
      expect(content, contains('<string>group.example</string>'));
      expect(content, contains('<key>aps-environment</key>'));
    });

    test('removes the entitlement once no group is left', () async {
      final file = entitlementsFile()..writeAsStringSync(twoGroups);

      await removeAppGroupEntitlements(
        entitlementsFile: file,
        appGroupIds: {'group.example', 'group.example.dev'},
      );

      final content = file.readAsStringSync();
      expect(content, isNot(contains('application-groups')));
      expect(content, isNot(contains('<array')));
      expect(content, contains('<string>development</string>'));
    });

    test('leaves a file without the groups byte for byte', () async {
      final file = entitlementsFile()..writeAsStringSync(twoGroups);

      await removeAppGroupEntitlements(
        entitlementsFile: file,
        appGroupIds: {'group.other'},
      );

      expect(file.readAsStringSync(), twoGroups);
    });

    test('reads the groups a file lists', () async {
      final file = entitlementsFile();
      expect(await appGroupEntitlements(file), isEmpty);

      file.writeAsStringSync(twoGroups);

      expect(
        await appGroupEntitlements(file),
        {'group.example', 'group.example.dev'},
      );
    });

    test('creates an empty entitlements file only when missing', () async {
      final file = entitlementsFile();

      await ensureEntitlementsFile(file);
      expect(await appGroupEntitlements(file), isEmpty);
      expect(file.readAsStringSync(), contains('<dict>'));

      file.writeAsStringSync(twoGroups);
      await ensureEntitlementsFile(file);
      expect(file.readAsStringSync(), twoGroups);
    });

    test('does nothing for a missing file', () async {
      final file = entitlementsFile();

      await removeAppGroupEntitlements(
        entitlementsFile: file,
        appGroupIds: {'group.example'},
      );

      expect(file.existsSync(), isFalse);
    });

    test('warns and leaves file unchanged when XML is malformed', () async {
      final file = entitlementsFile();
      const garbage = 'not xml at all';
      file.writeAsStringSync(garbage);

      await removeAppGroupEntitlements(
        entitlementsFile: file,
        appGroupIds: {'group.example'},
      );

      expect(file.readAsStringSync(), equals(garbage));
      verify(
        () => mockLogger.warn(
          any(that: contains('Could not parse entitlements as XML')),
        ),
      ).called(1);
    });
  });
}
