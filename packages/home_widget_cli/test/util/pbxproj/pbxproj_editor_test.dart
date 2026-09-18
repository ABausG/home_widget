import 'package:home_widget_cli/src/util/pbxproj/pbxproj_editor.dart';
import 'package:test/test.dart';

const _project = '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXBuildFile section */
		AAAA /* a.swift in Sources */ = {isa = PBXBuildFile; fileRef = BBBB /* a.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		BBBB /* a.swift */ = {isa = PBXFileReference; path = a.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXNativeTarget section */
		TARGET /* Runner */ = {
			packageProductDependencies = (
				PKG /* Package */,
			);
			isa = PBXNativeTarget;
			buildPhases = (
				SOURCES /* Sources */,
			);
			name = Runner;
		};
/* End PBXNativeTarget section */

/* Begin PBXSourcesBuildPhase section */
		SOURCES /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			files = (
				AAAA /* a.swift in Sources */,
			);
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		CONFIG /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALPHA = 1;
				LIST = (
					"\$(inherited)",
					FLAG,
				);
				OMEGA = 2;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
	rootObject = TARGET;
}
''';

const _inlineProject = '''
{
	objects = {
		GROUP = {isa = PBXGroup; children = (AAAA /* a.swift */, BBBB, ); };
		CONFIG = {isa = XCBuildConfiguration; buildSettings = {ALPHA = 1; }; name = Debug; };
	};
}
''';

void main() {
  test('pbxLiteral quotes what Xcode quotes', () {
    expect(pbxLiteral('Debug'), 'Debug');
    expect(pbxLiteral('Runner/Runner.plist'), 'Runner/Runner.plist');
    expect(pbxLiteral('a_b'), 'a_b');
    expect(pbxLiteral(r'$(SRCROOT)/Runner'), r'"$(SRCROOT)/Runner"');
    expect(pbxLiteral('Debug-dev'), '"Debug-dev"');
    expect(pbxLiteral('say "hi"'), r'"say \"hi\""');
    expect(pbxLiteral(''), '""');
    expect(pbxLiteral('//x'), '"//x"');
    expect(pbxLiteral('a//b'), '"a//b"');
    expect(pbxLiteral('a___b'), '"a___b"');
  });

  test('pbxLiteral round-trips through the parser', () {
    for (final value in const [
      'plain',
      'say "hi"',
      r'back\slash',
      r'trailing\',
      'line\nbreak',
      'tab\there',
      r'$(inherited) HW_FLAVOR_DEV',
      'with spaces',
      '//x',
      'a//b',
      'a___b',
      '',
      '<group>',
      'Grüße 日本',
      '/* not a comment */',
      r'"$(inherited)" PATH="a"',
    ]) {
      final root = parsePbxPlist('{ k = ${pbxLiteral(value)}; }').root;

      expect(root.string('k'), value, reason: pbxLiteral(value));
    }
  });

  test('an editor over a parsed project starts from that parse', () {
    final project = Pbxproj.parse(_project);
    final editor = PbxprojEditor.parsed(project);

    expect(editor.text, _project);
    expect(editor.project, same(project));

    editor.addArrayEntry('TARGET', 'buildPhases', 'NEW');

    expect(editor.project, isNot(same(project)));
    expect(
      editor.project.object('TARGET')!.strings('buildPhases'),
      ['SOURCES', 'NEW'],
    );
  });

  group('insertObjects', () {
    test('appends to the section of its class', () {
      final editor = PbxprojEditor(_project)
        ..insertObjects(
          'PBXBuildFile',
          '\t\tCCCC /* b.swift in Sources */ = {isa = PBXBuildFile; };\n',
        );

      expect(
        editor.text,
        contains(
          '\t\tAAAA /* a.swift in Sources */ = {isa = PBXBuildFile; fileRef = BBBB /* a.swift */; };\n'
          '\t\tCCCC /* b.swift in Sources */ = {isa = PBXBuildFile; };\n'
          '/* End PBXBuildFile section */\n',
        ),
      );
    });

    test('creates a missing section where Xcode sorts it', () {
      final editor = PbxprojEditor(_project)
        ..insertObjects(
          'PBXContainerItemProxy',
          '\t\tPROXY /* PBXContainerItemProxy */ = {\n'
              '\t\t\tisa = PBXContainerItemProxy;\n'
              '\t\t};\n',
        );

      expect(
        editor.text,
        contains(
          '/* End PBXBuildFile section */\n'
          '\n'
          '/* Begin PBXContainerItemProxy section */\n'
          '\t\tPROXY /* PBXContainerItemProxy */ = {\n'
          '\t\t\tisa = PBXContainerItemProxy;\n'
          '\t\t};\n'
          '/* End PBXContainerItemProxy section */\n'
          '\n'
          '/* Begin PBXFileReference section */\n',
        ),
      );
      expect(editor.project.object('PROXY')!.isa, 'PBXContainerItemProxy');
    });

    test('appends after the last object of its class outside any section', () {
      const project = '''
{
	objects = {
		AAAA = {isa = PBXBuildFile; };
		BBBB = {isa = PBXFileReference; };
	};
}
''';
      final editor = PbxprojEditor(project)
        ..insertObjects('PBXBuildFile', '\t\tCCCC = {isa = PBXBuildFile; };\n');

      expect(
        editor.text,
        contains(
          '\t\tAAAA = {isa = PBXBuildFile; };\n'
          '\t\tCCCC = {isa = PBXBuildFile; };\n'
          '\t\tBBBB = {isa = PBXFileReference; };\n',
        ),
      );
    });

    test('creates the first section at the end of objects', () {
      const project = '''
{
	objects = {
		BBBB = {isa = PBXFileReference; };
	};
}
''';
      final editor = PbxprojEditor(project)
        ..insertObjects('PBXBuildFile', '\t\tCCCC = {isa = PBXBuildFile; };\n');

      expect(
        editor.text,
        contains(
          '\t\tBBBB = {isa = PBXFileReference; };\n'
          '/* Begin PBXBuildFile section */\n'
          '\t\tCCCC = {isa = PBXBuildFile; };\n'
          '/* End PBXBuildFile section */\n'
          '\t};\n',
        ),
      );
      expect(editor.project.sections.single.isa, 'PBXBuildFile');
    });

    test('creates a section sorting after every other one at the end', () {
      final editor = PbxprojEditor(_project)
        ..insertObjects(
          'XCConfigurationList',
          '\t\tLIST = {\n\t\t\tisa = XCConfigurationList;\n\t\t};\n',
        );

      expect(
        editor.text,
        contains(
          '/* End XCBuildConfiguration section */\n'
          '\n'
          '/* Begin XCConfigurationList section */\n'
          '\t\tLIST = {\n'
          '\t\t\tisa = XCConfigurationList;\n'
          '\t\t};\n'
          '/* End XCConfigurationList section */\n'
          '\t};\n',
        ),
      );
    });

    group('stays inside objects when an anchor shares its line', () {
      void expectInserted(PbxprojEditor editor, String isa, String text) {
        expect(editor.text, text);
        final project = Pbxproj.parse(editor.text);
        expect(project.root.entries.map((entry) => entry.key.value), [
          'objects',
        ]);
        expect(project.object('NEW')!.isa, isa);
      }

      const buildFile = '\t\tNEW = {isa = PBXBuildFile; };\n';

      test('with the end marker after a closing brace', () {
        const project = '''
{
	objects = {
/* Begin PBXBuildFile section */
		X = {
			isa = PBXBuildFile;
		}; /* End PBXBuildFile section */
	};
}
''';
        final editor = PbxprojEditor(project)
          ..insertObjects('PBXBuildFile', buildFile);

        expectInserted(editor, 'PBXBuildFile', '''
{
	objects = {
/* Begin PBXBuildFile section */
		X = {
			isa = PBXBuildFile;
		};
		NEW = {isa = PBXBuildFile; };
/* End PBXBuildFile section */
	};
}
''');
      });

      test('with objects written on one line', () {
        const project = '''
{
	objects = {X = {isa = PBXFileReference; }; };
}
''';
        final editor = PbxprojEditor(project)
          ..insertObjects(
            'PBXFileReference',
            '\t\tNEW = {isa = PBXFileReference; };\n',
          );

        expectInserted(editor, 'PBXFileReference', '''
{
	objects = {X = {isa = PBXFileReference; };
		NEW = {isa = PBXFileReference; };
};
}
''');
      });

      test('with empty objects', () {
        const project = '''
{
	objects = {};
}
''';
        final editor = PbxprojEditor(project)
          ..insertObjects('PBXBuildFile', buildFile);

        expectInserted(editor, 'PBXBuildFile', '''
{
	objects = {
/* Begin PBXBuildFile section */
		NEW = {isa = PBXBuildFile; };
/* End PBXBuildFile section */
};
}
''');
      });

      test('with a whole file on one line', () {
        const project = '// !\$*UTF8*\$!\n'
            '{ objects = { /* Begin PBXBuildFile section */ '
            'B = {isa = PBXBuildFile; }; /* End PBXBuildFile section */ '
            '/* Begin XCBuildConfiguration section */ '
            'C = {isa = XCBuildConfiguration; }; '
            '/* End XCBuildConfiguration section */ }; }\n';
        final editor = PbxprojEditor(project)
          ..insertObjects('PBXBuildFile', buildFile)
          ..insertObjects('PBXGroup', '\t\tG = {isa = PBXGroup; };\n')
          ..insertObjects(
            'XCConfigurationList',
            '\t\tL = {isa = XCConfigurationList; };\n',
          );

        expectInserted(editor, 'PBXBuildFile', '''
// !\$*UTF8*\$!
{ objects = { /* Begin PBXBuildFile section */ B = {isa = PBXBuildFile; };
		NEW = {isa = PBXBuildFile; };
/* End PBXBuildFile section */
/* Begin PBXGroup section */
		G = {isa = PBXGroup; };
/* End PBXGroup section */

/* Begin XCBuildConfiguration section */ C = {isa = XCBuildConfiguration; }; /* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		L = {isa = XCConfigurationList; };
/* End XCConfigurationList section */
}; }
''');
        expect(
          Pbxproj.parse(editor.text).sections.map((section) => section.isa),
          [
            'PBXBuildFile',
            'PBXGroup',
            'XCBuildConfiguration',
            'XCConfigurationList',
          ],
        );
      });
    });
  });

  group('addArrayEntry', () {
    test('appends with the indentation of its siblings', () {
      final editor = PbxprojEditor(_project)
        ..addArrayEntry(
          'SOURCES',
          'files',
          'CCCC',
          comment: 'b.swift in Sources',
        );

      expect(
        editor.text,
        contains(
          '\t\t\t\tAAAA /* a.swift in Sources */,\n'
          '\t\t\t\tCCCC /* b.swift in Sources */,\n'
          '\t\t\t);',
        ),
      );
    });

    test('skips an element that is there already', () {
      final editor = PbxprojEditor(_project)
        ..addArrayEntry('SOURCES', 'files', 'AAAA');

      expect(editor.text, _project);
    });

    test('quotes the value it appends', () {
      final editor = PbxprojEditor(_inlineProject)
        ..addArrayEntry('GROUP', 'children', 'pt-BR')
        ..addArrayEntry('GROUP', 'children', 'pt-BR');

      expect(
        editor.text,
        contains('children = (AAAA /* a.swift */, BBBB, "pt-BR", );'),
      );
    });

    test('appends to an array written on one line', () {
      final editor = PbxprojEditor(_inlineProject)
        ..addArrayEntry('GROUP', 'children', 'CCCC');

      expect(
        editor.text,
        contains('children = (AAAA /* a.swift */, BBBB, CCCC, );'),
      );
    });

    group('separates a last element written without a comma', () {
      String appended(String array) {
        final editor = PbxprojEditor('''
{
	objects = {
		P = {
			isa = PBXProject;
			knownRegions = $array;
		};
	};
}
''')..addArrayEntry('P', 'knownRegions', 'de');
        final regions = Pbxproj.parse(editor.text).object('P')!;
        expect(regions.strings('knownRegions'), ['en', 'Base', 'de']);
        final start = editor.text.indexOf('(');
        return editor.text.substring(start, editor.text.indexOf(';', start));
      }

      test('on one line', () {
        expect(appended('(en, Base)'), '(en, Base, de, )');
        expect(appended('(en, Base /* b */ )'), '(en, Base /* b */, de, )');
      });

      test('on lines of their own', () {
        expect(
          appended('(\n\t\t\t\ten,\n\t\t\t\tBase\n\t\t\t)'),
          '(\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t\tde,\n\t\t\t)',
        );
      });

      test('after the opening parenthesis', () {
        expect(
          appended('(en, Base\n\t\t\t)'),
          '(en, Base,\n\t\t\t\tde,\n\t\t\t)',
        );
      });

      test('before a closing parenthesis on the same line', () {
        expect(
          appended('(\n\t\t\t\ten,\n\t\t\t\tBase)'),
          '(\n\t\t\t\ten,\n\t\t\t\tBase, de, )',
        );
      });
    });

    test('creates a missing field in sorted order after isa', () {
      final editor = PbxprojEditor(_project)
        ..addArrayEntry(
          'TARGET',
          'dependencies',
          'DEP',
          comment: 'PBXTargetDependency',
        );

      expect(
        editor.text,
        contains(
          '\t\t\tisa = PBXNativeTarget;\n'
          '\t\t\tbuildPhases = (\n'
          '\t\t\t\tSOURCES /* Sources */,\n'
          '\t\t\t);\n'
          '\t\t\tdependencies = (\n'
          '\t\t\t\tDEP /* PBXTargetDependency */,\n'
          '\t\t\t);\n'
          '\t\t\tname = Runner;\n',
        ),
      );
    });
  });

  group('setArrayItems', () {
    test('rewrites the elements in the given order', () {
      final editor = PbxprojEditor(_project)
        ..setArrayItems('TARGET', 'buildPhases', [
          'EMBED /* Embed */',
          'SOURCES /* Sources */',
        ]);

      expect(
        editor.text,
        contains(
          '\t\t\tbuildPhases = (\n'
          '\t\t\t\tEMBED /* Embed */,\n'
          '\t\t\t\tSOURCES /* Sources */,\n'
          '\t\t\t);\n',
        ),
      );
    });

    test('leaves an array that already holds the elements untouched', () {
      final editor = PbxprojEditor(_project)
        ..setArrayItems('TARGET', 'buildPhases', ['SOURCES /* Sources */']);

      expect(editor.text, _project);
    });

    test('keeps an array written on one line on one line', () {
      final editor = PbxprojEditor(_inlineProject)
        ..setArrayItems('GROUP', 'children', ['BBBB', 'AAAA /* a.swift */']);

      expect(
        editor.text,
        contains('children = (BBBB, AAAA /* a.swift */, );'),
      );
    });
  });

  group('build settings', () {
    test('replaces a single value in place', () {
      final editor = PbxprojEditor(_project)
        ..setBuildSetting('CONFIG', 'OMEGA', '3');

      expect(editor.text, contains('\t\t\t\tOMEGA = 3;\n'));
      expect(editor.text, isNot(contains('OMEGA = 2;')));
    });

    test('replaces a list value whole', () {
      final editor = PbxprojEditor(_project)
        ..setBuildSetting('CONFIG', 'LIST', 'a b');

      expect(
        editor.text,
        contains(
          '\t\t\t\tALPHA = 1;\n'
          '\t\t\t\tLIST = "a b";\n'
          '\t\t\t\tOMEGA = 2;\n',
        ),
      );
    });

    test('quotes the key and value it writes', () {
      const value = r'$(inherited) PATH="a" HW_FLAVOR_DEV';
      final editor = PbxprojEditor(_project)
        ..setBuildSetting('CONFIG', 'OMEGA', value)
        ..setBuildSetting('CONFIG', 'KEY[sdk=iphoneos*]', 'a/b');

      expect(
        editor.text,
        contains(r'OMEGA = "$(inherited) PATH=\"a\" HW_FLAVOR_DEV";'),
      );
      expect(editor.text, contains('"KEY[sdk=iphoneos*]" = a/b;'));
      final settings = Pbxproj.parse(editor.text)
          .object('CONFIG')!
          .fields
          .dict('buildSettings')!;
      expect(settings.string('OMEGA'), value);
      expect(settings.string('KEY[sdk=iphoneos*]'), 'a/b');
    });

    test('writes the last copy of a duplicated setting and drops the rest', () {
      const project = '''
{
	objects = {
		CONFIG = {
			isa = XCBuildConfiguration;
			buildSettings = {
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				ALPHA = 1;
				IPHONEOS_DEPLOYMENT_TARGET = 12.0; OMEGA = 2;
			};
		};
	};
}
''';
      final editor = PbxprojEditor(project)
        ..setBuildSetting('CONFIG', 'IPHONEOS_DEPLOYMENT_TARGET', '14.0');

      expect(editor.text, '''
{
	objects = {
		CONFIG = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALPHA = 1;
				IPHONEOS_DEPLOYMENT_TARGET = 14.0; OMEGA = 2;
			};
		};
	};
}
''');
    });

    test('inserts a new setting where Xcode sorts it', () {
      final editor = PbxprojEditor(_project)
        ..setBuildSetting('CONFIG', 'BETA', 'YES')
        ..setBuildSetting('CONFIG', 'ZULU', 'NO');

      expect(
        editor.text,
        contains(
          '\t\t\t\tALPHA = 1;\n'
          '\t\t\t\tBETA = YES;\n'
          '\t\t\t\tLIST = (\n',
        ),
      );
      expect(
        editor.text,
        contains(
          '\t\t\t\tOMEGA = 2;\n'
          '\t\t\t\tZULU = NO;\n'
          '\t\t\t};\n',
        ),
      );
    });

    test('appends to settings written on one line', () {
      final editor = PbxprojEditor(_inlineProject)
        ..setBuildSetting('CONFIG', 'OMEGA', '2');

      expect(
        editor.text,
        contains('buildSettings = {ALPHA = 1; OMEGA = 2; };'),
      );
    });

    test('creates the buildSettings a configuration does not have', () {
      const project = '''
{
	objects = {
		CONFIG = {
			isa = XCBuildConfiguration;
			name = Debug;
		};
	};
}
''';
      final editor = PbxprojEditor(project)
        ..setBuildSetting('CONFIG', 'SKIP_INSTALL', 'YES');

      expect(
        editor.text,
        contains(
          '\t\t\tisa = XCBuildConfiguration;\n'
          '\t\t\tbuildSettings = {\n'
          '\t\t\t\tSKIP_INSTALL = YES;\n'
          '\t\t\t};\n'
          '\t\t\tname = Debug;\n',
        ),
      );
    });

    test('indents the first setting one level deeper than the brace', () {
      const project = '''
{
	objects = {
		CONFIG = {
			isa = XCBuildConfiguration;
			buildSettings = {
			};
		};
	};
}
''';
      final editor = PbxprojEditor(project)
        ..setBuildSetting('CONFIG', 'ALPHA', '1');

      expect(
        editor.text,
        contains(
          '\t\t\tbuildSettings = {\n'
          '\t\t\t\tALPHA = 1;\n'
          '\t\t\t};\n',
        ),
      );
    });

    test('removes a list value with every line it spans', () {
      final editor = PbxprojEditor(_project)
        ..removeBuildSetting('CONFIG', 'LIST');

      expect(
        editor.text,
        contains(
          '\t\t\t\tALPHA = 1;\n'
          '\t\t\t\tOMEGA = 2;\n',
        ),
      );
      expect(editor.text, isNot(contains('FLAG')));
    });

    test('removes every copy of a duplicated setting', () {
      const project = '''
{
	objects = {
		CONFIG = {
			isa = XCBuildConfiguration;
			buildSettings = {A = 1; B = 2; A = 3; };
		};
		OTHER = {isa = XCBuildConfiguration; };
	};
}
''';
      final editor = PbxprojEditor(project)
        ..removeBuildSetting('CONFIG', 'A')
        ..removeBuildSetting('OTHER', 'A')
        ..removeBuildSetting('MISSING', 'A');

      expect(editor.text, contains('buildSettings = {B = 2; };'));
    });
  });

  group('removeObjects', () {
    test('drops the objects, the elements naming them and their sections', () {
      final editor = PbxprojEditor(_project)..removeObjects({'AAAA', 'BBBB'});

      expect(editor.text, isNot(contains('AAAA')));
      expect(editor.text, isNot(contains('BBBB')));
      expect(
        editor.text,
        contains('\tobjects = {\n\n/* Begin PBXNativeTarget section */\n'),
      );
      expect(editor.text, contains('\t\t\tfiles = (\n\t\t\t);\n'));
    });

    test('drops every copy of a duplicated object', () {
      const project = '''
{
	objects = {
		KEEP = {isa = PBXGroup; children = (
			X,
		); };
		X = {isa = PBXBuildFile; };
		X = {isa = PBXBuildFile; };
	};
}
''';
      final editor = PbxprojEditor(project)..removeObjects({'X'});

      expect(editor.text, '''
{
	objects = {
		KEEP = {isa = PBXGroup; children = (
		); };
	};
}
''');
    });

    test('cuts an element out of an array on one line', () {
      final editor = PbxprojEditor(_inlineProject)..removeObjects({'AAAA'});

      expect(editor.text, contains('children = (BBBB, );'));
    });

    test('leaves no whitespace behind an element ending its line', () {
      const project = '''
{
	objects = {
		G = {
			isa = PBXGroup;
			children = (
				Z, X,\t
				W
			);
		};
	};
}
''';
      final editor = PbxprojEditor(project)..removeObjects({'X'});

      expect(editor.text, contains('\t\t\t\tZ,\n\t\t\t\tW\n'));
    });

    test('drops a section it empties the way Xcode leaves none', () {
      const project = '''
{
	objects = {
/* Begin PBXBuildFile section */
		A = {isa = PBXBuildFile; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		B = {isa = PBXFileReference; };
		C = {isa = PBXFileReference; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
/* End PBXGroup section */

/* Begin PBXSourcesBuildPhase section */
		D = {isa = PBXSourcesBuildPhase; };
/* End PBXSourcesBuildPhase section */
	};
}
''';
      final editor = PbxprojEditor(project)..removeObjects({'A', 'B', 'D'});

      expect(editor.text, '''
{
	objects = {

/* Begin PBXFileReference section */
		C = {isa = PBXFileReference; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
/* End PBXGroup section */
	};
}
''');
    });

    test('drops a section it empties on a line shared with others', () {
      const project = '{ objects = { /* Begin A section */ X = {isa = A; }; '
          '/* End A section */ /* Begin B section */ Y = {isa = B; }; '
          '/* End B section */ }; }';
      final editor = PbxprojEditor(project)..removeObjects({'X'});

      expect(
        editor.text,
        '{ objects = { /* Begin B section */ Y = {isa = B; }; '
        '/* End B section */ }; }',
      );
    });
  });

  test('writes the line breaks of a CRLF file', () {
    final editor = PbxprojEditor(_project.replaceAll('\n', '\r\n'))
      ..insertObjects('PBXBuildFile', '\t\tCCCC = {isa = PBXBuildFile; };\n')
      ..insertObjects('PBXGroup', '\t\tGROUP = {isa = PBXGroup; };\n')
      ..addArrayEntry('SOURCES', 'files', 'CCCC')
      ..addArrayEntry('GROUP', 'children', 'BBBB')
      ..setArrayItems('TARGET', 'buildPhases', ['A', 'B'])
      ..setBuildSetting('CONFIG', 'BETA', 'YES')
      ..removeObjects({'AAAA'});

    expect(RegExp(r'(?<!\r)\n').hasMatch(editor.text), isFalse);
    final project = Pbxproj.parse(editor.text);
    expect(project.object('GROUP')!.strings('children'), ['BBBB']);
    expect(project.object('SOURCES')!.strings('files'), ['CCCC']);
  });

  test('retitle rewrites every comment following the id', () {
    final editor = PbxprojEditor(_project)..retitle('AAAA', 'renamed');

    expect('AAAA /* renamed */'.allMatches(editor.text), hasLength(2));
    expect(editor.text, isNot(contains('a.swift in Sources')));
  });
}
