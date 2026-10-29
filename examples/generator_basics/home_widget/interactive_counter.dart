import 'package:flutter/material.dart';
import 'package:generator_basics/interactive_counter.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

/// Interactive demo: two `HWButton`s change the count without opening the app.
///
/// A tap runs `onInteractiveCounterInteraction` in the background, which gets
/// the button as a generated class:
///
///   switch (interaction) {
///     InteractiveCounterIncrementInteraction(:final step) => ...,
///     InteractiveCounterDecrementInteraction() => ...,
///   }
///
/// The function lives in `lib/interactive_counter.dart`, because the generated
/// Dart imports it and this schema file is not part of the app. The `data` of
/// a button comes back as the fields of its class, holding the values the
/// widget was rendered with: `step` is fixed here, so it names which button
/// was tapped, not the current count.
///
/// The generator adds the plugin's background receiver to the Android
/// manifest. On iOS it generates an `AppIntent`, links `home_widget` into the
/// widget extension and registers the app's plugins in `AppDelegate.swift`.
/// Buttons need iOS 17.
@HomeWidget(
  name: 'Interactive Counter',
  description: 'A counter with buttons that run Dart code in the background.',
  onInteraction: onInteractiveCounterInteraction,
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [
      HWWidgetFamily.systemSmall,
      HWWidgetFamily.systemMedium,
    ],
  ),
  widget: HWColumn(
    mainAxisAlignment: HWMainAxisAlignment.center,
    crossAxisAlignment: HWCrossAxisAlignment.center,
    spacing: 8,
    children: [
      HWText.number(
        HWInt('count', defaultValue: 0),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
      HWRow(
        spacing: 24,
        children: [
          HWButton(
            'decrement',
            child: HWIcon(
              HWIconData.fixed(Icons.remove_circle_outline),
              size: 32,
              semanticLabel: 'Decrement',
            ),
          ),
          HWButton(
            'increment',
            data: [HWPayload('step', HWInt.fixed(1))],
            child: HWIcon(
              HWIconData.fixed(Icons.add_circle_outline),
              size: 32,
              semanticLabel: 'Increment',
            ),
          ),
        ],
      ),
    ],
  ),
)
class InteractiveCounter {}
