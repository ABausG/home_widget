import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../generators/android_generator.dart';
import '../generators/dart_helper_generator.dart';
import '../generators/ios_generator.dart';
import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../parser/schema_parser.dart';
import '../util/cli_thanks.dart';
import '../util/dependencies.dart';
import '../util/exit_codes.dart';
import '../util/logger.dart';

/// Command that generates native widget code from annotated Dart schemas.
class GenerateCommand extends Command<int> {
  @override
  String get name => 'generate';

  @override
  String get description => 'Generate native widget code from a schema file.';

  /// Creates a new [GenerateCommand].
  GenerateCommand() {
    argParser.addOption(
      'input',
      abbr: 'i',
      help: 'Path to schema file or directory. Defaults to home_widget/',
    );
    argParser.addOption(
      'dart-out',
      help: 'Output path for the generated Dart helper. '
          'Can be a .dart file path or a directory.',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      hide: true,
      help: 'Enable verbose output.',
    );
  }

  @override
  Future<int> run() async {
    final input = argResults?['input'] as String? ?? 'home_widget';
    final absoluteInput = p.absolute(input);
    final inputEntity = FileSystemEntity.isDirectorySync(absoluteInput)
        ? Directory(absoluteInput)
        : File(absoluteInput);

    if (!inputEntity.existsSync()) {
      logger.err('Input path "$input" does not exist.');
      return ExitCodes.noInput;
    }

    // Initialize AnalysisContextCollection
    // We include the root of the input to ensure context covers it.
    // If input is a file, we use its directory.
    // If input is a dir, we use it directly.
    final rootPath = inputEntity is Directory
        ? inputEntity.path
        : p.dirname(inputEntity.path);
    final collection = AnalysisContextCollection(
      includedPaths: [rootPath],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final specs = <({String path, WidgetSpec spec})>[];

    Future<void> processFile(File file) async {
      if (!file.path.endsWith('.dart')) return;
      try {
        final fileSpecs =
            await parseSchemaFile(file.path, collection: collection);
        if (fileSpecs.isEmpty && inputEntity is File) {
          logger.warn('No @HomeWidget annotation found in ${file.path}');
        }
        for (final spec in fileSpecs) {
          specs.add((path: file.path, spec: spec));
          logger.detail('Parsed ${spec.data.name} from ${file.path}');
        }
      } on GeneratorError catch (e) {
        logger.err(e.message);
        rethrow;
      } catch (e) {
        // coverage:ignore-start
        logger.err('Error parsing ${file.path}: $e');
        // We continue processing other files
        // coverage:ignore-end
      }
    }

    try {
      if (inputEntity is Directory) {
        await for (final file in inputEntity.list(recursive: true)) {
          if (file is File) {
            await processFile(file);
          }
        }
      } else if (inputEntity is File) {
        await processFile(inputEntity);
      }
    } on GeneratorError {
      return ExitCodes.software;
    }

    if (specs.isEmpty) {
      logger.info('No @HomeWidget annotated classes found.');
      return ExitCodes.success;
    }

    for (final item in specs) {
      final spec = item.spec;
      final path = item.path;

      final dartOutOption = argResults?['dart-out'] as String?;
      final specDartOutput = spec.data.dartOutput;
      final autoFileName =
          '${p.basenameWithoutExtension(path)}.home_widget.dart';

      final String dartOutPath;
      if (dartOutOption != null) {
        dartOutPath = _resolveDartOutPath(dartOutOption, autoFileName);
      } else if (specDartOutput != null) {
        dartOutPath = _resolveDartOutPath(specDartOutput, autoFileName);
      } else {
        dartOutPath = p.join('lib', 'src', 'home_widget', autoFileName);
      }

      final steps = <({String label, Future<void> Function() run})>[
        if (spec.data.android != null)
          (
            label: 'Generating Android widget',
            run: () =>
                AndroidGenerator(spec: spec, projectRoot: Directory.current)
                    .generate(),
          ),
        if (spec.data.iOS != null)
          (
            label: 'Generating iOS widget',
            run: () => IosGenerator(spec: spec, projectRoot: Directory.current)
                .generate(),
          ),
        (
          label: 'Generating Dart helper',
          run: () async {
            final dartHelperGenerator = DartHelperGenerator(spec);
            final dartHelperContent = dartHelperGenerator.generate();
            final dartOutFile = File(dartOutPath);
            await dartOutFile.parent.create(recursive: true);
            await dartOutFile.writeAsString(dartHelperContent);
          },
        ),
      ];

      final total = steps.length;
      final base = 'Generating ${spec.data.name} home_widget';
      final progress = logger.progress(base);
      for (var i = 0; i < steps.length; i++) {
        progress.update('$base · ${i + 1}/$total ${steps[i].label}');
        await steps[i].run();
      }
      progress.complete('Generated ${spec.data.name} home_widget');
    }

    // Ensure dependencies are present since generated code depends on home_widget
    await ensureFlutterHomeWidgetDependency(Directory.current);

    logGenerateSuccessThanks();
    return ExitCodes.success;
  }

  /// Resolves a `--dart-out` value to a full file path.
  ///
  /// - If [value] ends with `.dart`, it's treated as a file path.
  /// - Otherwise it's treated as a directory and [autoFileName] is appended.
  /// - Any other extension (e.g. `.txt`) throws a [FormatException].
  static String _resolveDartOutPath(String value, String autoFileName) {
    final ext = p.extension(value);
    if (ext == '.dart') {
      return value;
    }
    if (ext.isEmpty || FileSystemEntity.isDirectorySync(value)) {
      return p.join(value, autoFileName);
    }
    throw FormatException(
      'Invalid --dart-out value "$value". '
      'Must be a .dart file path or a directory.',
    );
  }
}
