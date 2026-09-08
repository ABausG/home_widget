import 'dart:io';

import 'package:home_widget_cli/src/util/fnv_hash.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

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

/// A native flavor, i.e. the trio of Runner build configurations Flutter
/// creates for `--flavor <name>`.
final class _RunnerFlavor {
  const _RunnerFlavor({
    required this.name,
    required this.idPrefix,
    required this.bundleId,
    this.entitlements,
    this.entitlementsByConfiguration = const {},
  });

  final String name;
  final String idPrefix;
  final String bundleId;
  final String? entitlements;

  /// What each of the three configurations signs with, keyed by base name; a
  /// base name it does not list falls back to [entitlements].
  final Map<String, String?> entitlementsByConfiguration;

  String? entitlementsFor(String baseName) =>
      entitlementsByConfiguration.containsKey(baseName)
          ? entitlementsByConfiguration[baseName]
          : entitlements;
}

const _dev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: 'Runner/RunnerDev.entitlements',
);
const _prod = _RunnerFlavor(
  name: 'prod',
  idPrefix: 'BB',
  bundleId: 'com.example.app',
);
const _stg = _RunnerFlavor(
  name: 'stg',
  idPrefix: 'CC',
  bundleId: 'com.example.app.stg',
);

/// A flavor whose values Xcode had to quote, because neither a bundle id with
/// a dash nor a path holding a build variable is a bare identifier.
const _quotedDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: '"com.example.app-dev"',
  entitlements: r'"$(SRCROOT)/Runner/RunnerDev.entitlements"',
);

/// A flavor signing with a file only Xcode can locate.
const _customPathDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: r'"$(CUSTOM)/RunnerDev.entitlements"',
);

/// A flavor whose Debug configuration signs with a different file than its
/// Release and Profile ones, the split an app that keeps `aps-environment` per
/// configuration ends up with.
const _splitDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: 'Runner/RunnerDevRelease.entitlements',
  entitlementsByConfiguration: {'Debug': 'Runner/RunnerDevDebug.entitlements'},
);

/// A flavor only its Release configuration gives an entitlements file.
const _releaseOnlyDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlementsByConfiguration: {
    'Release': 'Runner/RunnerDevRelease.entitlements',
  },
);

const _baseConfigNames = ['Debug', 'Release', 'Profile'];

String _flavorConfigId(String prefix, int rank) => '$prefix${'0' * 21}$rank';

String _runnerConfigObject({
  required String id,
  required String name,
  required String bundleId,
  String? entitlements,
  bool infoPlist = true,
}) {
  final entitlementsLine = entitlements == null
      ? ''
      : '\t\t\t\tCODE_SIGN_ENTITLEMENTS = $entitlements;\n';
  final infoPlistLine =
      infoPlist ? '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n' : '';
  return '''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
$entitlementsLine\t\t\t\tDEVELOPMENT_TEAM = TEAM123;
$infoPlistLine\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $bundleId;
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''';
}

/// A configuration name the way Xcode stores it: quoted unless it is a bare
/// identifier, so a flavored one reads `name = "Debug-dev";`.
String _configName(String name) =>
    RegExp(r'^[A-Za-z0-9_$./]+$').hasMatch(name) ? name : '"$name"';

/// A Runner configuration that leaves everything to the project level, the way
/// flutter_flavorizr writes a flavor's target configuration.
String _bareConfigObject({required String id, required String name}) => '''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''';

