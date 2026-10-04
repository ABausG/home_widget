# Dasholingo (streak_widget)

A Duolingo parody built on `home_widget_generator` and `home_widget_cli`: a
home screen streak widget where Dash fills the whole widget, reacts to how your
day is going and swaps her mood **every 15 minutes**, without the app running.

<!-- The real Duolingo rotates hourly. Fifteen minutes makes the effect easy to
     watch while trying the example out. -->

## What it demonstrates

- **`HWStack`.** The Dash picture is the full-bleed background, with the streak
  in the top corner and an optional caption at the bottom layered over it.
- **`HWTimedData` for images and text.** The picture and the caption are time
  based, so the widget cycles through Dash's moods on its own: a WidgetKit
  timeline on iOS, scheduled updates on Android. See
  [Time-based Content](https://use-home-widget.web.app/generator/timed-data).
- **`HWDataExists`.** A slot saved without a caption shows none at all.
- **`HWIcon`.** A Material flame, or a snowflake while the streak is frozen.
- **Custom font.** The streak number is set in Nunito Black, declared under
  `flutter: fonts:` like any other Flutter font. See
  [Custom Fonts](https://use-home-widget.web.app/generator/custom-fonts).
- **Nested `HWBoolConditional`.** Two stored flags (`frozen`, `completed`)
  pick the color of flame and number: grey while today's lesson is open,
  orange once it is done, ice blue while the streak is frozen.
- **Partial saves.** Changing the streak number writes only `streak`; changing
  the state rewrites the whole 15 minute schedule. Every `saveData` parameter
  left `null` leaves its stored value untouched.

## The app

- Set the streak count with `-` / `+` or the slider.
- Toggle between **Pending**, **Completed** and **Frozen**.
- A preview tile mirrors what the home screen widget shows at this very moment,
  including which picture the current 15 minute slot resolves to.

Each state has its own pool of Dash illustrations and captions. Switching state
replaces the schedule with a fresh random rotation: every picture of the pool
shows once before any repeats, and about half the slots carry a caption.

## Layout

| Path | What it is |
| --- | --- |
| [`home_widget/streak.dart`](home_widget/streak.dart) | The widget schema, the only file describing the native UI. |
| [`lib/src/streak_status.dart`](lib/src/streak_status.dart) | The three states with their colors, picture pools and captions. |
| [`lib/src/streak_schedule.dart`](lib/src/streak_schedule.dart) | Builds the 15 minute `timedData` map. |
| [`lib/src/home_widget/streak.home_widget.dart`](lib/src/home_widget/streak.home_widget.dart) | Generated. Do not edit. |
| `assets/dash/` | The Dash illustrations. |
| `assets/fonts/` | Nunito Black and its license. |

## Generating the native code

From this directory:

```bash
dart run home_widget_cli:home_widget generate
```

That writes the Glance widget and its provider XML on Android, the SwiftUI
widget extension and entitlements on iOS, and the Dart helper under
`lib/src/home_widget/`. It also registers
`HomeWidgetScheduledUpdateReceiver` and the `RECEIVE_BOOT_COMPLETED`
permission in the Android manifest, which is what keeps the 15 minute rotation
alive across a reboot.

## Running it

```bash
flutter run
```

Add the **Streak** widget from the home screen widget gallery (search for
*Dasholingo*), or with the app's **Add to home screen** button on Android, then
leave the phone alone and watch Dash change on the quarter hour.

On Android 12 and above the swaps land at the exact minute only if the app
holds an exact alarm permission; without it the system may delay them by a few
minutes.

## Credits

The Dash illustrations in `assets/dash/` are generated artwork of the Flutter
mascot. Nunito is licensed under the
[SIL Open Font License](assets/fonts/OFL.txt). Dasholingo is a parody and is
not affiliated with Duolingo.
