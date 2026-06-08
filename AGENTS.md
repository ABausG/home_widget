# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is

Flutter/Dart monorepo for the **home_widget** plugin ecosystem (plugin, generator, CLI, and example apps). There is no backend or database — development is Flutter + Melos + platform SDKs.

### Toolchain (pre-installed on the VM snapshot)

- **Flutter**: `~/flutter` (stable channel). Ensure `$HOME/flutter/bin` is on `PATH`.
- **Melos**: activated globally via `dart pub global activate melos`. Ensure `$HOME/.pub-cache/bin` is on `PATH` so `melos run …` scripts work (they invoke `melos` internally).
- **Android SDK**: `$HOME/Android/Sdk` with platforms 33/35/36, build-tools, emulator, and an x86_64 system image. Set `ANDROID_HOME` and point Flutter at it with `flutter config --android-sdk "$ANDROID_HOME"`.
- **JDK 21**: OpenJDK 21 (`JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`).

### Bootstrap (after `git pull`)

From repo root:

```bash
dart pub get
melos bootstrap
```

The VM update script runs the dependency refresh steps above automatically.

### Common commands

| Task | Command |
|------|---------|
| Analyze all packages | `melos analyze` |
| Unit tests (all packages) | `melos run test` |
| Flutter tests (one package) | `cd packages/home_widget && flutter test` |
| Dart tests (CLI/generator) | `cd packages/home_widget_cli && dart test` |
| Build Android example APK | `cd examples/generator_basics && flutter build apk --debug` |
| Generate native widget code | `cd examples/generator_basics && dart run home_widget_cli:home_widget generate` |

Melos script definitions live in root `pubspec.yaml` under the `melos:` key.

### Non-obvious gotchas

- **CLI executable name**: The CLI package is `home_widget_cli`, but its executable is `home_widget`. In this workspace, `dart run home_widget` resolves to the *plugin* package and fails. Use `dart run home_widget_cli:home_widget <command>` from example apps.
- **Android emulator**: `/dev/kvm` is not available in this cloud VM, so `flutter run` on an emulator will not work. Validate Android with `flutter build apk` or CI-style Gradle builds instead.
- **iOS builds/tests**: Require macOS + Xcode; not available on Linux cloud agents.
- **Full `melos format:all`**: Needs `ktfmt` and `swift-format` (installed via Homebrew on macOS in CI). `melos analyze` and `melos run test` are sufficient for Linux validation.
- **First Android build**: Gradle may download NDK/CMake on first run; subsequent builds are much faster.

### Example apps

Runnable demos under `examples/` (`generator_basics` is the smallest). Typical flow: generate native code with the CLI, then build or run on a device/emulator.
