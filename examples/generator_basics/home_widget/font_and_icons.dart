import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

/// Custom font and icon demo.
///
/// - `HWTextStyle(fontFamily: 'Chewy')` renders text in a font declared under
///   `flutter: fonts:` in `pubspec.yaml`. The font file itself stays where it
///   is: both platforms read it out of `flutter_assets`, so nothing is copied
///   next to the widget. The label and the line under it share the family:
///   on Android each is measured in turn, so the paragraph wraps to the room
///   the label leaves it.
/// - `androidFont: HWAndroidFont.serif` on the line under those keeps the
///   custom family on iOS but asks Android for a Glance `Text` in the device's
///   serif family instead of a bitmap, so that line follows the theme and needs
///   no measuring pass. `HWAndroidFont.system` would give it the platform's own
///   font the same way.
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
/// - `CupertinoIcons.sun_max` and `FontAwesomeIcons.solidHeart` come from
///   packages; the CLI subsets those fonts the same way.
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
      HWText.fixed(
        'The same family again, wrapping to the room the label leaves it.',
        textAlign: HWTextAlign.center,
        style: HWTextStyle(fontFamily: 'Chewy', fontSize: 14),
      ),
      HWText.fixed(
        'serif on Android',
        style: HWTextStyle(
          fontFamily: 'Chewy',
          fontSize: 11,
          androidFont: HWAndroidFont.serif,
        ),
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
          HWIcon.fixed(
            CupertinoIcons.sun_max,
            size: 24,
            color: HWFixedColor(0xFFFB8C00),
          ),
          HWIcon.fixed(
            FontAwesomeIcons.solidHeart,
            size: 24,
            color: HWFixedColor(0xFF8E24AA),
          ),
        ],
      ),
      HWText.fixed(
        'three icons, three fonts',
        style: HWRoleTextStyle(role: HWTextStyleRole.caption),
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
