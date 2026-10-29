import 'dart:io';

import 'package:home_widget_cli/src/util/fnv_hash.dart';
import 'package:home_widget_cli/src/util/pbxproj/pbxproj_editor.dart';
import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/xcode_project.dart';

const _widget = 'CounterHomeWidget';
const _intent = 'CounterHomeWidgetIntent.swift';
const _product = 'FlutterGeneratedPluginSwiftPackage';
const _podsXcconfig = 'HomeWidget-CounterHomeWidget.xcconfig';

const _runnerTargetId = '97C146ED1CF9000F007C117D';
const _runnerSourcesId = '97C146EA1CF9000F007C117D';
const _mainGroupId = '97C146E51CF9000F007C117D';
const _runnerProductId = '78A3181F2AECB46A00862997';
const _flutterGroupId = '9740EEB11CF90186004384FC';

const _dev = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
);

final _targetId = xcodeObjectId('target:$_widget');
final _widgetGroupId = xcodeObjectId('group:$_widget');
final _rootGroupId = xcodeObjectId('fsgroup:$_widget');
final _sourcesId = xcodeObjectId('phase:sources:$_widget');
final _frameworksId = xcodeObjectId('phase:frameworks:$_widget');
final _versionXcconfigId = xcodeObjectId('fileref:HomeWidget.xcconfig');

final _intentFileRefId = xcodeObjectId('fileref:$_intent:$_widget');
final _intentBuildFileId = xcodeObjectId('buildfile:$_intent:$_widget');
final _runnerIntentBuildFileId =
    xcodeObjectId('buildfile:app:$_intent:$_widget');
final _runnerExceptionId = xcodeObjectId('fsex:app:$_widget');
final _packageProductId = xcodeObjectId('package:plugins:$_widget');
final _packageBuildFileId = xcodeObjectId('buildfile:package:plugins:$_widget');
final _podsXcconfigId = xcodeObjectId('fileref:pods-xcconfig:$_widget');

final _interactivityIds = [
  _intentFileRefId,
  _intentBuildFileId,
  _runnerIntentBuildFileId,
  _runnerExceptionId,
  _packageProductId,
  _packageBuildFileId,
  _podsXcconfigId,
];

/// [pbxproj] with the Runner target linking the Swift package Flutter
/// generates for the app's plugins.
String _withRunnerPackage(String pbxproj) => (PbxprojEditor(pbxproj)
      ..insertObjects('XCSwiftPackageProductDependency', '''
\t\t$_runnerProductId /* $_product */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tproductName = $_product;
\t\t};
''')
      ..addArrayEntry(
        _runnerTargetId,
        'packageProductDependencies',
        _runnerProductId,
        comment: _product,
      ))
    .text;

/// [pbxproj] with the two sections Xcode 16 writes, which has the scaffolder
/// give the extension a synchronized root group.
String _withSynchronizedGroups(String pbxproj) => pbxproj.replaceFirst(
      '/* End PBXFileReference section */\n',
      '''
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
/* End PBXFileSystemSynchronizedRootGroup section */
''',
    );

/// [pbxproj] with the `Flutter` group of a `flutter create` project.
String _withFlutterGroup(String pbxproj) => (PbxprojEditor(pbxproj)
      ..insertObjects('PBXGroup', '''
\t\t$_flutterGroupId /* Flutter */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tpath = Flutter;
\t\t\tsourceTree = "<group>";
\t\t};
''')
      ..addArrayEntry(
        _mainGroupId,
        'children',
        _flutterGroupId,
        comment: 'Flutter',
      ))
    .text;

String _withoutObject(String pbxproj, String id) =>
    (PbxprojEditor(pbxproj)..removeObjects({id})).text;

/// The lines only [actual] has, marked `+`, and the ones only [expected] has,
/// marked `-`.
List<String> _lineDifference(String actual, String expected) {
  final missing = expected.split('\n');
  final added = <String>[];
  for (final line in actual.split('\n')) {
    if (!missing.remove(line)) added.add('+ $line');
  }
  return [...added, for (final line in missing) '- $line'];
}

/// What is left of the product list the extension target got.
const _emptiedProductList = [
  '+ \t\t\tpackageProductDependencies = (',
  '+ \t\t\t);',
];

