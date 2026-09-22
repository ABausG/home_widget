import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/fnv_hash.dart';
import 'package:home_widget_cli/src/util/naming.dart';
import 'package:home_widget_cli/src/util/pbxproj/pbxproj_editor.dart';
import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/package_root.dart';

const _widget = 'GreetingHomeWidget';

/// A project layout the patcher has to handle, with what its Runner target
/// resolves to.
final class _Fixture {
  const _Fixture(
    this.file, {
    required this.description,
    required this.bundleIds,
    required this.teams,
    required this.runnerEntitlements,
  });

  final String file;
  final String description;

  /// The Runner bundle id by flavor, `null` for the unflavored configurations.
  final Map<String?, String> bundleIds;

  /// The Runner development team by flavor.
  final Map<String?, String> teams;

  /// The entitlements file the Runner configurations of each flavor sign with
  /// once the patcher ran.
  final Map<String?, String> runnerEntitlements;

  List<String> get flavors => [...bundleIds.keys.whereType<String>()];
}

const _layouts = [
  _Fixture(
    'spm_migrated.pbxproj',
    description: 'fields ahead of isa after the SwiftPM migration',
    bundleIds: {null: 'es.antonborri.exampleHomeWidget'},
    teams: {null: 'T3PND82A9W'},
    runnerEntitlements: {null: 'Runner/Runner.entitlements'},
  ),
  _Fixture(
    'no_dependency_sections.pbxproj',
    description: 'no PBXContainerItemProxy or PBXTargetDependency section',
    bundleIds: {null: 'com.example.freshApp'},
    teams: {null: 'T3PND82A9W'},
    runnerEntitlements: {null: 'Runner/Runner.entitlements'},
  ),
  _Fixture(
    'spm_migrated_flavor_next.pbxproj',
    description: 'a flavor whose configurations have non-hex ids',
    bundleIds: {
      null: 'es.antonborri.exampleHomeWidget',
      'next': 'es.antonborri.exampleHomeWidget.next',
    },
    teams: {null: 'T3PND82A9W', 'next': 'NEXT7EAM42'},
    runnerEntitlements: {
      null: 'Runner/Runner.entitlements',
      'next': 'Runner/RunnerNext.entitlements',
    },
  ),
  _Fixture(
    'non_canonical_field_order.pbxproj',
    description: 'build configurations with their fields in any order',
    bundleIds: {
      null: 'com.example.freshApp',
      'dev': 'com.example.freshApp.dev',
    },
    teams: {null: 'T3PND82A9W', 'dev': 'DEV7EAM123'},
    runnerEntitlements: {
      null: 'Runner/Runner.entitlements',
      'dev': 'Runner/RunnerDev.entitlements',
    },
  ),
];

/// The ids [pbxproj] references that no object defines, found with plain
/// pattern matching rather than the parser the patcher uses.
Set<String> _undefinedReferences(String pbxproj) {
  final defined = {
    for (final match in RegExp(
      r'^\t\t(\S+)(?: /\*.*?\*/)? = \{',
      multiLine: true,
    ).allMatches(pbxproj))
      match.group(1)!,
  };
  final withoutCommentsAndStrings = pbxproj
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
      .replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '""');
  final referenced = {
    for (final match in RegExp(r'(?<![A-Za-z0-9_])[0-9A-Z]{24}(?![A-Za-z0-9_])')
        .allMatches(withoutCommentsAndStrings))
      match.group(0)!,
  };
  return referenced.difference(defined);
}

/// The ids [pbxproj] defines more than once.
Set<String> _duplicateObjectIds(String pbxproj) {
  final seen = <String>{};
  return {
    for (final entry in Pbxproj.parse(pbxproj).objectsDict.entries)
      if (!seen.add(entry.key.value)) entry.key.value,
  };
}

String? _flavorOf(String configurationName) =>
    RegExp(r'^(?:Debug|Release|Profile)-(.+)$')
        .firstMatch(configurationName)
        ?.group(1);

