import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/test_flutter_project.dart';

Matcher _throwsMessage(Matcher message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );

void main() {
  group('parseInteractionHandler', () {
    late TestFlutterProject project;
    late AnalysisContextCollection collection;

    setUpAll(() async {
      project = await TestFlutterProject.create();
      collection = AnalysisContextCollection(
        includedPaths: [project.root.path],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );
    });

    setUp(useMockLogger);

    Future<List<WidgetSpec>> parseFile(
      String name,
      String source, {
      String directory = 'lib',
    }) async {
      final file = File(p.join(project.root.path, directory, '$name.dart'));
      await file.parent.create(recursive: true);
      await file.writeAsString(source);
      return parseSchemaFile(file.path, collection: collection);
    }

    /// Parses the schema `<name>_schema.dart` of a `Counter` widget with one
    /// button, next to the library `lib/<name>_handlers.dart` holding
    /// [handlers] when there are any.
    Future<WidgetSpec> parseCounter(
      String name, {
      String? onInteraction,
      String? handlers,
      String declarations = '',
      String directory = 'lib',
      bool button = true,
    }) async {
      if (handlers != null) {
        final library =
            File(p.join(project.root.path, 'lib', '${name}_handlers.dart'));
        await library.writeAsString(handlers);
      }

      final specs = await parseFile(
        '${name}_schema',
        '''
import 'package:home_widget_generator/home_widget_generator.dart';
${handlers == null ? '' : "import 'package:cli_test/${name}_handlers.dart';"}

@HomeWidget(
  name: 'Counter',
  ${onInteraction == null ? '' : 'onInteraction: $onInteraction,'}
  widget: ${button ? "HWButton('increment', child: HWText(HWString.fixed('+')))" : "HWText(HWString.fixed('label'))"},
)
class Counter {}

$declarations
''',
        directory: directory,
      );
      return specs.single;
    }

    group('reads', () {
      test('no function from an annotation without onInteraction', () async {
        final spec = await parseCounter('none', button: false);

        expect(spec.interactionHandler, isNull);
        expect(spec.hasInteractions, isFalse);
      });

      test('a top-level function taking a class not generated yet', () async {
        final spec = await parseCounter(
          'first_run',
          onInteraction: 'onCounterInteraction',
          handlers: '''
Future<void> onCounterInteraction(CounterInteraction interaction) async {}
''',
        );

        final handler = spec.interactionHandler!;
        expect(handler.libraryUri, 'package:cli_test/first_run_handlers.dart');
        expect(handler.name, 'onCounterInteraction');
        expect(handler.className, isNull);
        expect(handler.returnsFuture, isTrue);
        expect(handler.reference, 'onCounterInteraction');
        expect(spec.hasInteractions, isTrue);
        expect(spec.buttons.single.id, 'increment');
      });

      test('a function a widget without a button never calls', () async {
        final spec = await parseCounter(
          'no_button',
          onInteraction: 'onCounterInteraction',
          handlers: '''
Future<void> onCounterInteraction(CounterInteraction interaction) async {}
''',
          button: false,
        );

        expect(spec.interactionHandler?.name, 'onCounterInteraction');
        expect(spec.hasInteractions, isFalse);
      });

      test('a function returning void as one not to wait for', () async {
        final spec = await parseCounter(
          'returns_void',
          onInteraction: 'onTap',
          handlers: 'void onTap(CounterInteraction interaction) {}',
        );

        expect(spec.interactionHandler?.returnsFuture, isFalse);
      });

      test('a function returning FutureOr<void> as one to wait for', () async {
        final spec = await parseCounter(
          'returns_future_or',
          onInteraction: 'onTap',
          handlers: '''
import 'dart:async';

FutureOr<void> onTap(CounterInteraction interaction) {}
''',
        );

        expect(spec.interactionHandler?.returnsFuture, isTrue);
      });

      test('a static function with the class declaring it', () async {
        final spec = await parseCounter(
          'static_method',
          onInteraction: 'Handlers.onTap',
          handlers: '''
void onTap(Uri uri) {}

void onOther(Uri uri) {}

class Other {
  void onTap(Uri uri) {}

  static int get tapCount => 0;
}

class Handlers {
  static void onOther(Uri uri) {}

  static Future<void> onTap(CounterInteraction interaction) async {}
}
''',
        );

        final handler = spec.interactionHandler!;
        expect(
          handler.libraryUri,
          'package:cli_test/static_method_handlers.dart',
        );
        expect(handler.name, 'onTap');
        expect(handler.className, 'Handlers');
        expect(handler.reference, 'Handlers.onTap');
        expect(handler.returnsFuture, isTrue);
      });

      test('a top-level function next to methods of its name', () async {
        final spec = await parseCounter(
          'next_to_methods',
          onInteraction: 'onTap',
          handlers: '''
class Handlers {
  static void onTap(Uri uri) {}
}

void onOther(Uri uri) {}

void onTap(CounterInteraction interaction) {}
''',
        );

        expect(spec.interactionHandler?.reference, 'onTap');
      });

      test('a static function next to one of its name in another class',
          () async {
        final spec = await parseCounter(
          'same_name_classes',
          onInteraction: 'Handlers.onTap',
          handlers: '''
class Other {
  static void onTap(Uri uri) {}
}

class Handlers {
  static void onTap(CounterInteraction interaction) {}
}
''',
        );

        expect(spec.interactionHandler?.reference, 'Handlers.onTap');
      });

      test('a top-level function next to a local one of its name', () async {
        final spec = await parseCounter(
          'local_function',
          onInteraction: 'onTap',
          handlers: '''
void helper() {
  void onTap(Uri uri) {}
  onTap(Uri());
}

void onTap(CounterInteraction interaction) {}
''',
        );

        expect(spec.interactionHandler?.reference, 'onTap');
      });

      test('no function from an explicit null', () async {
        final spec = await parseCounter(
          'explicit_null',
          onInteraction: 'null',
          button: false,
        );

        expect(spec.interactionHandler, isNull);
      });

      test('a function through a prefixed import and annotation', () async {
        await File(p.join(project.root.path, 'lib', 'prefixed_handlers.dart'))
            .writeAsString('void onTap(CounterInteraction interaction) {}');

        final specs = await parseFile(
          'prefixed_schema',
          '''
import 'package:cli_test/prefixed_handlers.dart' as handlers;
import 'package:home_widget_generator/home_widget_generator.dart' as hw;

@deprecated
@hw.HomeWidget(
  name: 'Counter',
  onInteraction: handlers.onTap,
  widget: hw.HWButton('increment', child: hw.HWText(hw.HWString.fixed('+'))),
)
class Counter {}
''',
        );

        final handler = specs.single.interactionHandler!;
        expect(handler.libraryUri, 'package:cli_test/prefixed_handlers.dart');
        expect(handler.reference, 'onTap');
      });

      test('the function of each widget of a file', () async {
        await File(p.join(project.root.path, 'lib', 'two_handlers.dart'))
            .writeAsString('void onTimer(TimerInteraction interaction) {}');

        final specs = await parseFile(
          'two_schema',
          '''
import 'package:cli_test/two_handlers.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(name: 'Counter', widget: HWText(HWString.fixed('label')))
class Counter {}

@HomeWidget(
  name: 'Timer',
  onInteraction: onTimer,
  widget: HWButton('start', child: HWText(HWString.fixed('Start'))),
)
class Timer {}
''',
        );

        expect(specs.map((spec) => spec.className), ['Counter', 'Timer']);
        expect(specs.first.interactionHandler, isNull);
        expect(specs.last.interactionHandler?.name, 'onTimer');
        expect(specs.last.interactionClassName, 'TimerInteraction');
      });
    });

    group('accepts a parameter', () {
      const parameters = <String, String>{
        'dynamic': 'dynamic interaction',
        'object': 'Object interaction',
        'untyped': 'interaction',
        'nullable': 'CounterInteraction? interaction',
        'final': 'final CounterInteraction interaction',
        'prefixed': 'generated.CounterInteraction interaction',
        'optional': '[CounterInteraction? interaction]',
        'defaulted': '[CounterInteraction? interaction = null]',
        'var': 'var interaction',
        'final_untyped': 'final interaction',
        'annotated': '@deprecated CounterInteraction interaction',
        'alias': 'Alias interaction',
        'not_generated_yet': 'SomethingUnresolved interaction',
      };

      for (final MapEntry(key: name, value: parameter) in parameters.entries) {
        test('written as $parameter', () async {
          final spec = await parseCounter(
            'parameter_$name',
            onInteraction: 'onTap',
            handlers: '''
import 'package:cli_test/parameter_${name}_generated.dart' as generated;

typedef Alias = CounterInteraction;

void onTap($parameter) {}
''',
          );

          expect(spec.interactionHandler?.name, 'onTap');
          expect(
            spec.interactionHandler?.libraryUri,
            'package:cli_test/parameter_${name}_handlers.dart',
          );
        });
      }

      test('typed through a typedef of the generated class', () async {
        final spec = await parseCounter(
          'parameter_resolved_alias',
          onInteraction: 'onTap',
          handlers: '''
class CounterInteraction {}

typedef Alias = CounterInteraction;

void onTap(@deprecated Alias? interaction) {}
''',
        );

        expect(spec.interactionHandler?.name, 'onTap');
      });
    });

    group('rejects an onInteraction that is no constant', () {
      const values = <String, String>{
        'closure': '(interaction) {}',
        'instance_method': 'const Handlers().onTap',
        'final_variable': 'handler',
        'getter': 'Handlers.current',
        'missing': 'doesNotExist',
      };

      for (final MapEntry(key: name, :value) in values.entries) {
        test('written as $value', () async {
          await expectLater(
            parseCounter(
              'not_constant_$name',
              onInteraction: value,
              handlers: '''
class Handlers {
  const Handlers();

  static void Function(Object) get current => (interaction) {};

  void onTap(Object interaction) {}
}

final void Function(Object) handler = (interaction) {};
''',
            ),
            _throwsMessage(
              allOf(
                contains('not_constant_${name}_schema.dart: the @HomeWidget '),
                contains('does not compile'),
                contains(
                  'onInteraction has to be a compile-time constant: pass a '
                  'top-level or static function by name',
                ),
              ),
            ),
          );
        });
      }

      test('without the hint when another value is at fault', () async {
        await expectLater(
          parseFile('not_constant_elsewhere_schema', '''
import 'package:home_widget_generator/home_widget_generator.dart';

void onTap(Object interaction) {}

@HomeWidget(name: unknownName, onInteraction: onTap)
class Counter {}
'''),
          _throwsMessage(
            allOf(
              contains('does not compile'),
              isNot(contains('onInteraction has to be')),
            ),
          ),
        );
      });
    });

    group('rejects', () {
      test('a constructor', () async {
        await expectLater(
          parseCounter(
            'constructor',
            onInteraction: 'Handlers.new',
            handlers: '''
class Handlers {
  const Handlers(Object interaction);
}
''',
          ),
          _throwsMessage(
            allOf(
              startsWith('Widget "Counter": onInteraction names Handlers'),
              contains('which is not a top-level or static function.'),
              contains('without an instance of anything'),
            ),
          ),
        );
      });

      test('a private function', () async {
        await expectLater(
          parseCounter(
            'private_function',
            onInteraction: '_onTap',
            declarations: 'void _onTap(CounterInteraction interaction) {}',
          ),
          _throwsMessage(
            allOf(
              startsWith(
                'Widget "Counter": onInteraction names _onTap, which is '
                'private.',
              ),
              contains('so make it public'),
            ),
          ),
        );
      });

      test('a static function of a private class', () async {
        await expectLater(
          parseCounter(
            'private_class',
            onInteraction: '_Handlers.onTap',
            declarations: '''
class _Handlers {
  static void onTap(CounterInteraction interaction) {}
}
''',
          ),
          _throwsMessage(
            contains('onInteraction names _Handlers.onTap, which is private.'),
          ),
        );
      });

      test('a private static function', () async {
        await expectLater(
          parseCounter(
            'private_method',
            onInteraction: 'Handlers._onTap',
            declarations: '''
class Handlers {
  static void _onTap(CounterInteraction interaction) {}
}
''',
          ),
          _throwsMessage(
            contains('onInteraction names Handlers._onTap, which is private.'),
          ),
        );
      });

      test('a function declared outside lib/', () async {
        await expectLater(
          parseCounter(
            'outside_lib',
            onInteraction: 'onTap',
            declarations: 'void onTap(CounterInteraction interaction) {}',
            directory: 'schemas',
          ),
          _throwsMessage(
            allOf(
              startsWith(
                'Widget "Counter": onInteraction names onTap, declared in '
                'file://',
              ),
              contains('outside_lib_schema.dart'),
              contains(
                'declare it in a library under lib/ and import that library '
                'in the schema file.',
              ),
            ),
          ),
        );
      });

      test('a function not taking exactly one positional parameter', () async {
        const parameters = <String, String>{
          'none': '',
          'two': 'CounterInteraction interaction, int count',
          'named': '{CounterInteraction? interaction}',
          'required_named': '{required CounterInteraction interaction}',
        };

        for (final MapEntry(key: name, value: parameter)
            in parameters.entries) {
          await expectLater(
            parseCounter(
              'arity_$name',
              onInteraction: 'onTap',
              handlers: 'void onTap($parameter) {}',
            ),
            _throwsMessage(
              equals(
                'Widget "Counter": onInteraction names onTap, which has to '
                'take exactly one positional parameter: the '
                'CounterInteraction that was tapped.',
              ),
            ),
            reason: parameter,
          );
        }
      });

      test('a function returning a value', () async {
        const returnTypes = <String, String>{
          'int': 'int',
          'future_int': 'Future<int>',
          'nullable_future': 'Future<void>?',
        };

        for (final MapEntry(key: name, value: returnType)
            in returnTypes.entries) {
          await expectLater(
            parseCounter(
              'returns_$name',
              onInteraction: 'Handlers.onTap',
              handlers: '''
class Handlers {
  static $returnType onTap(CounterInteraction interaction) => throw 0;
}
''',
            ),
            _throwsMessage(
              equals(
                'Widget "Counter": onInteraction names Handlers.onTap, which '
                'returns $returnType. Return void, Future<void> or '
                'FutureOr<void>.',
              ),
            ),
            reason: returnType,
          );
        }
      });

      test('a function taking something else', () async {
        const parameters = <String, (String, String)>{
          'uri': ('Uri uri', 'Uri'),
          'other_widget': ('TimerInteraction interaction', 'TimerInteraction'),
          'nullable': ('final String? id', 'String?'),
          'generic': ('List<int> ids', 'List<int>'),
          'alias': ('Alias uri', 'Uri'),
        };

        for (final MapEntry(key: name, value: (parameter, type))
            in parameters.entries) {
          await expectLater(
            parseCounter(
              'takes_$name',
              onInteraction: 'onTap',
              handlers: '''
class TimerInteraction {}

typedef Alias = Uri;

void onTap($parameter) {}
''',
            ),
            _throwsMessage(
              equals(
                'Widget "Counter": onInteraction names onTap, whose parameter '
                'is a $type. It is called with the generated '
                'CounterInteraction, so take that.',
              ),
            ),
            reason: parameter,
          );
        }
      });
    });
  });
}
