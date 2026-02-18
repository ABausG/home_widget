import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../generators/android_generator.dart';
import '../generators/dart_helper_generator.dart';
import '../generators/ios_generator.dart';
import '../models/widget_spec.dart';
import '../parser/schema_parser.dart';
import '../util/logger.dart';
import '../util/dependencies.dart';
import '../util/exit_codes.dart';

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
      help: 'Output path for the generated Dart helper file.',
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
      logger.err('Error: Input path "$input" does not exist.');
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
          logger.info('Parsed ${spec.data.name} from ${file.path}');
        }
      } catch (e) {
        logger.err('Error parsing ${file.path}: $e');
        // We continue processing other files
      }
    }

    if (inputEntity is Directory) {
      await for (final file in inputEntity.list(recursive: true)) {
        if (file is File) {
          await processFile(file);
        }
      }
    } else if (inputEntity is File) {
      await processFile(inputEntity);
    }

    if (specs.isEmpty) {
      logger.info('No widgets found to generate.');
      return ExitCodes.success;
    }

    logger.info('Found ${specs.length} widget(s). Generating...');

    for (final item in specs) {
      final spec = item.spec;
      final path = item.path;

      // Generate Dart helper file
      logger.info('Generating Dart helper for ${spec.data.name}...');
      final dartHelperGenerator = DartHelperGenerator(spec);
      final dartHelperContent = dartHelperGenerator.generate();

      final dartOutOption = argResults?['dart-out'] as String?;
      final dartOutPath = dartOutOption ??
          spec.data.dartOutput ??
          p.join(
            'lib',
            'src',
            'home_widget',
            '${p.basenameWithoutExtension(path)}.home_widget.dart',
          );
      final dartOutFile = File(dartOutPath);
      await dartOutFile.parent.create(recursive: true);
      await dartOutFile.writeAsString(dartHelperContent);

      if (spec.data.android != null) {
        logger.info('Generating Android for ${spec.data.name}...');
        await AndroidGenerator(spec: spec, projectRoot: Directory.current)
            .generate();
      }
      if (spec.data.iOS != null) {
        logger.info('Generating iOS for ${spec.data.name}...');
        await IosGenerator(spec: spec, projectRoot: Directory.current)
            .generate();
      }
    }

    // Ensure dependencies are present since generated code depends on home_widget
    await ensureFlutterHomeWidgetDependency(Directory.current);

    return ExitCodes.success;
  }
}