void main() {
  late Directory tempDir;
  late Directory iosDir;
  late File pbxprojFile;
  late File podsXcconfig;
  late MockLogger mockLogger;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pbxproj_interactivity_test');
    iosDir = Directory(p.join(tempDir.path, 'ios'));
    pbxprojFile = File(
      p.join(iosDir.path, 'Runner.xcodeproj', 'project.pbxproj'),
    )..parent.createSync(recursive: true);
    podsXcconfig = File(p.join(iosDir.path, 'Flutter', _podsXcconfig));
    mockLogger = useMockLogger();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String read() => pbxprojFile.readAsStringSync();

  Pbxproj project() => Pbxproj.parse(read());

  Future<String> scaffold(String pbxproj) async {
    pbxprojFile.writeAsStringSync(pbxproj);
    await ensureWidgetExtensionTargetInXcodeProject(
      pbxprojFile: pbxprojFile,
      widgetClassName: _widget,
    );
    return read();
  }

  Future<WidgetPluginLinkage> sync({
    bool interactive = true,
    bool hasPodfile = false,
    bool? pluginInSwiftPackage,
  }) =>
      syncWidgetInteractivityInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: _widget,
        intentFileName: _intent,
        interactive: interactive,
        hasPodfile: hasPodfile,
        pluginInSwiftPackage: pluginInSwiftPackage,
      );

  int definitions(String id) =>
      RegExp('^\t\t$id /\\*.*\\*/ = \\{', multiLine: true)
          .allMatches(read())
          .length;

  Map<String, String?> baseConfigurations() {
    final pbxproj = project();
    return {
      for (final config
          in pbxproj.buildConfigurationsOf(pbxproj.object(_targetId)!))
        config.string('name')!: config.string('baseConfigurationReference'),
    };
  }

  void expectIntentWiredExplicitly() {
    final pbxproj = project();
    final fileRef = pbxproj.object(_intentFileRefId)!;
    expect(fileRef.string('isa'), 'PBXFileReference');
    expect(fileRef.string('path'), _intent);
    expect(fileRef.string('lastKnownFileType'), 'sourcecode.swift');
    expect(
      pbxproj.object(_widgetGroupId)!.strings('children'),
      contains(_intentFileRefId),
    );
    for (final (buildFileId, phaseId) in [
      (_intentBuildFileId, _sourcesId),
      (_runnerIntentBuildFileId, _runnerSourcesId),
    ]) {
      final buildFile = pbxproj.object(buildFileId)!;
      expect(buildFile.string('isa'), 'PBXBuildFile');
      expect(buildFile.string('fileRef'), _intentFileRefId);
      expect(pbxproj.object(phaseId)!.strings('files'), contains(buildFileId));
      expect(definitions(buildFileId), 1);
    }
    expect(definitions(_intentFileRefId), 1);
  }

  void expectPackageLinked() {
    final pbxproj = project();
    final product = pbxproj.object(_packageProductId)!;
    expect(product.string('isa'), 'XCSwiftPackageProductDependency');
    expect(product.string('productName'), _product);
    final buildFile = pbxproj.object(_packageBuildFileId)!;
    expect(buildFile.string('isa'), 'PBXBuildFile');
    expect(buildFile.string('productRef'), _packageProductId);
    expect(
      pbxproj.object(_frameworksId)!.strings('files'),
      contains(_packageBuildFileId),
    );
    expect(
      pbxproj.object(_targetId)!.strings('packageProductDependencies'),
      [_packageProductId],
    );
    expect(definitions(_packageProductId), 1);
    expect(definitions(_packageBuildFileId), 1);
  }

  void expectNothingOf(List<String> ids) {
    final pbxproj = read();
    for (final id in ids) {
      expect(pbxproj, isNot(contains(id)));
    }
  }

  void expectRestored(String expected) {
    expect(_lineDifference(read(), expected), isEmpty);
    expect(read(), expected);
  }

  group('explicit groups in a project linking the plugin package', () {
    setUp(() async {
      await scaffold(_withRunnerPackage(flavoredPbxproj(const [])));
    });

    test('makes the intent a member of both targets and links the package',
        () async {
      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expectIntentWiredExplicitly();
      expectPackageLinked();
      expectNothingOf([_runnerExceptionId, _podsXcconfigId]);
      expect(podsXcconfig.existsSync(), isFalse);
      verify(
        () => mockLogger.detail(
          'Wired the interaction intent of $_widget into Runner and $_widget.',
        ),
      ).called(1);
    });

    test('ignores a Podfile', () async {
      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expectPackageLinked();
      expectNothingOf([_podsXcconfigId]);
      expect(podsXcconfig.existsSync(), isFalse);
    });

    test('is idempotent', () async {
      await sync();
      final first = read();

      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expect(read(), first);
    });

    test('adds no second product to an extension linking it by hand', () async {
      const handProductId = 'AB00000000000000000000EE';
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(read())
              ..insertObjects('XCSwiftPackageProductDependency', '''
\t\t$handProductId /* $_product */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tproductName = $_product;
\t\t};
''')
              ..addArrayEntry(
                _targetId,
                'packageProductDependencies',
                handProductId,
                comment: _product,
              ))
            .text,
      );

      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expectIntentWiredExplicitly();
      expectNothingOf([_packageProductId, _packageBuildFileId]);
      expect(
        project().object(_targetId)!.strings('packageProductDependencies'),
        [handProductId],
      );
    });

    test('links nothing into an extension without a Frameworks phase',
        () async {
      pbxprojFile.writeAsStringSync(_withoutObject(read(), _frameworksId));

      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expectIntentWiredExplicitly();
      expectNothingOf([_packageProductId, _packageBuildFileId]);
    });

    test('restores the project when the last button goes', () async {
      final before = read();
      await sync();
      expect(read(), isNot(before));

      final linkage = await sync(interactive: false);

      expect(linkage, WidgetPluginLinkage.none);
      expectNothingOf(_interactivityIds);
      expect(_lineDifference(read(), before), _emptiedProductList);
      verify(
        () => mockLogger.detail('Removed the interaction wiring of $_widget.'),
      ).called(1);
    });

    test('links the package when it is known to hold the plugin', () async {
      final linkage = await sync(hasPodfile: true, pluginInSwiftPackage: true);

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expectIntentWiredExplicitly();
      expectPackageLinked();
      expectNothingOf([_podsXcconfigId]);
      expect(podsXcconfig.existsSync(), isFalse);
    });

    test('goes through CocoaPods when the package does not hold the plugin',
        () async {
      final linkage = await sync(hasPodfile: true, pluginInSwiftPackage: false);

      expect(linkage, WidgetPluginLinkage.cocoaPods);
      expectIntentWiredExplicitly();
      expectNothingOf([_packageProductId, _packageBuildFileId]);
      expect(baseConfigurations(), {
        'Debug': _podsXcconfigId,
        'Release': _podsXcconfigId,
        'Profile': _podsXcconfigId,
      });
      expect(
        project().object(_mainGroupId)!.strings('children'),
        contains(_podsXcconfigId),
      );
      expect(podsXcconfig.readAsStringSync(), '''
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.debug.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.release.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.profile.xcconfig"
#include "HomeWidget.xcconfig"
''');
    });

    test(
        'links nothing when the package does not hold the plugin and there '
        'is no Podfile', () async {
      final linkage = await sync(pluginInSwiftPackage: false);

      expect(linkage, WidgetPluginLinkage.none);
      expectIntentWiredExplicitly();
      expectNothingOf([
        _packageProductId,
        _packageBuildFileId,
        _podsXcconfigId,
      ]);
      expect(podsXcconfig.existsSync(), isFalse);
    });

    test('unlinks the package once it no longer holds the plugin', () async {
      await sync(hasPodfile: true);
      expectPackageLinked();

      final linkage = await sync(hasPodfile: true, pluginInSwiftPackage: false);

      expect(linkage, WidgetPluginLinkage.cocoaPods);
      expectNothingOf([_packageProductId, _packageBuildFileId]);
      expect(podsXcconfig.existsSync(), isTrue);
    });
  });

  group('synchronized groups', () {
    late String scaffolded;

    setUp(() async {
      scaffolded = await scaffold(
        _withSynchronizedGroups(_withRunnerPackage(flavoredPbxproj(const []))),
      );
    });

    test('excepts the intent into the app target', () async {
      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      final pbxproj = project();
      final exception = pbxproj.object(_runnerExceptionId)!;
      expect(
        exception.string('isa'),
        'PBXFileSystemSynchronizedBuildFileExceptionSet',
      );
      expect(exception.strings('membershipExceptions'), [_intent]);
      expect(exception.string('target'), _runnerTargetId);
      expect(
        pbxproj.object(_rootGroupId)!.strings('exceptions'),
        contains(_runnerExceptionId),
      );
      expect(
        read(),
        contains(
          '$_runnerExceptionId /* Exceptions for "$_widget" folder in '
          '"Runner" target */ = {',
        ),
      );
      expectNothingOf([
        _intentFileRefId,
        _intentBuildFileId,
        _runnerIntentBuildFileId,
      ]);
      expect(read(), isNot(contains('path = $_intent;')));
      expectPackageLinked();
    });

    test('is idempotent', () async {
      await sync();
      final first = read();

      await sync();

      expect(read(), first);
    });

    test('restores the project when the last button goes', () async {
      await sync();

      final linkage = await sync(interactive: false);

      expect(linkage, WidgetPluginLinkage.none);
      expectNothingOf(_interactivityIds);
      expect(_lineDifference(read(), scaffolded), _emptiedProductList);
    });
  });

  group('CocoaPods', () {
    final configurationNames = [
      'Debug',
      'Release',
      'Profile',
      'Debug-dev',
      'Release-dev',
      'Profile-dev',
    ];
    const content = '''
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.debug.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.release.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.profile.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.debug-dev.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.release-dev.xcconfig"
#include? "Pods/Target Support Files/Pods-CounterHomeWidget/Pods-CounterHomeWidget.profile-dev.xcconfig"
#include "HomeWidget.xcconfig"
''';

    late String scaffolded;

    setUp(() async {
      scaffolded = await scaffold(flavoredPbxproj(const [_dev]));
    });

    test('names the xcconfig the configurations are based on', () {
      expect(podsXcconfigPath(_widget), 'Flutter/$_podsXcconfig');
    });

    test('bases every configuration on an xcconfig including the pods',
        () async {
      expect(
        baseConfigurations(),
        {for (final name in configurationNames) name: _versionXcconfigId},
      );

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.cocoaPods);
      expect(podsXcconfig.readAsStringSync(), content);
      expect(
        baseConfigurations(),
        {for (final name in configurationNames) name: _podsXcconfigId},
      );
      expect(
        read(),
        contains(
          'baseConfigurationReference = $_podsXcconfigId '
          '/* $_podsXcconfig */;',
        ),
      );
      expectIntentWiredExplicitly();
      expectNothingOf([_packageProductId, _packageBuildFileId]);
      verify(
        () => mockLogger.detail('Generated: ${podsXcconfig.path}'),
      ).called(1);
    });

    test('references the xcconfig from the main group without a Flutter group',
        () async {
      await sync(hasPodfile: true);

      final pbxproj = project();
      expect(
        read(),
        contains(
          '\t\t$_podsXcconfigId /* $_podsXcconfig */ = {isa = '
          'PBXFileReference; lastKnownFileType = text.xcconfig; name = '
          '"$_podsXcconfig"; path = "Flutter/$_podsXcconfig"; sourceTree = '
          '"<group>"; };\n',
        ),
      );
      expect(
        pbxproj.object(_mainGroupId)!.strings('children'),
        contains(_podsXcconfigId),
      );
      expect(definitions(_podsXcconfigId), 1);
    });

    test('references the xcconfig from the Flutter group', () async {
      await scaffold(_withFlutterGroup(flavoredPbxproj(const [_dev])));

      await sync(hasPodfile: true);

      final pbxproj = project();
      expect(
        read(),
        contains(
          '\t\t$_podsXcconfigId /* $_podsXcconfig */ = {isa = '
          'PBXFileReference; lastKnownFileType = text.xcconfig; path = '
          '"$_podsXcconfig"; sourceTree = "<group>"; };\n',
        ),
      );
      expect(
        pbxproj.object(_flutterGroupId)!.strings('children'),
        containsAll([_versionXcconfigId, _podsXcconfigId]),
      );
      expect(
        pbxproj.object(_mainGroupId)!.strings('children'),
        isNot(contains(_podsXcconfigId)),
      );
    });

    test('keeps a foreign base xcconfig and gives a missing base one',
        () async {
      const foreignId = 'AB00000000000000000000CC';
      final pbxproj = project();
      final configs = {
        for (final config
            in pbxproj.buildConfigurationsOf(pbxproj.object(_targetId)!))
          config.string('name')!: config.id,
      };
      final edited = (PbxprojEditor(read())
            ..insertObjects('PBXFileReference', '''
\t\t$foreignId /* Widget.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Flutter/Widget.xcconfig; sourceTree = "<group>"; };
''')
            ..addArrayEntry(
              _mainGroupId,
              'children',
              foreignId,
              comment: 'Widget.xcconfig',
            )
            ..setReferenceField(
              configs['Debug']!,
              'baseConfigurationReference',
              foreignId,
              comment: 'Widget.xcconfig',
            ))
          .text;
      final release = RegExp(
        '\t\t${configs['Release']} /\\* Release \\*/ = \\{\n'
        '\t\t\tisa = XCBuildConfiguration;\n'
        '(\t\t\tbaseConfigurationReference = .*;\n)',
      ).firstMatch(edited)!;
      pbxprojFile.writeAsStringSync(
        edited.replaceRange(release.start, release.end, '''
\t\t${configs['Release']} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
'''),
      );
      expect(baseConfigurations()['Release'], isNull);

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.cocoaPods);
      expect(baseConfigurations(), {
        for (final name in configurationNames) name: _podsXcconfigId,
        'Debug': foreignId,
      });
      expect(podsXcconfig.readAsStringSync(), content);
    });

    test('is idempotent', () async {
      await sync(hasPodfile: true);
      final first = read();
      final written = podsXcconfig.lastModifiedSync();

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.cocoaPods);
      expect(read(), first);
      expect(podsXcconfig.readAsStringSync(), content);
      expect(podsXcconfig.lastModifiedSync(), written);
      verify(
        () => mockLogger.detail('Generated: ${podsXcconfig.path}'),
      ).called(1);
    });

    test('rewrites an xcconfig that names other configurations', () async {
      podsXcconfig
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('#include "HomeWidget.xcconfig"\n');

      await sync(hasPodfile: true);

      expect(podsXcconfig.readAsStringSync(), content);
    });

    test('survives a second run of the extension target patcher', () async {
      await sync(hasPodfile: true);
      final first = read();
      final mock = useMockLogger();

      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: _widget,
      );

      expect(read(), first);
      expect(
        baseConfigurations(),
        {for (final name in configurationNames) name: _podsXcconfigId},
      );
      verifyNever(() => mock.warn(any()));
    });

    test('restores the project when the last button goes', () async {
      await sync(hasPodfile: true);
      expect(podsXcconfig.existsSync(), isTrue);

      final linkage = await sync(interactive: false, hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.none);
      expectNothingOf(_interactivityIds);
      expect(
        baseConfigurations(),
        {for (final name in configurationNames) name: _versionXcconfigId},
      );
      expect(podsXcconfig.existsSync(), isFalse);
      expectRestored(scaffolded);
    });
  });

  group('a project integrating plugins neither way', () {
    late String scaffolded;

    setUp(() async {
      scaffolded = await scaffold(flavoredPbxproj(const []));
    });

    test('wires the intent and links nothing', () async {
      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.none);
      expectIntentWiredExplicitly();
      expectNothingOf([
        _packageProductId,
        _packageBuildFileId,
        _podsXcconfigId,
      ]);
      expect(read(), isNot(contains('XCSwiftPackageProductDependency')));
      expect(podsXcconfig.existsSync(), isFalse);
    });

    test('links nothing on the word of the package alone', () async {
      final linkage = await sync(pluginInSwiftPackage: true);

      expect(linkage, WidgetPluginLinkage.none);
      expectNothingOf([_packageProductId, _packageBuildFileId]);
    });

    test('changes nothing for a widget that never had a button', () async {
      final written = pbxprojFile.lastModifiedSync();

      final linkage = await sync(interactive: false, hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.none);
      expectRestored(scaffolded);
      expect(pbxprojFile.lastModifiedSync(), written);
      expect(podsXcconfig.existsSync(), isFalse);
    });

    test('restores the project when the last button goes', () async {
      await sync();

      await sync(interactive: false);

      expectRestored(scaffolded);
    });
  });

  group('a project changing how it integrates plugins', () {
    test('moves from CocoaPods to the plugin package', () async {
      await scaffold(flavoredPbxproj(const []));
      expect(await sync(hasPodfile: true), WidgetPluginLinkage.cocoaPods);
      expect(podsXcconfig.existsSync(), isTrue);
      pbxprojFile.writeAsStringSync(_withRunnerPackage(read()));

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.swiftPackage);
      expect(baseConfigurations(), {
        'Debug': _versionXcconfigId,
        'Release': _versionXcconfigId,
        'Profile': _versionXcconfigId,
      });
      expectNothingOf([_podsXcconfigId]);
      expect(podsXcconfig.existsSync(), isFalse);
      expectIntentWiredExplicitly();
      expectPackageLinked();
    });

    test('moves from the plugin package to CocoaPods', () async {
      await scaffold(_withRunnerPackage(flavoredPbxproj(const [])));
      expect(await sync(hasPodfile: true), WidgetPluginLinkage.swiftPackage);
      pbxprojFile.writeAsStringSync(_withoutObject(read(), _runnerProductId));

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.cocoaPods);
      expectNothingOf([_packageProductId, _packageBuildFileId]);
      expect(baseConfigurations(), {
        'Debug': _podsXcconfigId,
        'Release': _podsXcconfigId,
        'Profile': _podsXcconfigId,
      });
      expect(podsXcconfig.existsSync(), isTrue);
      expectIntentWiredExplicitly();
    });

    test('unlinks the plugin package once nothing integrates plugins',
        () async {
      await scaffold(_withRunnerPackage(flavoredPbxproj(const [])));
      await sync();
      pbxprojFile.writeAsStringSync(_withoutObject(read(), _runnerProductId));

      final linkage = await sync();

      expect(linkage, WidgetPluginLinkage.none);
      expectNothingOf([_packageProductId, _packageBuildFileId]);
      expectIntentWiredExplicitly();
    });
  });

  group('a project without one of the targets', () {
    test('changes nothing without the extension target', () async {
      final pbxproj = _withRunnerPackage(flavoredPbxproj(const []));
      pbxprojFile.writeAsStringSync(pbxproj);

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.none);
      expect(read(), pbxproj);
      expect(podsXcconfig.existsSync(), isFalse);
    });

    test('changes nothing without an app target', () async {
      final pbxproj =
          (await scaffold(_withRunnerPackage(flavoredPbxproj(const []))))
              .replaceFirst('\t\t\tname = Runner;\n', '\t\t\tname = App;\n')
              .replaceFirst(
                'productType = "com.apple.product-type.application";',
                'productType = "com.apple.product-type.framework";',
              );
      pbxprojFile.writeAsStringSync(pbxproj);

      final linkage = await sync(hasPodfile: true);

      expect(linkage, WidgetPluginLinkage.none);
      expect(read(), pbxproj);
      expect(podsXcconfig.existsSync(), isFalse);
    });
  });

  group('explicit groups the intent cannot be wired into', () {
    late String scaffolded;

    setUp(() async {
      scaffolded =
          await scaffold(_withRunnerPackage(flavoredPbxproj(const [])));
    });

    for (final (description, id) in [
      ('the group of the extension folder', _widgetGroupId),
      ('the Sources phase of the extension', _sourcesId),
      ('the Sources phase of the app', _runnerSourcesId),
    ]) {
      test('warns without $description', () async {
        pbxprojFile.writeAsStringSync(_withoutObject(scaffolded, id));

        final linkage = await sync();

        expect(linkage, WidgetPluginLinkage.swiftPackage);
        expectNothingOf([
          _intentFileRefId,
          _intentBuildFileId,
          _runnerIntentBuildFileId,
          _runnerExceptionId,
        ]);
        expectPackageLinked();
        verify(
          () => mockLogger.warn(
            any(
              that: allOf(
                contains(
                  '$_intent could not be wired into the Xcode project',
                ),
                contains('Add ios/$_widget/$_intent to both targets'),
                contains('in Runner and $_widget'),
              ),
            ),
          ),
        ).called(1);
      });
    }
  });
}
