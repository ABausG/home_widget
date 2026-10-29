import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

const _pending = HWColor.fixed(0xE0AFAFAF);
const _completed = HWColor.fixed(0xE0FF9600);
const _frozen = HWColor.fixed(0xE01CB0F6);

const _mascot = HWTimedData(
  HWImageData('mascot', previewAsset: 'assets/dash/success_grass.png'),
);

const _message = HWTimedData(
  HWString('message', previewValue: 'Streak secured'),
);

const _streak = HWInt('streak', defaultValue: 0, previewValue: 12);

const _number = HWTextStyle(
  fontFamily: 'Nunito',
  fontWeight: HWFontWeight.w900,
  fontSize: 28,
);

const _pill = HWBoxDecoration(
  color: HWColor.fixed(0x73000000),
  borderRadius: HWBorderRadius.circular(16),
);

/// Duolingo-style streak widget: Dash fills the widget edge to edge and the
/// streak sits on top of her.
///
/// - `HWStack` layers the flame and the caption over the full-bleed picture.
/// - `HWImage` and the caption are `HWTimedData`, so the app saves one entry
///   per 15 minute slot and the widget swaps Dash's mood on its own. A slot
///   saved without a caption shows none: `HWDataExists` leaves the pill out.
/// - `HWIcon.fixed` draws the Material flame and snowflake.
/// - The streak number is set in Nunito Black, a font declared under
///   `flutter: fonts:`.
/// - Nested `HWBoolConditional`s pick the color: grey while today's lesson is
///   open, orange once it is done, ice blue while the streak is frozen.
@HomeWidget(
  name: 'Streak',
  description: 'Your Dasholingo streak, with Dash reacting through the day.',
  useLiveDataInPreview: false,
  android: HomeWidgetAndroidConfiguration(
    minWidth: 110,
    minHeight: 110,
    targetCellWidth: 2,
    targetCellHeight: 2,
    resizeMode: HWAndroidResizeMode.none,
    applyContentPadding: false,
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.streakWidget',
    supportedFamilies: [HWWidgetFamily.systemSmall],
    applyContentPadding: false,
  ),
  widget: HWStack(
    fit: HWStackFit.expand,
    children: [
      HWSizedBox.expand(
        child: HWImage(
          _mascot,
          fit: HWImageFit.cover,
          semanticLabel: 'Dash reacting to your streak',
        ),
      ),
      HWAlign(
        alignment: HWAlignment.topStart,
        child: HWPadding(
          padding: HWEdgeInsets.all(10),
          child: HWDecoratedBox(
            decoration: _pill,
            child: HWPadding(
              padding: HWEdgeInsets.only(left: 6, right: 10),
              child: HWBoolConditional(
                data: HWBool('frozen', defaultValue: false),
                whenTrue: HWRow(
                  spacing: 2,
                  children: [
                    HWIcon.fixed(
                      Icons.ac_unit,
                      size: 24,
                      color: _frozen,
                      semanticLabel: 'Streak frozen',
                    ),
                    HWText(
                      _streak,
                      style: HWTextStyle(baseStyle: _number, color: _frozen),
                    ),
                  ],
                ),
                whenFalse: HWBoolConditional(
                  data: HWBool(
                    'completed',
                    defaultValue: false,
                    previewValue: true,
                  ),
                  whenTrue: HWRow(
                    spacing: 2,
                    children: [
                      HWIcon.fixed(
                        Icons.local_fire_department,
                        size: 24,
                        color: _completed,
                        semanticLabel: 'Lesson done',
                      ),
                      HWText(
                        _streak,
                        style: HWTextStyle(
                          baseStyle: _number,
                          color: _completed,
                        ),
                      ),
                    ],
                  ),
                  whenFalse: HWRow(
                    spacing: 2,
                    children: [
                      HWIcon.fixed(
                        Icons.local_fire_department,
                        size: 24,
                        color: _pending,
                        semanticLabel: 'Lesson not done yet',
                      ),
                      HWText(
                        _streak,
                        style: HWTextStyle(baseStyle: _number, color: _pending),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      HWDataExists(
        data: _message,
        whenPresent: HWAlign(
          alignment: HWAlignment.bottomCenter,
          child: HWPadding(
            padding: HWEdgeInsets.all(8),
            child: HWDecoratedBox(
              decoration: _pill,
              child: HWPadding(
                padding: HWEdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: HWText(
                  _message,
                  style: HWRoleTextStyle(
                    role: HWTextStyleRole.captionSmall,
                    fontWeight: HWFontWeight.bold,
                    color: HWColor.fixed(0xF2FFFFFF),
                  ),
                  textAlign: HWTextAlign.center,
                ),
              ),
            ),
          ),
        ),
        whenAbsent: HWDataOnly([_message]),
      ),
    ],
  ),
)
class Streak {}