/// A `flutter create` shaped project with Runner configurations for [flavors].
///
/// Carries the sections the extension scaffolder inserts into, a project-level
/// `Debug` that is *not* a Runner config (it must stay untouched), and a Runner
/// `XCConfigurationList` listing exactly the Runner configurations.
///
/// [flavorSettingsInProject] moves each flavor's settings to the project-level
/// configuration of the same name, which is where flutter_flavorizr puts them.
/// [infoPlistInProjectSettings] keeps the `INFOPLIST_FILE` marker out of those,
/// so nothing but the Runner target's configuration list says which
/// configurations are Runner's.
String _buildFlavoredPbxproj({
  List<_RunnerFlavor> flavors = const [_dev, _prod],
  bool flavorSettingsInProject = false,
  bool infoPlistInProjectSettings = true,
  String? baseEntitlements,
}) {
  final configObjects = <String>[];
  final configListEntries = <String>[];
  final projectConfigEntries = <String>[];

  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = _baseConfigNames[rank];
    final id = '97C1470${rank}1CF9000F007C117D';
    configObjects.add(
      _runnerConfigObject(
        id: id,
        name: name,
        bundleId: 'com.example.app',
        entitlements: baseEntitlements,
      ),
    );
    configListEntries.add('\t\t\t\t$id /* $name */,');
  }
  for (final flavor in flavors) {
    for (var rank = 0; rank < _baseConfigNames.length; rank++) {
      final name = '${_baseConfigNames[rank]}-${flavor.name}';
      final id = _flavorConfigId(flavor.idPrefix, rank + 1);
      final settings = _runnerConfigObject(
        id: flavorSettingsInProject ? '${flavor.idPrefix}${'F' * 21}$rank' : id,
        name: name,
        bundleId: flavor.bundleId,
        entitlements: flavor.entitlementsFor(_baseConfigNames[rank]),
        infoPlist: !flavorSettingsInProject || infoPlistInProjectSettings,
      );
      if (flavorSettingsInProject) {
        configObjects.add(_bareConfigObject(id: id, name: name));
        configObjects.add(settings);
        projectConfigEntries.add(
          '\t\t\t\t${flavor.idPrefix}${'F' * 21}$rank /* $name */,',
        );
      } else {
        configObjects.add(settings);
      }
      configListEntries.add('\t\t\t\t$id /* $name */,');
    }
  }

  return '''
// !\$*UTF8*\$!
{
\tarchiveVersion = 1;
\tobjectVersion = 54;
\tobjects = {

/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t97C146EE1CF9000F007C117D /* Runner.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Runner.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t97C146EB1CF9000F007C117D /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t97C146E51CF9000F007C117D = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t97C146EF1CF9000F007C117D /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t97C146EF1CF9000F007C117D /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t97C146ED1CF9000F007C117D /* Runner */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;
\t\t\tbuildPhases = (
\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,
\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,
\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,
\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Runner;
\t\t\tproductName = Runner;
\t\t\tproductReference = 97C146EE1CF9000F007C117D /* Runner.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t97C146E61CF9000F007C117D /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tbuildConfigurationList = 97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = 97C146E51CF9000F007C117D;
\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;
\t\t\ttargets = (
\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t97C146EC1CF9000F007C117D /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t97C146EA1CF9000F007C117D /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
\t\t97C147031CF9000F007C117D /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t};
\t\t\tname = Debug;
\t\t};
${configObjects.join('\n')}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t97C147031CF9000F007C117D /* Debug */,
${projectConfigEntries.join('\n')}
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
${configListEntries.join('\n')}
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
}

/// Adds [flavor]'s Runner configurations to an existing project, the way a
/// developer adding a flavor to an app that already has a widget would.
String _addRunnerFlavor(String pbxproj, _RunnerFlavor flavor) {
  final objects = <String>[];
  final entries = <String>[];
  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = '${_baseConfigNames[rank]}-${flavor.name}';
    final id = _flavorConfigId(flavor.idPrefix, rank + 1);
    objects.add(
      _runnerConfigObject(
        id: id,
        name: name,
        bundleId: flavor.bundleId,
        entitlements: flavor.entitlementsFor(_baseConfigNames[rank]),
      ),
    );
    entries.add('\t\t\t\t$id /* $name */,');
  }

  var out = pbxproj.replaceFirst(
    '/* End XCBuildConfiguration section */',
    '${objects.join('\n')}\n/* End XCBuildConfiguration section */',
  );

  const listMarker =
      '/* Build configuration list for PBXNativeTarget "Runner" */ = {';
  final listStart = out.indexOf(listMarker);
  final listEnd = out.indexOf('\t\t\t);', listStart);
  return out.replaceRange(listEnd, listEnd, '${entries.join('\n')}\n');
}

/// The extension's build configuration object named [name], as written text.
String _extensionConfig(String pbxproj, String name) {
  final id = xcodeObjectId('cfg:$name:GreetingHomeWidget');
  final match = RegExp(
    '$id /\\* ${RegExp.escape(name)} \\*/ = \\{[\\s\\S]*?\\n\\t\\t\\};',
  ).firstMatch(pbxproj);
  expect(
    match,
    isNotNull,
    reason: 'no extension build configuration named "$name"',
  );
  return match!.group(0)!;
}

/// The `buildConfigurations` list of the extension's `XCConfigurationList`.
String _extensionConfigList(String pbxproj) {
  final id = xcodeObjectId('cfglist:GreetingHomeWidget');
  return RegExp(
    '$id /\\* [^*]*? \\*/ = \\{[\\s\\S]*?'
    'buildConfigurations = \\(([\\s\\S]*?)\\);',
  ).firstMatch(pbxproj)!.group(1)!;
}

/// A project whose flavored Runner configurations hold nothing themselves and
/// point at `Flutter/Debug-dev.xcconfig` instead, the setup Flutter's own
/// flavor documentation describes.
///
/// The file reference sits in the `Flutter` group, which carries a name but no
/// path, so its own `path` is what the project resolves against `ios/`.
String _xcconfigFlavoredPbxproj() {
  const fileRefId = 'DD0000000000000000000001';
  final configObjects = <String>[];
  final configListEntries = <String>[];

  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = _baseConfigNames[rank];
    final id = '97C1470${rank}1CF9000F007C117D';
    configObjects.add(
      _runnerConfigObject(id: id, name: name, bundleId: 'com.example.app'),
    );
    configListEntries.add('\t\t\t\t$id /* $name */,');
  }
  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = '${_baseConfigNames[rank]}-dev';
    final id = _flavorConfigId('AA', rank + 1);
    configObjects.add('''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = $fileRefId /* Debug-dev.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''');
    configListEntries.add('\t\t\t\t$id /* $name */,');
  }

  return '''
// !\$*UTF8*\$!
{
\tarchiveVersion = 1;
\tobjectVersion = 54;
\tobjects = {

/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t$fileRefId /* Debug-dev.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Debug-dev.xcconfig"; path = "Flutter/Debug-dev.xcconfig"; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t97C146E51CF9000F007C117D = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,
\t\t\t\t97C146EF1CF9000F007C117D /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t9740EEB11CF90186004384FC /* Flutter */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t$fileRefId /* Debug-dev.xcconfig */,
\t\t\t);
\t\t\tname = Flutter;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t97C146EF1CF9000F007C117D /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t97C146ED1CF9000F007C117D /* Runner */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;
\t\t\tbuildPhases = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Runner;
\t\t\tproductName = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t97C146E61CF9000F007C117D /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tbuildConfigurationList = 97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */;
\t\t\tmainGroup = 97C146E51CF9000F007C117D;
\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;
\t\t\ttargets = (
\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
${configObjects.join('\n')}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
${configListEntries.join('\n')}
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
}

/// The build configuration object with [id], as written text.
String _configObjectWithId(String pbxproj, String id) => RegExp(
      '$id /\\* [^*\\n]*? \\*/ = \\{[\\s\\S]*?\\n\\t\\t\\};',
    ).firstMatch(pbxproj)!.group(0)!;

/// Rewrites the extension's `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, standing in
/// for a developer who edited the configuration in Xcode.
String _withCompilationConditions(
  String pbxproj,
  String configName,
  String lines,
) {
  final block = _extensionConfig(pbxproj, configName);
  final existing = RegExp(
    r'\n\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = (?:[^;\n]*;|\([\s\S]*?\n\t\t\t\t\);)',
  );
  final patched = existing.hasMatch(block)
      ? block.replaceFirst(existing, '\n$lines')
      : block.replaceFirst(
          '\n\t\t\t\tSWIFT_VERSION = 5.0;',
          '\n$lines\n\t\t\t\tSWIFT_VERSION = 5.0;',
        );
  return pbxproj.replaceFirst(block, patched);
}

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

  group('flavors', () {
    Future<String> patch({
      Map<String, String> flavorEntitlements = const {},
    }) async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
        flavorEntitlements: flavorEntitlements,
      );
      return pbxprojFile.readAsStringSync();
    }

    test('detectXcodeFlavors lists the flavors in first-seen order', () {
      expect(
        detectXcodeFlavors(_buildFlavoredPbxproj()),
        ['dev', 'prod'],
      );
    });

    test('detectXcodeFlavors is empty without flavored configurations', () {
      expect(
        detectXcodeFlavors(_buildPbxproj(deploymentTarget: '14.0')),
        isEmpty,
      );
      expect(detectXcodeFlavors(_buildFlavoredPbxproj(flavors: [])), isEmpty);
    });

    test('runnerEntitlementsPathsForFlavor reads the per-flavor file', () {
      final pbxproj = _buildFlavoredPbxproj();

      // All three of dev's configurations name the same file.
      expect(
        runnerEntitlementsPathsForFlavor(pbxproj, 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );
      // prod and the base configurations do not set it at all.
      expect(runnerEntitlementsPathsForFlavor(pbxproj, 'prod'), isEmpty);
      expect(runnerEntitlementsPathsForFlavor(pbxproj, null), isEmpty);
      expect(runnerEntitlementsPathsForFlavor(pbxproj, 'missing'), isEmpty);
    });

    test('lists every file a flavor signs with, in configuration order', () {
      final pbxproj = _buildFlavoredPbxproj(flavors: const [_splitDev]);

      // Release and Profile share one file, so it is listed once.
      expect(runnerEntitlementsPathsForFlavor(pbxproj, 'dev'), [
        'Runner/RunnerDevDebug.entitlements',
        'Runner/RunnerDevRelease.entitlements',
      ]);
      expect(runnerEntitlementsSettingsForFlavor(pbxproj, 'dev'), [
        'Runner/RunnerDevDebug.entitlements',
        'Runner/RunnerDevRelease.entitlements',
      ]);
    });

    test('leaves out the configurations that name no file', () {
      final pbxproj = _buildFlavoredPbxproj(flavors: const [_releaseOnlyDev]);

      expect(
        runnerEntitlementsPathsForFlavor(pbxproj, 'dev'),
        ['Runner/RunnerDevRelease.entitlements'],
      );
    });

    test('lists the file the unflavored trio shares once', () {
      final pbxproj = _buildFlavoredPbxproj(
        flavors: const [],
        baseEntitlements: 'Runner/Runner.entitlements',
      );

      expect(
        runnerEntitlementsPathsForFlavor(pbxproj, null),
        ['Runner/Runner.entitlements'],
      );
    });

    test('mirrors every Runner configuration onto the extension', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      final list = _extensionConfigList(result);
      for (final name in [
        'Debug',
        'Release',
        'Profile',
        'Debug-dev',
        'Release-dev',
        'Profile-dev',
        'Debug-prod',
        'Release-prod',
        'Profile-prod',
      ]) {
        expect(list, contains('/* $name */'));
        expect(
          _extensionConfig(result, name),
          contains('DEVELOPMENT_TEAM = TEAM123;'),
        );
      }
      // The extension still defaults to Release, like Runner does.
      expect(result, contains('defaultConfigurationName = Release;'));
      // Xcode sorts the build settings, DEVELOPMENT_TEAM included.
      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
          '\t\t\t\tDEVELOPMENT_TEAM = TEAM123;\n'
          '\t\t\t\tGENERATE_INFOPLIST_FILE = YES;',
        ),
      );
    });

    test('spells a flavored configuration name the way Xcode does', () async {
      final fixture = _buildFlavoredPbxproj();
      // Xcode quotes the value but never the object comment.
      expect(fixture, contains('name = "Debug-dev";'));
      expect(fixture, contains('/* Debug-dev */'));
      pbxprojFile.writeAsStringSync(fixture);

      final result = await patch();

      expect(detectXcodeFlavors(result), ['dev', 'prod']);
      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains('/* Debug-dev */'),
      );
      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains('name = "Debug-dev";'),
      );
      expect(_extensionConfig(result, 'Debug'), contains('name = Debug;'));
      expect(result, isNot(contains('"Debug-dev" */')));
      expect(_extensionConfigList(result), contains('/* Debug-dev */'));
    });

    test('inherits the settings a flavor keeps at project level', () async {
      final fixture = _buildFlavoredPbxproj(flavorSettingsInProject: true);
      pbxprojFile.writeAsStringSync(fixture);

      expect(detectXcodeFlavors(fixture), ['dev', 'prod']);
      expect(
        runnerEntitlementsPathsForFlavor(fixture, 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'com.example.app.dev.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains('DEVELOPMENT_TEAM = TEAM123;'),
      );
    });

    test('reuses a configuration the project already names', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
      final first = await patch();

      // Xcode – or an earlier version of this patcher – gives the configuration
      // an id of its own and may spell its comment differently.
      const foreignId = 'AB0000000000000000000001';
      final foreign = first
          .replaceAll(
            xcodeObjectId('cfg:Debug-dev:GreetingHomeWidget'),
            foreignId,
          )
          .replaceAll(
            '$foreignId /* Debug-dev */',
            '$foreignId /* "Debug-dev" */',
          );
      pbxprojFile.writeAsStringSync(foreign);

      final result = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      // Runner's configuration and the extension's, and no duplicate of either.
      expect('name = "Debug-dev";'.allMatches(result).length, 2);
      expect(result, contains('$foreignId /* Debug-dev */'));
      expect(result, isNot(contains('"Debug-dev" */')));
      expect(
        result,
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
        ),
      );
    });

    test('gives each configuration its own Runner bundle id', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(result, 'Release-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'com.example.app.dev.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(result, 'Profile-prod'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.GreetingHomeWidget;',
        ),
      );
    });

    test('sets a compilation condition on flavored configurations only',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) HW_FLAVOR_DEV";',
        ),
      );
      expect(
        _extensionConfig(result, 'Profile-prod'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) HW_FLAVOR_PROD";',
        ),
      );
      expect(
        _extensionConfig(result, 'Release'),
        isNot(contains('SWIFT_ACTIVE_COMPILATION_CONDITIONS')),
      );
    });

    test('uses the entitlements file mapped to each flavor', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
        ),
      );
      // An unmapped flavor and the base configurations share the default file.
      expect(
        _extensionConfig(result, 'Debug-prod'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
      expect(
        _extensionConfig(result, 'Debug'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
    });

    test('is idempotent', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final first = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );
      final second = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      expect(second, first);
    });

    test('adds a configuration for a flavor introduced later', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final before = await patch();
      expect(
        () => _extensionConfig(before, 'Debug-stg'),
        throwsA(anything),
      );

      pbxprojFile.writeAsStringSync(_addRunnerFlavor(before, _stg));
      final after = await patch();

      expect(
        _extensionConfig(after, 'Release-stg'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'com.example.app.stg.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(after, 'Release-stg'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) HW_FLAVOR_STG";',
        ),
      );
      expect(_extensionConfigList(after), contains('/* Profile-stg */'));
      // The configurations that were already there are untouched.
      expect(
        _extensionConfig(after, 'Debug-dev'),
        _extensionConfig(before, 'Debug-dev'),
      );
    });

    test('updates an existing configuration to the desired values', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
      final first = await patch();

      final second = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      expect(
        _extensionConfig(first, 'Debug-dev'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
      expect(
        _extensionConfig(second, 'Debug-dev'),
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
        ),
      );
    });

    test('keeps a per-flavor Runner entitlements path', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
      final result = pbxprojFile.readAsStringSync();

      expect(
        runnerEntitlementsPathsForFlavor(result, 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );
      // Configurations without one get the default.
      expect(
        runnerEntitlementsPathsForFlavor(result, null),
        ['Runner/Runner.entitlements'],
      );
      expect(
        runnerEntitlementsPathsForFlavor(result, 'prod'),
        ['Runner/Runner.entitlements'],
      );
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements;'
            .allMatches(result)
            .length,
        3,
      );
    });

    test('sets CODE_SIGN_ENTITLEMENTS on a bare flavored configuration',
        () async {
      // Nothing but the Runner target's configuration list says that these
      // belong to Runner: the target configuration holds only PRODUCT_NAME and
      // the project-level one carries no Info.plist marker either.
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(
          flavors: const [_prod],
          flavorSettingsInProject: true,
          infoPlistInProjectSettings: false,
        ),
      );

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
      final result = pbxprojFile.readAsStringSync();

      for (var rank = 0; rank < _baseConfigNames.length; rank++) {
        expect(
          _configObjectWithId(result, _flavorConfigId('BB', rank + 1)),
          contains(
            'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
          ),
        );
      }
    });

    test('quotes a bundle id the way Xcode does', () async {
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(flavors: const [_quotedDev]),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = "com.example.app-dev.GreetingHomeWidget";',
        ),
      );
      // The quotes belong to the value, not to what was read out of the
      // project: a doubly quoted one would not parse.
      expect(result, isNot(contains('""com.example')));
    });

    test('resolves an entitlements path written with build variables', () {
      final pbxproj = _buildFlavoredPbxproj(flavors: const [_quotedDev]);

      expect(
        runnerEntitlementsPathsForFlavor(pbxproj, 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );
      expect(
        runnerEntitlementsSettingsForFlavor(pbxproj, 'dev'),
        [r'$(SRCROOT)/Runner/RunnerDev.entitlements'],
      );
    });

    test('has no path for an entitlements file only Xcode can locate', () {
      final pbxproj = _buildFlavoredPbxproj(flavors: const [_customPathDev]);

      expect(runnerEntitlementsPathsForFlavor(pbxproj, 'dev'), isEmpty);
      expect(
        runnerEntitlementsSettingsForFlavor(pbxproj, 'dev'),
        [r'$(CUSTOM)/RunnerDev.entitlements'],
      );
    });
  });

  group('xcconfig', () {
    late Directory iosDir;
    late File xcconfig;

    setUp(() {
      iosDir = Directory('${tempDir.path}/ios')..createSync();
      Directory('${iosDir.path}/Runner.xcodeproj').createSync();
      Directory('${iosDir.path}/Flutter').createSync();
      pbxprojFile = File('${iosDir.path}/Runner.xcodeproj/project.pbxproj')
        ..writeAsStringSync(_xcconfigFlavoredPbxproj());
      xcconfig = File('${iosDir.path}/Flutter/Debug-dev.xcconfig');
    });

    test('reads the bundle id a flavor keeps in its xcconfig', () async {
      // Generated.xcconfig only exists after the first build; Xcode reads the
      // project without it and so must this.
      xcconfig.writeAsStringSync(
        '#include "Generated.xcconfig"\n'
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev // the flavor\n',
      );

      expect(detectXcodeFlavors(pbxprojFile.readAsStringSync()), ['dev']);

      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      final result = pbxprojFile.readAsStringSync();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev.GreetingHomeWidget;',
        ),
      );
      // Without the xcconfig the flavor would silently take the unflavored
      // bundle id, which iOS rejects for an extension of the flavored app.
      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.GreetingHomeWidget;',
        ),
      );
    });

    test('reads the entitlements a flavor keeps in its xcconfig', () {
      xcconfig.writeAsStringSync(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements\n',
      );

      expect(
        runnerEntitlementsPathsForFlavor(
          pbxprojFile.readAsStringSync(),
          'dev',
          projectDir: iosDir,
        ),
        ['Runner/RunnerDev.entitlements'],
      );
    });

    test('resolves a bundle id assembled from other settings', () {
      xcconfig.writeAsStringSync(
        'APP_ID = com.example.app\n'
        r'PRODUCT_BUNDLE_IDENTIFIER = $(APP_ID).dev'
        '\n',
      );

      expect(
        runnerEntitlementsPathsForFlavor(
          pbxprojFile.readAsStringSync(),
          'dev',
          projectDir: iosDir,
        ),
        isEmpty,
      );
    });

    test('sees nothing without a project directory', () {
      xcconfig.writeAsStringSync(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements\n',
      );

      expect(
        runnerEntitlementsPathsForFlavor(pbxprojFile.readAsStringSync(), 'dev'),
        isEmpty,
      );
    });
  });

  group('compilation conditions', () {
    Future<String> patch() async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      return pbxprojFile.readAsStringSync();
    }

    setUp(() {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
    });

    test('keeps the flags a developer added to a flavored configuration',
        () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Debug-dev',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
              '"\$(inherited) MY_FLAG";',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) MY_FLAG HW_FLAVOR_DEV";',
        ),
      );
    });

    test('reads the list form Xcode writes without duplicating the key',
        () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Debug-dev',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = (\n'
              '\t\t\t\t\t"\$(inherited)",\n'
              '\t\t\t\t\tMY_FLAG,\n'
              '\t\t\t\t);',
        ),
      );

      final result = await patch();
      final config = _extensionConfig(result, 'Debug-dev');

      expect(
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS'.allMatches(config).length,
        1,
      );
      expect(
        config,
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) MY_FLAG HW_FLAVOR_DEV";',
        ),
      );
    });

    test('drops a stale flavor condition and keeps the rest', () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Release',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
              '"\$(inherited) MY_FLAG HW_FLAVOR_OLD";',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Release'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "\$(inherited) MY_FLAG";',
        ),
      );
    });

    test('removes a setting that held nothing but a flavor condition',
        () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Release',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
              '"\$(inherited) HW_FLAVOR_OLD";',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Release'),
        isNot(contains('SWIFT_ACTIVE_COMPILATION_CONDITIONS')),
      );
    });

    test('changes nothing on a second run', () async {
      final first = await patch();
      final second = await patch();

      expect(second, first);
    });
  });

  group('reporting', () {
    MockLogger useMockLogger() {
      final saved = logger;
      final mock = MockLogger();
      when(() => mock.detail(any())).thenReturn(null);
      when(() => mock.info(any())).thenReturn(null);
      when(() => mock.warn(any())).thenReturn(null);
      logger = mock;
      addTearDown(() => logger = saved);
      return mock;
    }

    Future<String> patch({Map<String, String> flavorEntitlements = const {}}) =>
        ensureWidgetExtensionTargetInXcodeProject(
          pbxprojFile: pbxprojFile,
          widgetClassName: 'GreetingHomeWidget',
          flavorEntitlements: flavorEntitlements,
        ).then((_) => pbxprojFile.readAsStringSync());

    test('says which settings a sync reset on an existing configuration',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      await patch();
      final mock = useMockLogger();

      await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      verify(
        () => mock.info(
          any(
            that: allOf(
              contains('CODE_SIGN_ENTITLEMENTS'),
              contains('"Debug-dev"'),
            ),
          ),
        ),
      ).called(1);
    });

    test('stays quiet when a re-run changes nothing', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      await patch();
      final mock = useMockLogger();

      await patch();

      verifyNever(() => mock.info(any()));
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