/// The settings each configuration of [target] spells out, by name.
Map<String, Map<String, String>> _settingsByConfiguration(
  Pbxproj pbxproj,
  String target,
) =>
    {
      for (final config
          in pbxproj.buildConfigurationsOf(pbxproj.nativeTargetNamed(target)!))
        config.string('name')!: ownBuildSettings(config),
    };

void main() {
  late Directory fixtures;
  late Directory tempDir;
  late Directory iosDir;
  late File pbxprojFile;
  late MockLogger mockLogger;

  setUpAll(() async {
    fixtures = await pbxprojFixturesDirectory();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pbxproj_fixture_test');
    iosDir = Directory(p.join(tempDir.path, 'ios'))..createSync();
    pbxprojFile = File(
      p.join(iosDir.path, 'Runner.xcodeproj', 'project.pbxproj'),
    )..parent.createSync(recursive: true);
    mockLogger = useMockLogger();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String fixture(String name) =>
      File(p.join(fixtures.path, name)).readAsStringSync();

  void useFixture(String name) => pbxprojFile.writeAsStringSync(fixture(name));

  /// The patchers in the order `generate` runs them.
  Future<String> generate({
    String widgetClassName = _widget,
    List<String> flavors = const [],
  }) async {
    await ensureWidgetExtensionTargetInXcodeProject(
      pbxprojFile: pbxprojFile,
      widgetClassName: widgetClassName,
      flavorEntitlements: {
        for (final flavor in flavors)
          flavor: '$widgetClassName.$flavor.entitlements',
      },
    );
    await ensureMinimumDeploymentTargetInXcodeProject(pbxprojFile: pbxprojFile);
    await ensureLocalizableCatalogInXcodeProject(
      pbxprojFile: pbxprojFile,
      widgetClassName: widgetClassName,
      locales: const ['en', 'de', 'pt-BR'],
    );
    await ensureWidgetResourceFilesInXcodeProject(
      pbxprojFile: pbxprojFile,
      widgetClassName: widgetClassName,
      resourceFileNames: const ['hw_font_icons_materialicons.otf'],
    );
    return pbxprojFile.readAsStringSync();
  }

  for (final fixture in _layouts) {
    group('${fixture.file} (${fixture.description})', () {
      setUp(() => useFixture(fixture.file));

      test('detects the flavors the project defines', () {
        expect(
          detectXcodeFlavors(
            Pbxproj.parse(pbxprojFile.readAsStringSync()),
            projectDir: iosDir,
          ),
          fixture.flavors,
        );
      });

      test('adds the extension target and wires it into Runner', () async {
        final pbxproj = Pbxproj.parse(await generate(flavors: fixture.flavors));

        final extension = pbxproj.nativeTargetNamed(_widget);
        expect(extension, isNotNull);
        final runner = pbxproj.nativeTargetNamed('Runner')!;

        final dependencies = [
          for (final id in runner.strings('dependencies'))
            if (pbxproj.object(id)?.string('target') == extension!.id)
              pbxproj.object(id)!,
        ];
        expect(dependencies, hasLength(1));
        expect(dependencies.single.isa, 'PBXTargetDependency');
        final proxy = pbxproj.object(dependencies.single.string('targetProxy'));
        expect(proxy?.isa, 'PBXContainerItemProxy');
        expect(proxy!.string('remoteGlobalIDString'), extension!.id);
        expect(proxy.string('containerPortal'), pbxproj.rootProject!.id);

        final product = extension.string('productReference');
        final phases = [
          for (final id in runner.strings('buildPhases')) pbxproj.object(id)!,
        ];
        final embeds = phases.where(
          (phase) =>
              phase.isa == 'PBXCopyFilesBuildPhase' &&
              phase.strings('files').any(
                    (file) =>
                        pbxproj.object(file)?.string('fileRef') == product,
                  ),
        );
        expect(embeds, hasLength(1));
        expect(phases.last.string('name'), 'Thin Binary');
        final podsEmbed = phases.indexWhere(
          (phase) => phase.string('name') == '[CP] Embed Pods Frameworks',
        );
        if (podsEmbed != -1) {
          expect(phases.indexOf(embeds.single), lessThan(podsEmbed));
        }

        expect(pbxproj.rootProject!.strings('targets'), contains(extension.id));
      });

      test('references only objects the project defines', () async {
        expect(_undefinedReferences(pbxprojFile.readAsStringSync()), isEmpty);

        final result = await generate(flavors: fixture.flavors);

        expect(_undefinedReferences(result), isEmpty);
      });

      test('changes nothing on a second run', () async {
        final first = await generate(flavors: fixture.flavors);
        final second = await generate(flavors: fixture.flavors);

        expect(second, first);
      });

      test('mirrors every Runner configuration onto the extension', () async {
        final pbxproj = Pbxproj.parse(await generate(flavors: fixture.flavors));

        expect(
          detectXcodeFlavors(pbxproj, projectDir: iosDir),
          fixture.flavors,
        );
        final runnerNames = _settingsByConfiguration(pbxproj, 'Runner').keys;
        final extensionSettings = _settingsByConfiguration(pbxproj, _widget);
        expect(extensionSettings.keys, unorderedEquals(runnerNames));

        for (final MapEntry(key: name, value: settings)
            in extensionSettings.entries) {
          final flavor = _flavorOf(name);
          expect(
            settings['PRODUCT_BUNDLE_IDENTIFIER'],
            '${fixture.bundleIds[flavor]}.$_widget',
            reason: name,
          );
          expect(
            settings['DEVELOPMENT_TEAM'],
            fixture.teams[flavor],
            reason: name,
          );
          expect(
            settings['CODE_SIGN_ENTITLEMENTS'],
            flavor == null
                ? '$_widget.entitlements'
                : '$_widget.$flavor.entitlements',
            reason: name,
          );
          expect(
            settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'],
            flavor == null
                ? isNull
                : '\$(inherited) ${flavorCompilationCondition(flavor)}',
            reason: name,
          );
        }
      });

      test('keeps every flavor on its own Runner entitlements', () async {
        final pbxproj = Pbxproj.parse(await generate(flavors: fixture.flavors));

        for (final MapEntry(key: flavor, value: entitlements)
            in fixture.runnerEntitlements.entries) {
          expect(
            runnerEntitlementsSettingsForFlavor(
              pbxproj,
              flavor,
              projectDir: iosDir,
            ),
            [entitlements],
            reason: '$flavor',
          );
        }
      });

      test(
        'passes plutil -lint',
        () async {
          await generate(flavors: fixture.flavors);

          final lint = Process.runSync('plutil', ['-lint', pbxprojFile.path]);
          expect(lint.exitCode, 0, reason: '${lint.stdout}${lint.stderr}');
        },
        skip: Platform.isMacOS ? false : 'plutil is only available on macOS',
      );
    });
  }

  group('no_dependency_sections.pbxproj', () {
    setUp(() => useFixture('no_dependency_sections.pbxproj'));

    test('creates the missing sections in the order Xcode sorts them',
        () async {
      final pbxproj = Pbxproj.parse(await generate());

      final sections = [for (final section in pbxproj.sections) section.isa];
      expect(
        sections,
        containsAll(['PBXContainerItemProxy', 'PBXTargetDependency']),
      );
      expect(sections, [...sections]..sort());
    });
  });

  group('spm_migrated.pbxproj', () {
    setUp(() => useFixture('spm_migrated.pbxproj'));

    test('leaves a deployment target the project level sets high enough',
        () async {
      final before = Pbxproj.parse(pbxprojFile.readAsStringSync());
      final runnerConfigIds = [
        for (final config in before.buildConfigurationsOf(
          before.nativeTargetNamed('Runner')!,
        ))
          config.id,
      ];

      final after = Pbxproj.parse(await generate());

      for (final id in runnerConfigIds) {
        expect(
          ownBuildSettings(after.object(id)!),
          isNot(contains('IPHONEOS_DEPLOYMENT_TARGET')),
        );
      }
    });

    test('adds configurations for a flavor introduced later', () async {
      final before = Pbxproj.parse(await generate());
      final extension = before.nativeTargetNamed(_widget)!;
      final existing = {
        for (final config in before.buildConfigurationsOf(extension))
          config.id:
              before.text.substring(config.entry.start, config.entry.end),
      };

      final source = fixture('spm_migrated_flavor_next.pbxproj');
      final next = Pbxproj.parse(source);
      final editor = PbxprojEditor(before.text);
      final runner = next.nativeTargetNamed('Runner')!;
      final flavored = [
        for (final owner in [runner, next.rootProject!])
          for (final config in next.buildConfigurationsOf(owner))
            if (config.id.startsWith('NEXT')) (owner, config),
      ];
      editor.insertObjects(
        'XCBuildConfiguration',
        [
          for (final (_, config) in flavored)
            '\t\t${source.substring(config.entry.start, config.entry.end)}\n',
        ].join(),
      );
      for (final (owner, config) in flavored) {
        editor.addArrayEntry(
          owner.string('buildConfigurationList')!,
          'buildConfigurations',
          config.id,
          comment: config.string('name'),
        );
      }
      pbxprojFile.writeAsStringSync(editor.text);

      final text = await generate(flavors: const ['next']);
      final after = Pbxproj.parse(text);

      final settings = _settingsByConfiguration(after, _widget);
      expect(settings.keys, containsAll(['Debug-next', 'Release-next']));
      expect(
        settings['Profile-next']!['PRODUCT_BUNDLE_IDENTIFIER'],
        'es.antonborri.exampleHomeWidget.next.$_widget',
      );
      expect(
        settings['Profile-next']!['SWIFT_ACTIVE_COMPILATION_CONDITIONS'],
        '\$(inherited) ${flavorCompilationCondition('next')}',
      );
      expect(settings['Profile-next']!['IPHONEOS_DEPLOYMENT_TARGET'], '15.0');
      for (final MapEntry(key: id, value: object) in existing.entries) {
        final config = after.object(id)!;
        expect(
          after.text.substring(config.entry.start, config.entry.end),
          object,
        );
      }
      expect(_undefinedReferences(text), isEmpty);
      expect(await generate(flavors: const ['next']), text);
    });
  });

  group('a target it created', () {
    test('has the wiring an older version left dangling restored', () async {
      useFixture('no_dependency_sections.pbxproj');
      final wired = await generate();
      final project = Pbxproj.parse(wired);
      final runner = project.nativeTargetNamed('Runner')!;
      final dependency = runner.strings('dependencies').single;

      // Versions writing into sections the project did not have lost the
      // dependency and its proxy, and kept Runner's entry naming them.
      final damaged = (PbxprojEditor(wired)
            ..removeObjects({
              dependency,
              project.object(dependency)!.string('targetProxy')!,
            })
            ..addArrayEntry(
              runner.id,
              'dependencies',
              dependency,
              comment: 'PBXTargetDependency',
            ))
          .text;
      expect(_undefinedReferences(damaged), {dependency});
      pbxprojFile.writeAsStringSync(damaged);

      expect(await generate(), wired);
    });

    test('is restored after Xcode deleted it, without duplicating what is left',
        () async {
      useFixture('no_dependency_sections.pbxproj');
      final wired = await generate();
      final project = Pbxproj.parse(wired);
      final target = project.nativeTargetNamed(_widget)!;
      final listId = target.string('buildConfigurationList')!;
      final product = target.string('productReference')!;
      final dependency = project
          .nativeTargetNamed('Runner')!
          .strings('dependencies')
          .firstWhere(
            (id) => project.object(id)?.string('target') == target.id,
          );

      // What Xcode removes along with a target; the copy phase, the file
      // references of the target's folder and its group stay behind.
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(wired)
              ..removeObjects({
                target.id,
                listId,
                ...project.object(listId)!.strings('buildConfigurations'),
                for (final phase in target.strings('buildPhases')) ...[
                  phase,
                  ...project.object(phase)!.strings('files'),
                ],
                dependency,
                project.object(dependency)!.string('targetProxy')!,
                product,
                for (final file in project.objectsOfIsa('PBXBuildFile'))
                  if (file.string('fileRef') == product) file.id,
              }))
            .text,
      );

      final restored = await generate();

      expect(_duplicateObjectIds(restored), isEmpty);
      expect(_undefinedReferences(restored), isEmpty);
      final pbxproj = Pbxproj.parse(restored);
      expect(
        _settingsByConfiguration(pbxproj, _widget).keys,
        unorderedEquals(['Debug', 'Release', 'Profile']),
      );
      expect(
        pbxproj.nativeTargetNamed('Runner')!.strings('dependencies'),
        [dependency],
      );
      expect(await generate(), restored);
    });

    test('keeps Runner build phases in the order the developer chose',
        () async {
      useFixture('spm_migrated.pbxproj');
      final wired = Pbxproj.parse(await generate());
      final runner = wired.nativeTargetNamed('Runner')!;
      final editor = PbxprojEditor.parsed(wired);
      final items = runner.fields.array('buildPhases')!.items;
      final embed = items.singleWhere(
        (item) => item.string == xcodeObjectId('phase:copy:$_widget'),
      );
      editor.setArrayItems(runner.id, 'buildPhases', [
        editor.itemText(embed),
        for (final item in items)
          if (item != embed) editor.itemText(item),
      ]);
      pbxprojFile.writeAsStringSync(editor.text);

      expect(await generate(), editor.text);
    });

    test('keeps its product and folder where the developer put them', () async {
      useFixture('no_dependency_sections.pbxproj');
      final wired = Pbxproj.parse(await generate());
      final root = wired.rootProject!;
      final mainGroup = root.string('mainGroup')!;
      final productsGroup = root.string('productRefGroup')!;
      final folder = xcodeObjectId('group:$_widget');
      const widgets = 'C0FFEE000000000000000001';

      final editor = PbxprojEditor.parsed(wired);
      editor
        ..setArrayItems(productsGroup, 'children', [
          for (final item
              in wired.object(productsGroup)!.fields.array('children')!.items)
            if (item.string != xcodeObjectId('fileref:product:$_widget'))
              editor.itemText(item),
        ])
        ..setArrayItems(mainGroup, 'children', [
          for (final item
              in wired.object(mainGroup)!.fields.array('children')!.items)
            item.string == folder
                ? '$widgets /* Widgets */'
                : editor.itemText(item),
        ])
        ..insertObjects('PBXGroup', '''
\t\t$widgets /* Widgets */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t$folder /* $_widget */,
\t\t\t);
\t\t\tname = Widgets;
\t\t\tsourceTree = "<group>";
\t\t};
''');
      pbxprojFile.writeAsStringSync(editor.text);

      expect(await generate(), editor.text);
    });
  });

  group('an extension target Xcode created', () {
    const xcodeExtension = 'HomeWidgetExampleExtension';

    test('is updated by configuration name instead of duplicated', () async {
      useFixture('spm_migrated.pbxproj');
      final before = Pbxproj.parse(pbxprojFile.readAsStringSync());
      final ids = [
        for (final config in before.buildConfigurationsOf(
          before.nativeTargetNamed(xcodeExtension)!,
        ))
          config.id,
      ];

      final after = Pbxproj.parse(
        await generate(widgetClassName: xcodeExtension),
      );

      final configs = after.buildConfigurationsOf(
        after.nativeTargetNamed(xcodeExtension)!,
      );
      expect([for (final config in configs) config.id], ids);
      for (final config in configs) {
        expect(
          ownBuildSettings(config)['PRODUCT_BUNDLE_IDENTIFIER'],
          'es.antonborri.exampleHomeWidget.$xcodeExtension',
        );
      }
      // The values it replaced were chosen by hand, and nothing is wired the
      // way a target this patcher creates would be.
      verify(
        () => mockLogger.warn(
          any(that: contains('Reset PRODUCT_BUNDLE_IDENTIFIER on the "Debug"')),
        ),
      ).called(1);
      verifyNever(() => mockLogger.info(any(that: contains('Reset'))));
      for (final kind in const ['target', 'proxy', 'dep', 'phase:copy']) {
        expect(after.object(xcodeObjectId('$kind:$xcodeExtension')), isNull);
      }
    });

    test('gains the configurations of a flavor it lacks', () async {
      useFixture('spm_migrated_flavor_next.pbxproj');

      final text = await generate(
        widgetClassName: xcodeExtension,
        flavors: const ['next'],
      );

      final settings =
          _settingsByConfiguration(Pbxproj.parse(text), xcodeExtension);
      expect(
        settings.keys,
        unorderedEquals([
          'Debug',
          'Release',
          'Profile',
          'Debug-next',
          'Release-next',
          'Profile-next',
        ]),
      );
      expect(settings['Release-next']!['DEVELOPMENT_TEAM'], 'NEXT7EAM42');
      expect(
        settings['Release-next']!['CODE_SIGN_ENTITLEMENTS'],
        '$xcodeExtension.next.entitlements',
      );
      expect(_undefinedReferences(text), isEmpty);
      expect(
        await generate(
          widgetClassName: xcodeExtension,
          flavors: const ['next'],
        ),
        text,
      );
    });
  });

  test('reads a setting from the xcconfig a reordered configuration names',
      () async {
    useFixture('non_canonical_field_order.pbxproj');
    File(p.join(iosDir.path, 'Flutter', 'Debug.xcconfig'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('DEVELOPMENT_TEAM = XCCONFIG42\n');

    final settings = _settingsByConfiguration(
      Pbxproj.parse(await generate(flavors: const ['dev'])),
      _widget,
    );

    // The xcconfig a target configuration is based on overrides the project
    // level, and the configuration's own settings override both.
    expect(settings['Debug-dev']!['DEVELOPMENT_TEAM'], 'XCCONFIG42');
    expect(settings['Release-dev']!['DEVELOPMENT_TEAM'], 'DEV7EAM123');
    expect(settings['Debug']!['DEVELOPMENT_TEAM'], 'T3PND82A9W');
  });

  test('reads the xcconfigs Xcode 16 names by their synchronized folder',
      () async {
    const folder = 'C0FFEE00000000000000C0F1';
    const targetDebugDev = 'DE0000000000000000000001';
    const projectDebugDev = 'DE0000000000000000000011';
    final editor = PbxprojEditor(
      fixture('non_canonical_field_order.pbxproj').replaceFirst(
        '\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;\n\t\t};\n\t\tDE0000000000000000000002',
        '''
\t\t\tbaseConfigurationReferenceAnchor = $folder /* Config */;
\t\t\tbaseConfigurationReferenceRelativePath = Flavors/Debug-dev.xcconfig;
\t\t};
\t\tDE0000000000000000000002''',
      ).replaceFirst(
        '\t\t$projectDebugDev /* Debug-dev */ = {\n',
        '''
\t\t$projectDebugDev /* Debug-dev */ = {
\t\t\tbaseConfigurationReferenceAnchor = $folder /* Config */;
\t\t\tbaseConfigurationReferenceRelativePath = Project.xcconfig;
''',
      ),
    );
    editor
      ..removeBuildSetting(projectDebugDev, 'DEVELOPMENT_TEAM')
      ..insertObjects('PBXFileSystemSynchronizedRootGroup', '''
\t\t$folder /* Config */ = {
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = Config;
\t\t\tsourceTree = "<group>";
\t\t};
''')
      ..addArrayEntry(
        editor.project.rootProject!.string('mainGroup')!,
        'children',
        folder,
        comment: 'Config',
      );
    expect(
      editor.project.object(targetDebugDev)!.fields.entry(
            'baseConfigurationReference',
          ),
      isNull,
    );
    pbxprojFile.writeAsStringSync(editor.text);
    File(p.join(iosDir.path, 'Config', 'Flavors', 'Debug-dev.xcconfig'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('PRODUCT_BUNDLE_IDENTIFIER = com.example.anchored\n');
    File(p.join(iosDir.path, 'Config', 'Project.xcconfig'))
        .writeAsStringSync('DEVELOPMENT_TEAM = ANCH0RTEAM\n');

    final settings = _settingsByConfiguration(
      Pbxproj.parse(await generate(flavors: const ['dev'])),
      _widget,
    );

    expect(
      settings['Debug-dev']!['PRODUCT_BUNDLE_IDENTIFIER'],
      'com.example.anchored.$_widget',
    );
    expect(settings['Debug-dev']!['DEVELOPMENT_TEAM'], 'ANCH0RTEAM');
    expect(settings['Release-dev']!['DEVELOPMENT_TEAM'], 'DEV7EAM123');
  });

  group('a project without an app target', () {
    late String content;

    setUp(() {
      content = fixture('no_dependency_sections.pbxproj')
          .replaceFirst('\t\t\tname = Runner;\n', '\t\t\tname = App;\n')
          .replaceFirst(
            'productType = "com.apple.product-type.application";',
            'productType = "com.apple.product-type.framework";',
          );
      pbxprojFile.writeAsStringSync(content);
    });

    test('fails naming what is missing and writes nothing', () async {
      await expectLater(
        ensureWidgetExtensionTargetInXcodeProject(
          pbxprojFile: pbxprojFile,
          widgetClassName: _widget,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(
                'the project is missing an app target (a PBXNativeTarget '
                'named "Runner", or the only one of productType '
                '"com.apple.product-type.application")',
              ),
              contains(pbxprojFile.path),
            ),
          ),
        ),
      );
      expect(pbxprojFile.readAsStringSync(), content);
    });

    test('fails the check that runs before anything is written', () async {
      await expectLater(
        checkWidgetExtensionTargetInXcodeProject(
          pbxprojFile: pbxprojFile,
          widgetClassName: _widget,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('PBXNativeTarget named "Runner"'),
          ),
        ),
      );
    });

    test('fails the iOS generator before it writes anything', () async {
      await expectLater(
        IosGenerator(
          spec: WidgetSpec(
            data: const HomeWidget(
              name: 'Greeting',
              iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
            ),
            className: 'Greeting',
          ),
          projectRoot: tempDir,
        ).generate(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('PBXNativeTarget named "Runner"'),
          ),
        ),
      );
      expect(pbxprojFile.readAsStringSync(), content);
      expect(Directory(p.join(iosDir.path, _widget)).existsSync(), isFalse);
      expect(
        File(p.join(iosDir.path, '$_widget.entitlements')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(iosDir.path, 'Runner', 'Runner.entitlements')).existsSync(),
        isFalse,
      );
    });
  });

  group('a renamed Xcode project', () {
    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'Greeting',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
      ),
      className: 'Greeting',
    );
    late File renamed;

    /// Moves spm_migrated.pbxproj to `ios/MyApp.xcodeproj`, with its app
    /// target called [target], its Info.plist in [appFolder] and no
    /// entitlements file to sign with yet.
    void useRenamed({required String target, required String appFolder}) {
      pbxprojFile.parent.deleteSync();
      renamed = File(p.join(iosDir.path, 'MyApp.xcodeproj', 'project.pbxproj'))
        ..parent.createSync()
        ..writeAsStringSync(
          fixture('spm_migrated.pbxproj')
              .replaceFirst('\t\t\tname = Runner;\n', '\t\t\tname = $target;\n')
              .replaceAll(
                '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n',
                '',
              )
              .replaceAll(
                'INFOPLIST_FILE = Runner/Info.plist;',
                'INFOPLIST_FILE = $appFolder/Info.plist;',
              ),
        );
    }

    bool dependsOnWidget(Pbxproj pbxproj, String target) {
      final extension = pbxproj.nativeTargetNamed(_widget)!.id;
      return pbxproj
          .nativeTargetNamed(target)!
          .strings('dependencies')
          .any((id) => pbxproj.object(id)?.string('target') == extension);
    }

    test('wires the widget into the app target named after it', () async {
      useRenamed(target: 'MyApp', appFolder: 'MyApp');

      await IosGenerator(spec: spec, projectRoot: tempDir).generate();

      final pbxproj = Pbxproj.parse(renamed.readAsStringSync());
      expect(dependsOnWidget(pbxproj, 'MyApp'), isTrue);
      expect(
        pbxproj.nativeTargetNamed('MyApp')!.strings('buildPhases'),
        contains(xcodeObjectId('phase:copy:$_widget')),
      );
      final extensionSettings = _settingsByConfiguration(pbxproj, _widget);
      expect(
        extensionSettings.keys,
        unorderedEquals(_settingsByConfiguration(pbxproj, 'MyApp').keys),
      );
      for (final MapEntry(key: name, value: settings)
          in extensionSettings.entries) {
        expect(settings['IPHONEOS_DEPLOYMENT_TARGET'], '15.0', reason: name);
        expect(
          settings['PRODUCT_BUNDLE_IDENTIFIER'],
          'es.antonborri.exampleHomeWidget.$_widget',
          reason: name,
        );
      }
      expect(
        runnerEntitlementsSettingsForFlavor(
          pbxproj,
          null,
          projectDir: iosDir,
          projectName: 'MyApp',
        ),
        ['MyApp/MyApp.entitlements'],
      );
      expect(
        File(p.join(iosDir.path, 'MyApp', 'MyApp.entitlements'))
            .readAsStringSync(),
        contains('<string>group.example</string>'),
      );
      expect(Directory(p.join(iosDir.path, 'Runner')).existsSync(), isFalse);
    });

    test('keeps Runner/Runner.entitlements while the app lives in ios/Runner',
        () async {
      useRenamed(target: 'App', appFolder: 'Runner');

      await IosGenerator(spec: spec, projectRoot: tempDir).generate();

      final pbxproj = Pbxproj.parse(renamed.readAsStringSync());
      expect(dependsOnWidget(pbxproj, 'App'), isTrue);
      expect(dependsOnWidget(pbxproj, 'RunnerTests'), isFalse);
      expect(
        runnerEntitlementsSettingsForFlavor(
          pbxproj,
          null,
          projectDir: iosDir,
          projectName: 'MyApp',
        ),
        ['Runner/Runner.entitlements'],
      );
      expect(
        File(p.join(iosDir.path, 'Runner', 'Runner.entitlements'))
            .readAsStringSync(),
        contains('<string>group.example</string>'),
      );
    });

    test('names the project a declared flavor is missing from', () async {
      useRenamed(target: 'MyApp', appFolder: 'MyApp');
      final content = renamed.readAsStringSync();

      await expectLater(
        IosGenerator(
          spec: WidgetSpec(
            data: const HomeWidget(
              name: 'Greeting',
              iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
              flavors: {'stg': HomeWidgetFlavor()},
            ),
            className: 'Greeting',
          ),
          projectRoot: tempDir,
        ).generate(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains(
              'which MyApp.xcodeproj does not have: "stg" needs Debug-stg, '
              'Release-stg and Profile-stg.',
            ),
          ),
        ),
      );
      expect(renamed.readAsStringSync(), content);
      expect(Directory(p.join(iosDir.path, _widget)).existsSync(), isFalse);
    });
  });

  test('reports a project it cannot parse as a generator error', () async {
    const content = '{\n\tobjects = {\n\t\tbroken\n\t};\n}\n';
    pbxprojFile.writeAsStringSync(content);

    for (final patch in <Future<void> Function()>[
      () => ensureWidgetExtensionTargetInXcodeProject(
            pbxprojFile: pbxprojFile,
            widgetClassName: _widget,
          ),
      () => ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile),
      () => ensureMinimumDeploymentTargetInXcodeProject(
            pbxprojFile: pbxprojFile,
          ),
      () => ensureLocalizableCatalogInXcodeProject(
            pbxprojFile: pbxprojFile,
            widgetClassName: _widget,
            locales: const ['en'],
          ),
      () => ensureWidgetResourceFilesInXcodeProject(
            pbxprojFile: pbxprojFile,
            widgetClassName: _widget,
            resourceFileNames: const [],
          ),
      () => ensureWidgetExtensionDevelopmentTeamInXcodeProject(
            pbxprojFile: pbxprojFile,
          ),
      () => readXcodeProject(pbxprojFile),
    ]) {
      await expectLater(
        patch(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith(
                'Could not read the Xcode project ${pbxprojFile.path}: ',
              ),
              contains('line 4'),
            ),
          ),
        ),
      );
    }
    expect(pbxprojFile.readAsStringSync(), content);
  });
}
