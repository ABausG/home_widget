import 'dart:io';

import 'package:home_widget_cli/src/util/pbxproj/pbxproj_document.dart';
import 'package:test/test.dart';

import '../../helpers/package_root.dart';

String _source(String text, PbxNode node) =>
    text.substring(node.start, node.end);

void main() {
  group('parsePbxPlist', () {
    test('reads dictionaries, arrays and strings around comments', () {
      const text = r'''
// !$*UTF8*$!
{
	/* leading */ archiveVersion = 1;
	list = ( a /* first */, "b c" , /* between */ d, );
	nested = { inner = value; };
	// line comment
	empty = ();
}
''';
      final root = parsePbxPlist(text).root;

      expect(root.string('archiveVersion'), '1');
      expect(root.array('list')!.strings, ['a', 'b c', 'd']);
      expect(root.dict('nested')!.string('inner'), 'value');
      expect(root.array('empty')!.items, isEmpty);
    });

    test('resolves escapes in quoted keys and values', () {
      const text = r'''
{
	"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone \"Developer\"";
	script = "line\none\ttab \\ backslash \U00e9 \101";
}
''';
      final root = parsePbxPlist(text).root;

      final identity = root.entries.first;
      expect(identity.key.value, 'CODE_SIGN_IDENTITY[sdk=iphoneos*]');
      expect(
        _source(text, identity.key),
        '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"',
      );
      expect(buildSettingValue(identity), 'iPhone "Developer"');
      expect(root.string('script'), 'line\none\ttab \\ backslash é A');
    });

    test('resolves the control character escapes', () {
      final root = parsePbxPlist(r'{ value = "\r\a\b\f\v"; }').root;

      expect(root.string('value'), '\r\x07\b\f\v');
    });

    test('reads every character an unquoted string may hold', () {
      const text = r'{ path = $SRCROOT/y:z.a-b+c_d; data = <0fab 12>; }';
      final root = parsePbxPlist(text).root;

      expect(root.string('path'), r'$SRCROOT/y:z.a-b+c_d');
      expect(_source(text, root['data']! as PbxData), '<0fab 12>');
    });

    test('resolves a duplicated key to its last value', () {
      const text = '{ a = first; list = (x); a = last; list = (y); }';
      final root = parsePbxPlist(text).root;

      expect(root.string('a'), 'last');
      expect(root.array('list')!.strings, ['y']);
      expect(_source(text, root.entry('a')!.value), 'last');
    });

    test('records the spans edits splice at', () {
      const text = '''
{
	objects = {
		ABC /* Title */ = {isa = PBXGroup; children = (X /* x */, Y, ); };
	};
}
''';
      final result = parsePbxPlist(text);
      final objects = result.root.dict('objects')!;
      final entry = objects.entries.single;

      expect(
        text.substring(entry.start, entry.end),
        'ABC /* Title */ = {isa = PBXGroup; children = (X /* x */, Y, ); };',
      );
      expect(entry.key.comment!.text, 'Title');
      expect(
        text.substring(entry.key.comment!.start, entry.key.comment!.end),
        '/* Title */',
      );

      final children = (entry.value as PbxDict).array('children')!;
      expect(_source(text, children), '(X /* x */, Y, )');
      final first = children.items.first;
      expect(text.substring(first.start, first.textEnd), 'X /* x */');
      expect(text.substring(first.start, first.end), 'X /* x */,');
      expect(result.comments.map((c) => c.text), ['Title', 'x']);
    });

    test('keeps the last array element without a trailing comma', () {
      const text = '{ list = (a, b /* b */); nested = ((c)); }';
      final root = parsePbxPlist(text).root;
      final list = root.array('list')!;

      expect(list.strings, ['a', 'b']);
      expect(
        text.substring(list.items.last.start, list.items.last.end),
        'b /* b */',
      );
      final nested = root.array('nested')!.items.single;
      expect(text.substring(nested.start, nested.end), '(c)');
      expect(nested.textEnd, nested.end);
    });

    group('rejects a property list Xcode did not write', () {
      for (final (label, text) in const [
        ('XML', '<?xml version="1.0" encoding="UTF-8"?>\n<plist/>'),
        ('an XML doctype', '<!DOCTYPE plist>\n<plist/>'),
        ('a bare plist element', '\n<plist version="1.0"><dict/></plist>'),
        ('JSON', '{"archiveVersion" : "1", "objects" : {}}'),
        ('JSON with escapes', ' {\n  "a\\"b":{}}'),
      ]) {
        test(label, () {
          expect(
            () => parsePbxPlist(text),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('not in the format Xcode writes'),
                  contains('opening and saving the project in Xcode'),
                ),
              ),
            ),
          );
        });
      }

      test('but reads a quoted first key', () {
        final root = parsePbxPlist('{ "a:b" = c; }').root;

        expect(root.string('a:b'), 'c');
      });
    });

    group('reports malformed input with its line', () {
      void expectFailure(String text, String message, int line, [int? column]) {
        expect(
          () => parsePbxPlist(text),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains(message),
                contains(
                  column == null ? 'line $line' : 'line $line, column $column)',
                ),
              ),
            ),
          ),
        );
      }

      test('a missing semicolon, at the end of the value', () {
        expectFailure('{\n\ta = b;\n\tc = d\n}', 'Expected ";"', 3, 7);
        expectFailure(
          '{\n\tc = d /* title */\n}',
          'Expected ";"',
          2,
          19,
        );
      });

      test('a missing equals sign', () {
        expectFailure('{\n\ta b;\n}', 'Expected "="', 2);
      });

      test('an unterminated string', () {
        expectFailure('{\n\ta = "open;\n}', 'Unterminated string', 2);
      });

      test('an unterminated comment', () {
        expectFailure('{\n/* open\n}', 'Unterminated comment', 2);
      });

      test('an unterminated array', () {
        expectFailure('{\n\ta = (b,\n', 'Unterminated array', 2);
      });

      test('content after the top-level dictionary', () {
        expectFailure('{\n}\n}', 'after the top-level dictionary', 3);
      });

      test('something that is not a dictionary', () {
        expectFailure('(a)', 'Expected "{"', 1);
      });

      test('a missing value', () {
        expectFailure(
          '{\n\ta = ;\n}',
          'Unexpected ";", expected the value of "a"',
          2,
        );
      });

      test('an unterminated dictionary', () {
        expectFailure('{\n\ta = b;\n', 'Unterminated dictionary', 1);
      });

      test('something that is not a key', () {
        expectFailure('{\n\t(a) = b;\n}', 'expected a key or "}"', 2);
      });

      test('array elements without a comma between them', () {
        expectFailure('{\n\ta = (b c);\n}', 'Expected "," or ")"', 2, 8);
        expectFailure(
          '{\n\ta = (\n\t\t{}\n\t\tc\n\t);\n}',
          'Expected "," or ")"',
          3,
          5,
        );
      });

      test(r'a \U escape without hex digits', () {
        expectFailure('{\n\ta = "\\Uzz";\n}', r'hex digits after "\U"', 2);
      });
    });
  });

  group('Pbxproj', () {
    const project = r'''
// !$*UTF8*$!
{
	objects = {

/* Begin PBXNativeTarget section */
		NEXT00000000000000000001 /* Anything */ = {
			buildConfigurationList = LIST /* list */;
			isa = PBXNativeTarget;
			name = Runner;
		};
		97C146F01CF9000F007C117D /* Runner */ = {
			isa = PBXGroup;
			name = Runner;
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		PROJECT = {
			isa = PBXProject;
		};
/* End PBXProject section */
		LIST = {
			isa = XCConfigurationList;
			buildConfigurations = (
				CFG1,
				MISSING,
			);
		};
		CFG1 = {
			name = "Debug-next";
			buildSettings = {
				LIST_VALUE = (
					"$(inherited)",
					FLAG,
				);
				"KEY[sdk=iphoneos*]" = conditional;
				PLAIN = value;
			};
			isa = XCBuildConfiguration;
		};
	};
	rootObject = PROJECT;
}
''';

    test('indexes objects by any id and finds them by field', () {
      final pbxproj = Pbxproj.parse(project);

      expect(pbxproj.rootProject!.id, 'PROJECT');
      final runner = pbxproj.nativeTargetNamed('Runner')!;
      expect(runner.id, 'NEXT00000000000000000001');
      expect(
        pbxproj.buildConfigurationsOf(runner).map((c) => c.id),
        ['CFG1'],
      );
      expect(pbxproj.objectsOfIsa('PBXGroup').single.string('name'), 'Runner');
    });

    test('reads build settings whatever the field order', () {
      final config = Pbxproj.parse(project).object('CFG1')!;

      expect(config.string('name'), 'Debug-next');
      expect(ownBuildSettings(config), {
        'LIST_VALUE': r'$(inherited) FLAG',
        'PLAIN': 'value',
      });
    });

    test('finds the section markers inside objects', () {
      final sections = Pbxproj.parse(project).sections;

      expect(sections.map((s) => s.isa), ['PBXNativeTarget', 'PBXProject']);
      expect(sections.every((s) => s.end != null), isTrue);
    });

    test('falls back to the only PBXProject without a rootObject', () {
      final pbxproj = Pbxproj.parse(
        project.replaceFirst('\trootObject = PROJECT;\n', ''),
      );

      expect(pbxproj.rootProject!.id, 'PROJECT');
    });

    test('finds an object by id only when it has the class asked for', () {
      final pbxproj = Pbxproj.parse(project);

      expect(pbxproj.objectOfIsa('CFG1', 'XCBuildConfiguration')!.id, 'CFG1');
      expect(pbxproj.objectOfIsa('CFG1', 'PBXGroup'), isNull);
      expect(pbxproj.objectOfIsa(null, 'PBXGroup'), isNull);
    });

    test('keeps the last copy of a duplicated object', () {
      final pbxproj = Pbxproj.parse(
        '{ objects = { X = {isa = PBXGroup; }; X = {isa = PBXFileReference; }; '
        '}; }',
      );

      expect(pbxproj.objects.keys, ['X']);
      expect(pbxproj.object('X')!.isa, 'PBXFileReference');
    });

    test('walks every node in source order', () {
      const text = '{ objects = { X = {isa = PBXGroup; data = <0fab>; '
          'list = (<12>, Y, (Z)); }; }; }';
      final pbxproj = Pbxproj.parse(text);

      expect(
        pbxproj.nodes.skip(1).map((node) => _source(text, node)),
        [
          'objects',
          '{ X = {isa = PBXGroup; data = <0fab>; list = (<12>, Y, (Z)); }; }',
          'X',
          '{isa = PBXGroup; data = <0fab>; list = (<12>, Y, (Z)); }',
          'isa',
          'PBXGroup',
          'data',
          '<0fab>',
          'list',
          '(<12>, Y, (Z))',
          '<12>',
          'Y',
          '(Z)',
          'Z',
        ],
      );
      expect(pbxproj.nodes.first, pbxproj.root);
    });

    test('rejects a file without an objects dictionary', () {
      expect(
        () => Pbxproj.parse('{ rootObject = X; }'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses every committed example project', () async {
      final fixtures = (await pbxprojFixturesDirectory())
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.pbxproj'));
      expect(fixtures, isNotEmpty);

      for (final file in fixtures) {
        final text = file.readAsStringSync();
        final pbxproj = Pbxproj.parse(text);
        expect(pbxproj.rootProject, isNotNull, reason: file.path);
        for (final object in pbxproj.objects.values) {
          expect(
            text.substring(object.entry.start, object.entry.end),
            allOf(startsWith(object.id), endsWith(';')),
            reason: file.path,
          );
        }
      }
    });
  });
}
