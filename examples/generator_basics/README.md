# generator_basics

A minimal example that showcases the `home_widget_generator` annotations and the
`home_widget_cli` tool.

The widget schemas live in [`home_widget/`](home_widget/). They are intentionally
small and each one demonstrates a different feature of the generator:

- `greeting.dart` – the README walkthrough widget (`HWColumn` + `HWString`).
- `basic_creation.dart` – the smallest possible widget (no data, no UI).
- `adaptive_greeting.dart` – platform-specific text via `HWAdaptive`.
- `simple_data.dart` – a data-only widget that exposes typed `saveData` /
  `getData` helpers on the Dart side.
- `themed_counter.dart` – an inline UI that reads data, uses role-based colors
  and a themed background.
- `conditional_status.dart` – a widget that branches on whether data is present
  using `HWDataExists` and `HWBoolConditional`.
- `localized_greeting.dart` – translated body text and gallery entry via
  `HWText.localized` and `HWString.localized`.
- `forecast.dart` – time-based content via `HWTimedData`: the widget swaps its
  own values at the times passed to `saveData(timedData: {...})`.
- `image_showcase.dart` – a bundled asset image (`HWImage.asset`), a runtime
  image (`HWImage`) wrapped in `HWDataExists` for a placeholder, a time-based
  image (`HWImage(HWTimedData(HWImageData(...)))`) that alternates between two
  pictures on a schedule, and an image read out of a JSON group
  (`HWImage(HWJson('contact', HWImageData('avatar')))`) so a name and a picture
  travel together.
- `widget_link.dart` – a `widgetUrl`, so tapping the widget opens the app with
  that URL and the generated `launchedFromWidget()` helper reports it back.

## Generating the native code

Run the CLI from the project root:

```bash
dart run home_widget_cli:home_widget generate
```

This reads every `*.dart` file under `home_widget/`, writes the Dart helpers to
`lib/src/home_widget/<name>.home_widget.dart`, and scaffolds the native widget
targets for both Android and iOS.

Because `forecast.dart` and `image_showcase.dart` use `HWTimedData`, the CLI
also registers
`HomeWidgetScheduledUpdateReceiver` and the `RECEIVE_BOOT_COMPLETED` permission
in `android/app/src/main/AndroidManifest.xml` — that is what delivers the
scheduled content swaps on Android.

Because `widget_link.dart` sets `widgetUrl`, the CLI also adds the
`es.antonborri.home_widget.action.LAUNCH` intent-filter to the launcher activity
in that same manifest — that is what hands the URL to the app when the widget is
tapped.
