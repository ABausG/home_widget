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

## Generating the native code

Run the CLI from the project root:

```bash
dart run home_widget_cli generate
```

This reads every `*.dart` file under `home_widget/`, writes the Dart helpers to
`lib/src/home_widget/<name>.home_widget.dart`, and scaffolds the native widget
targets for both Android and iOS.
