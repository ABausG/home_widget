import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/parser/widget_value_decoder.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Every schema this file decodes, in one source file.
///
/// Icons are the one part of the DSL whose values come out of Flutter itself,
/// so these go through the analyzer rather than building a tree by hand. They
/// share a file, and with it a single resolution of `package:flutter`, which
/// each context of its own would pay for again.
const _schemas = '''
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

const _new = IconData(0xe001, fontFamily: 'MaterialIcons');
const values = IconData(0xe002, fontFamily: 'MaterialIcons');

@HomeWidget(
  name: 'FixedIcon',
  widget: HWIcon.fixed(Icons.wb_sunny, size: 32, semanticLabel: 'Sunny'),
)
class FixedIcon {}

@HomeWidget(
  name: 'PackageIcon',
  widget: HWIcon.fixed(CupertinoIcons.sun_max),
)
class PackageIcon {}

@HomeWidget(
  name: 'NotAnIcon',
  widget: HWIcon.fixed('Icons.wb_sunny'),
)
class NotAnIcon {}

@HomeWidget(
  name: 'BoundIcon',
  widget: HWIcon(
    HWIconData(
      'mood',
      icons: [Icons.wb_sunny, Icons.cloud, Icons.home_rounded],
      defaultValue: Icons.cloud,
      previewValue: Icons.wb_sunny,
    ),
  ),
)
class BoundIcon {}

@HomeWidget(
  name: 'DirectionalIcon',
  widget: HWIcon.fixed(Icons.arrow_back),
)
class DirectionalIcon {}

@HomeWidget(
  name: 'DirectionalIcons',
  widget: HWIcon(
    HWIconData(
      'arrow',
      icons: [Icons.arrow_forward, Icons.cloud, Icons.arrow_back],
    ),
  ),
)
class DirectionalIcons {}

@HomeWidget(
  name: 'InlineIcon',
  widget: HWIcon(
    HWIconData('mood', icons: [IconData(0xe88a, fontFamily: 'MaterialIcons')]),
  ),
)
class InlineIcon {}

@HomeWidget(
  name: 'ReservedNames',
  widget: HWIcon(HWIconData('mood', icons: [_new, values])),
)
class ReservedNames {}

@HomeWidget(
  name: 'WrappedIcon',
  widget: HWIcon(
    HWTimedData(
      HWJson('weather', HWIconData('condition', icons: [Icons.cloud])),
    ),
  ),
)
class WrappedIcon {}

@HomeWidget(
  name: 'MixedFonts',
  widget: HWIcon(
    HWIconData('mood', icons: [Icons.cloud, CupertinoIcons.sun_max]),
  ),
)
class MixedFonts {}

@HomeWidget(
  name: 'NoIcons',
  widget: HWIcon(HWIconData('mood', icons: [])),
)
class NoIcons {}

@HomeWidget(
  name: 'ForeignDefault',
  widget: HWIcon(
    HWIconData('mood', icons: [Icons.cloud], defaultValue: Icons.wb_sunny),
  ),
)
class ForeignDefault {}

@HomeWidget(
  name: 'NotAnIconValue',
  widget: HWIcon(HWIconData('mood', icons: ['sunny'])),
)
class NotAnIconValue {}

@HomeWidget(
  name: 'NotAnIconDefault',
  widget: HWIcon(
    HWIconData('mood', icons: [Icons.cloud], defaultValue: 'Icons.cloud'),
  ),
)
class NotAnIconDefault {}

@HomeWidget(
  name: 'NotAnIconPreview',
  widget: HWIcon(
    HWIconData('mood', icons: [Icons.cloud], previewValue: 0xe2bf),
  ),
)
class NotAnIconPreview {}

@HomeWidget(
  name: 'NullDefault',
  widget: HWIcon(
    HWIconData('mood', icons: [Icons.cloud], defaultValue: null),
  ),
)
class NullDefault {}

@HomeWidget(
  name: 'IconlessData',
  widget: HWIcon(HWString('label')),
)
class IconlessData {}

@HomeWidget(
  name: 'FamilyText',
  widget: HWText.fixed(
    'Hello',
    style: HWTextStyle(
      fontFamily: 'Chewy',
      package: 'my_fonts',
      fontWeight: HWFontWeight.bold,
    ),
  ),
)
class FamilyText {}

@HomeWidget(
  name: 'InheritedFamilyText',
  widget: HWText.fixed(
    'Hello',
    style: HWTextStyle(
      italic: true,
      baseStyle: HWRoleTextStyle.caption(fontFamily: 'Chewy'),
    ),
  ),
)
class InheritedFamilyText {}
''';

