import 'dart:io';

import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:test/test.dart';

/// Minimal pbxproj snippet with Runner build configurations.
///
/// Mirrors the structure produced by `flutter create`: each configuration
/// contains `INFOPLIST_FILE = Runner/Info.plist;` which is how the patcher
/// identifies Runner configs.
String _buildPbxproj({required String deploymentTarget}) => '''
// !&#36;*UTF8*&#36;!
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
// !&#36;*UTF8*&#36;!
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
// !&#36;*UTF8*&#36;!
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
}
