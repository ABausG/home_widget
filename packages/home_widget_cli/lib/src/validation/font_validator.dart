import 'dart:io';

import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../util/font_resolver.dart';
import 'home_widget_version.dart';

/// The first `home_widget` release whose native side can render a custom font.
const String minimumFontHomeWidgetVersion = '0.10.0';

/// Verifies that every font and icon [spec] names can actually be generated for,
/// before a single file is written.
///
/// Three things have to hold: each icon field is a legal set of icons, every
/// icon font is on disk where the schema says it is, and every text font family
/// is declared in a pubspec this project can see and ships the file it names.
/// Resolution runs here rather than in the generators so a typo fails the whole
/// command instead of leaving one platform half-generated.
///
/// Whatever fails says which widget it failed for: the fonts of a project are
/// validated one widget at a time, and none of the errors raised below the
/// resolvers knows the widget it was reached from.
void validateFonts(WidgetSpec spec, Directory projectRoot) {
  try {
    _validateFonts(spec, projectRoot);
  } on GeneratorError catch (error) {
    throw GeneratorError('Widget "${spec.data.name}": ${error.message}');
  }
}

void _validateFonts(WidgetSpec spec, Directory projectRoot) {
  for (final field in spec.iconFields) {
    field.validate();
  }

  // Walking the tree for its icons is itself a check: an icon bound to
  // something that is not an [HWIconData] is rejected right here.
  final variants = spec.fontVariants;
  final iconFonts = spec.iconCodePoints.keys.toList();
  if (variants.isEmpty && iconFonts.isEmpty) return;

  requireHomeWidgetVersion(
    projectRoot,
    minimum: minimumFontHomeWidgetVersion,
    feature: 'this widget renders a custom font or an icon',
  );

  final fonts = FontResolver(projectRoot);
  for (final variant in variants) {
    final asset = fonts.resolveTextFont(variant);
    final file = fonts.resolveTextFontFile(variant);
    if (!file.existsSync()) {
      throw GeneratorError(
        'The font family "${variant.family}" is declared as "$asset", which '
        'does not exist at ${file.path}.',
      );
    }
  }
  for (final font in iconFonts) {
    fonts.resolveIconFont(font);
  }
}