void main() {
  late Map<String, ElementAnnotation> annotations;
  late File file;

  setUpAll(() async {
    file = File(
      p.join(
        Directory.current.path,
        'test',
        'temp_icons_${DateTime.now().microsecondsSinceEpoch}.dart',
      ),
    );
    await file.writeAsString(_schemas);

    final collection = AnalysisContextCollection(
      includedPaths: [file.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final context = collection.contextFor(file.path);
    final result = await context.currentSession.getResolvedUnit(file.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('Failed to resolve');
    }

    annotations = {
      for (final element in result.unit.declaredFragment!.element.classes)
        element.name!: element.metadata.annotations.firstWhere(
          (m) => m.element?.enclosingElement?.name == 'HomeWidget',
        ),
    };
  });

  tearDownAll(() async {
    if (await file.exists()) await file.delete();
  });

  /// The decoded widget of the schema class [name], as a widget of the widget
  /// whose font resources are namespaced `hw_font_test_widget`.
  HWWidget widgetOf(String name) => WidgetValueDecoder(
        annotations[name]!.computeConstantValue()!.getField('widget'),
        fontResourcePrefix: 'hw_font_test_widget',
      ).decode();

  GeneratorError errorOf(String name) {
    try {
      widgetOf(name);
    } on GeneratorError catch (error) {
      return error;
    }
    throw StateError('Expected a GeneratorError for $name');
  }

  group('HWIcon.fixed', () {
    test('decodes a Flutter icon to its glyph and font', () {
      final icon = widgetOf('FixedIcon') as HWIcon;
      expect(icon.codePoint, isNotNull);
      expect(icon.font, const HWIconFont(family: 'MaterialIcons'));
      expect(icon.size, 32);
      expect(icon.semanticLabel, 'Sunny');
      expect(icon.iconCodePoints, {
        const HWIconFont(family: 'MaterialIcons'): {icon.codePoint},
      });
      expect(
        icon.toKotlin(0, dataExpr: 'data'),
        contains('R.font.hw_font_test_widget__icons_materialicons'),
      );
      expect(
        icon.toSwift(0, dataExpr: 'data'),
        contains('hwBundledFont("hw_font_icons_materialicons", size: 32)'),
      );
    });

    test('decodes an icon from a package', () {
      expect(
        (widgetOf('PackageIcon') as HWIcon).font,
        const HWIconFont(
          family: 'CupertinoIcons',
          package: 'cupertino_icons',
        ),
      );
    });

    test('rejects anything that is not an icon', () {
      expect(
        errorOf('NotAnIcon').message,
        contains('Could not decode HWIcon.fixed'),
      );
    });

    test('reads matchTextDirection off the icon', () {
      final directional = widgetOf('DirectionalIcon') as HWIcon;
      expect(directional.matchTextDirection, isTrue);
      expect(
        directional.toSwift(0, dataExpr: 'data'),
        contains(
          '.scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)',
        ),
      );
      expect(
        directional.toKotlin(0, dataExpr: 'data'),
        contains('matchTextDirection = true'),
      );

      expect((widgetOf('FixedIcon') as HWIcon).matchTextDirection, isFalse);
    });
  });

  group('HWIconData', () {
    test('decodes every icon to a named enum value', () {
      final widget = widgetOf('BoundIcon') as HWIcon;
      final icons = widget.iconData!;
      expect(
        icons.entries.map((entry) => entry.name),
        ['wbSunny', 'cloud', 'homeRounded'],
      );
      expect(icons.iconFont, const HWIconFont(family: 'MaterialIcons'));
      expect(icons.codePoints, hasLength(3));
      expect(icons.defaultValue, icons.entries[1].codePoint);
      expect(icons.previewValue, icons.entries[0].codePoint);
      expect(icons.enumNameFor('TestWidget'), 'TestWidgetMoodIcon');
      expect(widget.dataDependencies, {icons});
    });

    test('reads matchTextDirection off every icon of the list', () {
      final widget = widgetOf('DirectionalIcons') as HWIcon;
      final entries = widget.iconData!.entries;
      expect(
        entries.map((entry) => entry.matchTextDirection),
        [true, false, true],
      );
      expect(
        widget.iconData!.mirroredCodePoints,
        {entries[0].codePoint, entries[2].codePoint},
      );
      expect(
        widget.toKotlin(0, dataExpr: 'data'),
        contains('matchTextDirection = codePoint in hwMirroredIcons'),
      );
    });

    test('an inline icon declaring nothing is not directional', () {
      expect(
        (widgetOf('InlineIcon') as HWIcon)
            .iconData!
            .entries
            .single
            .matchTextDirection,
        isFalse,
      );
    });

    test('falls back to the codepoint when the icon has no name', () {
      expect(
        (widgetOf('InlineIcon') as HWIcon).iconData!.entries,
        [const HWIconEntry('icon0xE88A', 0xe88a)],
      );
    });

    test('suffixes a name that would collide in the generated enum', () {
      expect(
        (widgetOf('ReservedNames') as HWIcon)
            .iconData!
            .entries
            .map((entry) => entry.name),
        ['new_', 'values_'],
      );
    });

    test('reads an icon out of a JSON group and a timeline', () {
      final icon = widgetOf('WrappedIcon') as HWIcon;
      expect(icon.dataType, isA<HWTimedData<dynamic>>());
      expect(icon.iconData!.key, 'condition');
      expect(
        icon.toKotlin(0, dataExpr: 'data'),
        startsWith('data.weather?.condition?.let { codePoint ->'),
      );
    });

    test('rejects icons from more than one font', () {
      expect(
        errorOf('MixedFonts').message,
        contains('come from more than one font'),
      );
    });

    test('rejects an empty icon list', () {
      expect(
        errorOf('NoIcons').message,
        'HWIconData "mood" needs at least one icon.',
      );
    });

    test('rejects a default that is not one of the icons', () {
      expect(
        errorOf('ForeignDefault').message,
        'The defaultValue of HWIconData "mood" is not one of its icons.',
      );
    });

    test('rejects a value that is not an icon', () {
      expect(
        errorOf('NotAnIconValue').message,
        contains('takes Flutter IconData values'),
      );
    });

    test('rejects a default or preview that is not an icon', () {
      expect(
        errorOf('NotAnIconDefault').message,
        contains('The defaultValue of HWIconData "mood" takes a Flutter '
            'IconData'),
      );
      expect(
        errorOf('NotAnIconPreview').message,
        contains('The previewValue of HWIconData "mood" takes a Flutter '
            'IconData'),
      );
    });

    test('reads an explicit null default as no default', () {
      expect(
        (widgetOf('NullDefault') as HWIcon).iconData!.defaultValue,
        isNull,
      );
    });

    test('rejects an icon bound to something else', () {
      expect(
        errorOf('IconlessData').message,
        contains('HWIcon requires an HWIconData'),
      );
    });
  });

  group('HWTextStyle', () {
    test('decodes a font family and keys the asset lookup on it', () {
      final text = widgetOf('FamilyText') as HWText;
      expect(text.style!.fontFamily, 'Chewy');
      expect(text.style!.package, 'my_fonts');
      expect(text.fontVariants, {
        const HWFontVariant(
          family: 'Chewy',
          package: 'my_fonts',
          weight: 700,
          italic: false,
        ),
      });
      expect(
        text.toKotlin(0, dataExpr: 'data'),
        contains(
          'HomeWidgetFonts.typeface(context, "packages/my_fonts/Chewy", '
          '700, false)',
        ),
      );
      expect(
        text.toSwift(0, dataExpr: 'data'),
        contains('hwFont("packages/my_fonts/Chewy", 700, false, 16)'),
      );
    });

    test('decodes a family declared on a base style', () {
      final text = widgetOf('InheritedFamilyText') as HWText;
      expect(
        text.fontVariant,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: true),
      );
      expect(text.style!.effectiveFontSize, 12);
      final kotlin = text.toKotlin(0, dataExpr: 'data');
      expect(
        kotlin,
        contains('HomeWidgetFonts.typeface(context, "Chewy", 400, true)'),
      );
      expect(kotlin, contains('fontSizeSp = 12f,'));
      expect(kotlin, contains('italic = true,'));
    });
  });
}
