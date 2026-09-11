import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

/// Custom font and icon demo.
///
/// - `HWTextStyle(fontFamily: 'Chewy')` renders text in a font declared under
///   `flutter: fonts:` in `pubspec.yaml`. The font file itself stays where it
///   is: both platforms read it out of `flutter_assets`, so nothing is copied
///   next to the widget.
/// - `HWIcon.fixed(Icons.favorite)` renders one hardcoded Material icon. Icon
///   fonts are the exception to the above: Flutter tree-shakes them out of
///   `flutter_assets`, so the CLI copies the font next to the widget and
///   subsets it down to the glyphs this schema names.
/// - `HWIcon(HWIconData('mood', icons: [...]))` renders one icon out of a fixed
///   set, picked by the app via `saveData(mood: ...)`. The generated Dart
///   helper turns the list into a `FontAndIconsMoodIcon` enum, so the app never
///   deals with codepoints. Until the app saves one the widget falls back to
///   `defaultValue`, and the widget gallery shows `previewValue`.
/// - `Icons.arrow_forward` in that list declares `matchTextDirection`, so
///   picking it draws the arrow mirrored in a right-to-left layout, exactly as
///   Flutter's own `Icon` would.
@HomeWidget(
  name: 'Font & Icons',
  description: 'Text in a bundled font next to fixed and data-bound icons.',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWColumn(
    mainAxisAlignment: HWMainAxisAlignment.center,
    crossAxisAlignment: HWCrossAxisAlignment.center,
    children: [
      HWText.fixed(
        'Chewy',
        style: HWTextStyle(fontFamily: 'Chewy', fontSize: 24),
      ),
      HWRow(
        mainAxisAlignment: HWMainAxisAlignment.center,
        crossAxisAlignment: HWCrossAxisAlignment.center,
        children: [
          HWIcon.fixed(
            Icons.favorite,
            size: 24,
            color: HWFixedColor(0xFFE53935),
          ),
          HWText.fixed(
            'a fixed icon',
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
        ],
      ),
      HWIcon(
        HWIconData(
          'mood',
          icons: [
            Icons.wb_sunny,
            Icons.cloud,
            Icons.umbrella,
            Icons.ac_unit,
            Icons.bolt,
            Icons.favorite_border,
            Icons.star,
            Icons.pets,
            Icons.coffee,
            Icons.arrow_forward,
          ],
          defaultValue: Icons.wb_sunny,
          previewValue: Icons.star,
        ),
        size: 40,
        semanticLabel: 'Mood',
      ),
    ],
  ),
)
class FontAndIcons {}
