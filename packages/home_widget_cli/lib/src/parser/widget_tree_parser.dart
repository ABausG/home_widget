import 'package:analyzer/dart/element/element.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';

/// Parses a widget expression using the generator's parser.
///
/// This delegate allows the CLI to reuse the robust analyzer-based parsing logic
/// defined in `home_widget_generator`.
HWWidget parseWidgetAnnotation(ElementAnnotation annotation) {
  return WidgetTreeParser(annotation).parse();
}
