import 'dart:io';

import 'package:home_widget_cli/src/util/fnv_hash.dart';
import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:test/test.dart';

/// Project shaped like one the generator has already added an extension to:
/// an empty Resources phase, a group for the extension folder, and the
/// `knownRegions` list `flutter create` produces.
String _buildPbxprojWithExtension() {
  final resourcesPhaseId = xcodeObjectId('phase:resources:GreetingHomeWidget');
  final groupId = xcodeObjectId('group:GreetingHomeWidget');
  return '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXBuildFile section */
		11111111111111111111AAAA /* Widget.swift in Sources */ = {isa = PBXBuildFile; fileRef = 22222222222222222222BBBB /* Widget.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		22222222222222222222BBBB /* Widget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Widget.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		$groupId /* GreetingHomeWidget */ = {
			isa = PBXGroup;
			children = (
				22222222222222222222BBBB /* Widget.swift */,
			);
			path = GreetingHomeWidget;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXResourcesBuildPhase section */
		$resourcesPhaseId /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 97C146E51CF9000F007C117D;
		};
/* End PBXProject section */

	};
}
''';
}

/// Project where the widget's extension folder is a synchronized root group,
/// the shape `flutter create` produces under Xcode 16.
///
/// Every file in the folder is already a member of the target, so the catalog
/// must not be added a second time — Xcode would copy it twice and fail.
String _buildPbxprojWithSynchronizedGroup() {
  final fsRootGroupId = xcodeObjectId('fsgroup:GreetingHomeWidget');
  final fsExceptionId = xcodeObjectId('fsex:GreetingHomeWidget');
  final targetId = xcodeObjectId('target:GreetingHomeWidget');
  return '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		$fsExceptionId /* Exceptions for "GreetingHomeWidget" folder in "GreetingHomeWidget" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Info.plist,
			);
			target = $targetId /* GreetingHomeWidget */;
		};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		$fsRootGroupId /* GreetingHomeWidget */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = GreetingHomeWidget;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 97C146E51CF9000F007C117D;
		};
/* End PBXProject section */

	};
}
''';
}

/// The mixed case: the project has a synchronized root group section (some
/// *other* folder uses one), but this widget's extension was scaffolded as a
/// classic `PBXGroup`.
///
/// Deciding from the project-global marker skips the wiring here, so the
/// catalog ends up in no target at all.
String _buildPbxprojWithForeignSynchronizedGroup() {
  final base = _buildPbxprojWithExtension();
  return base.replaceFirst(
    '/* Begin PBXGroup section */',
    '''
/* Begin PBXFileSystemSynchronizedRootGroup section */
		CCCCCCCCCCCCCCCCCCCCCCCC /* SomeOtherFolder */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = SomeOtherFolder;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXGroup section */''',
  );
}

/// Minimal pbxproj snippet with Runner build configurations.
///
/// Mirrors the structure produced by `flutter create`: each configuration
/// contains `INFOPLIST_FILE = Runner/Info.plist;` which is how the patcher
/// identifies Runner configs.
String _buildPbxproj({required String deploymentTarget}) => '''
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	objectVersion = 54;
	objects = {

/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $deploymentTarget;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
		97C147071CF9000F007C117D /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $deploymentTarget;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Release;
		};
		249021D3217E4FDB00AE95B9 /* Profile */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $deploymentTarget;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Profile;
		};
/* End XCBuildConfiguration section */

	};
}
''';

/// Variant with no IPHONEOS_DEPLOYMENT_TARGET at all.
String _buildPbxprojWithoutDeploymentTarget() => '''
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	objectVersion = 54;
	objects = {

/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */

	};
}
''';

