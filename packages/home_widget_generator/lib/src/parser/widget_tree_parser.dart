import 'package:analyzer/dart/element/element.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

import '../generator_error.dart';
import 'widget_value_decoder.dart';

/// Parses a @HomeWidget annotation into an [HWWidget].
///
/// This uses the analyzer to compute the constant value of the annotation
/// and then decodes it using [WidgetValueDecoder].
class WidgetTreeParser {
  final ElementAnnotation annotation;

  WidgetTreeParser(this.annotation);

  HWWidget parse() {
    final constantValue = annotation.computeConstantValue();
    if (constantValue == null) {
      throw GeneratorError('Could not compute constant value for annotation');
    }

    final widgetField = constantValue.getField('widget');
    if (widgetField == null || widgetField.isNull) {
      // It's valid to have no widget (maybe only android/ios config),
      // but typically we expect one if we are calling parse.
      // Or simpler: return null? No, let's throw for now if expected.
      // Actually, maybe we should return HWDataOnly if no widget is present but data is?
      // For now, let's assume if this is called, we expect a widget.
      throw GeneratorError(
        'HomeWidget annotation does not contain a widget definition',
      );
    }

    return WidgetValueDecoder(widgetField).decode();
  }
}
