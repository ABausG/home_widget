## home_widget_cli

A Dart CLI to scaffold the native parts needed for `home_widget` widgets.

### Usage (planned)

Create platform placeholder structure for a widget named `ExampleHomeWidget`:

```bash
home_widget create Example
```

Platform selection:
- `--android`: scaffold Android only
- `--ios`: scaffold iOS only

If neither flag is provided, the CLI will scaffold platforms based on whether an `android/` and/or `ios/` folder exists in the current directory.