void main() {
  late Directory tempDir;
  late File pbxprojFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pbxproj_test');
    pbxprojFile = File('${tempDir.path}/project.pbxproj');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ensureMinimumDeploymentTargetInXcodeProject', () {
    test('bumps deployment target when below minimum', () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '12.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
      expect(result, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 12.0;')));
    });

    test('leaves deployment target unchanged when already at minimum',
        () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '14.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
    });

    test('leaves deployment target unchanged when above minimum', () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '16.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
      expect(result, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;')));
    });

    test('inserts deployment target when absent', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithoutDeploymentTarget());

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
    });

    test('respects custom minimum version', () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '14.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        minimumVersion: 17.0,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 17.0;'));
    });

    test('does not modify non-Runner configs', () async {
      // A config that does NOT have INFOPLIST_FILE = Runner/Info.plist
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		AABBCCDD11223344EEFF5566 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = MyExtension/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 12.0;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      // Should still be 12.0 — non-Runner config should not be touched.
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 12.0;'));
    });
  });

  group('ensureLocalizableCatalogInXcodeProject', () {
    Future<String> wire({List<String> locales = const ['en', 'de', 'pt-BR']}) {
      return ensureLocalizableCatalogInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
        locales: locales,
      ).then((_) => pbxprojFile.readAsStringSync());
    }

    test('adds the catalog as a resource of the extension', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final result = await wire();

      expect(
        result,
        contains('lastKnownFileType = text.json.xcstrings; '
            'path = Localizable.xcstrings;'),
      );
      expect(
        result,
        contains('/* Localizable.xcstrings in Resources */ = '
            '{isa = PBXBuildFile;'),
      );
      // Listed in the Resources phase, or it never ships.
      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(resourcesPhase, contains('Localizable.xcstrings in Resources'));
      // And visible in the extension's group in Xcode.
      final group = RegExp(
        r'isa = PBXGroup;[\s\S]*?children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(group, contains('/* Localizable.xcstrings */'));
    });

    test('adds every configured locale to knownRegions', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final result = await wire();

      final regions = RegExp(
        r'knownRegions = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(regions, contains('de,'));
      // A tag that is not a bare identifier has to be quoted.
      expect(regions, contains('"pt-BR",'));
      // Existing entries are kept, and `en` is not duplicated.
      expect(regions, contains('Base,'));
      expect('en'.allMatches(regions).length, 1);
    });

    test('is idempotent', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final first = await wire();
      final second = await wire();

      expect(second, first);
    });

    test('only patches knownRegions for a synchronized group', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithSynchronizedGroup());

      final result = await wire();

      // The synced folder already builds the catalog; a second, explicit
      // reference would make Xcode copy it twice and fail the build.
      expect(result, isNot(contains('Localizable.xcstrings')));
      final regions = RegExp(
        r'knownRegions = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(regions, contains('de,'));
      expect(regions, contains('"pt-BR",'));
    });

    test('wires the catalog when only another folder is synchronized',
        () async {
      pbxprojFile
          .writeAsStringSync(_buildPbxprojWithForeignSynchronizedGroup());

      final result = await wire();

      // The widget itself has a classic PBXGroup, so it needs the explicit
      // reference — deciding from the project-global marker would leave the
      // catalog in no target and every constant rendering as its resource key.
      expect(
        result,
        contains('lastKnownFileType = text.json.xcstrings; '
            'path = Localizable.xcstrings;'),
      );
      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(resourcesPhase, contains('Localizable.xcstrings in Resources'));
      final group = RegExp(
        r'isa = PBXGroup;[\s\S]*?children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(group, contains('/* Localizable.xcstrings */'));
    });
  });

  group('ensureWidgetExtensionDevelopmentTeamInXcodeProject', () {
    test('copies DEVELOPMENT_TEAM from Runner to widget extensions', () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEVELOPMENT_TEAM = TEAM123;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
		AABBCCDD11223344EEFF5566 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLICATION_EXTENSION_API_ONLY = YES;
				CODE_SIGN_ENTITLEMENTS = MyWidgetHomeWidget.entitlements;
				CODE_SIGN_STYLE = Automatic;
				INFOPLIST_FILE = MyWidgetHomeWidget/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app.MyWidgetHomeWidget;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('DEVELOPMENT_TEAM = TEAM123;'));
      expect(
        'DEVELOPMENT_TEAM = TEAM123;'.allMatches(result).length,
        2,
      );
    });

    test('does not modify Runner configs', () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEVELOPMENT_TEAM = TEAM123;
				INFOPLIST_FILE = Runner/Info.plist;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      expect(
        'DEVELOPMENT_TEAM = TEAM123;'
            .allMatches(
              pbxprojFile.readAsStringSync(),
            )
            .length,
        1,
      );
    });
  });
}
