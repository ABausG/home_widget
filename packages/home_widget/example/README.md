# home_widget_example

Demonstrates how to use the home_widget plugin.

## macOS example

Run this example with `flutter run -d macos`.
All platforms use `lib/main.dart`. Workmanager is initialized only on Android and iOS.
The embedded `HomeWidgetExampleExtension` displays shared data, PNG images and
Flutter screenshots, handles Widget URLs and runs background counter buttons.
The app reads shared data and installed widget configurations.

Build a Release app with
`flutter build macos --release`.

Open `macos/Runner.xcworkspace` in Xcode and select your signing team for the
Runner and HomeWidgetExampleExtension targets. Use your own matching bundle
identifiers (the extension identifier must start with the host identifier).
Without an App Group, the app shows setup instructions and the widget displays
**Configure App Group**. To share data and images, add **one matching App Group** to both targets in
Signing & Capabilities. Ensure it is present in the host's Debug and Release
entitlements and the Widget Extension's entitlements. The demo selects the first
signed App Group in each process, so use just one group in this example; no
personal team or group identifier is stored in the public project.

Launch the signed app and select **Save and refresh**. It shows a blue image with an
orange circle and a teal Flutter screenshot. Then add **HomeWidget macOS** from
Notification Center or, on macOS 14 and later, the desktop widget gallery. The
widget displays the same images and token. Reopen the app to restore its saved
previews. The provider reads persisted paths on snapshot/timeline creation.
Saving requests a refresh of both `HomeWidgetMacOSExample` and
`HomeWidgetMacOSConfigurableExample` after the image paths and token have been
written. You can update the existing widget
without removing it. WidgetKit schedules the actual refresh; a successful
request does not promise an immediate redraw.

The macOS plugin supports `setAppGroupId`, `saveWidgetData`, and `getWidgetData`.
To share data, add the same App Group to the host and Widget Extension's signing
entitlements, then set that group as the default or pass `appGroupId` per data
call. The per-call group takes precedence. Read the same suite with
`UserDefaults(suiteName:)` in Swift. Null deletes a value; missing keys use the
requested default, and typed byte data is stored as `Data`.

`setAppGroupId` only records the identifier. On macOS, data access fails with
`PlatformException` code `-9` if the resolved group is absent from the current
process's App Groups entitlement or its preferences are unavailable. It does
not fall back to private storage. The unconfigured example remains usable without an
App Group; URLs and configuration queries do not require shared storage.

`saveFile`, `saveImage`, and `renderFlutterWidget` now resolve the App Group
container through the plugin on both iOS and macOS. Files keep the layout
`{container}/home_widget/{key}.{extension}`; the path is stored in widget data
only after the file write succeeds. Clearing a key retains the existing managed
file cleanup rules. Android continues to use its application support directory.

File saving throws if the group is not set (`-7`), the macOS process lacks its
entitlement (`-9`), the system container is unavailable (`-10`), or file I/O
fails. These errors are wrapped by the existing file-save exception. No private
directory fallback is used. Screenshot rendering requires a Dart Flutter view.
A windowless macOS engine can still provide an implicit Dart view: the current
Flutter 3.47.8 Release probe rendered a PNG without a native window or
ViewController. An engine without an implicit Dart view receives an explicit
error. This is separate from background callback execution and app-termination
support; file sharing does not depend on screenshot rendering. The output is a PNG, not a live Flutter widget embedded in
WidgetKit.

For `updateWidget`, iOS and macOS both use the string `iOSName` alias first,
then `name`. Null or non-string aliases fall back to `name`; the value is the
Widget kind, not its Swift type or bundle identifier. Invalid arguments fail
with code `-3`. The existing empty-string behavior is preserved.

Android-only APIs keep the iOS compatibility results on macOS: preview updates,
scheduling/cancellation/exact-scheduling checks and pin-support checks return
`false`; pin requests, configure-launch queries and configure completion return
null (the `Future<void>` calls simply complete). They do not emulate Android
launcher behavior on macOS.

Select **Read widget configurations** to query WidgetKit without requiring an
App Group. Results use the existing `HomeWidgetInfo.iOSKind` and `iOSFamily`
fields on both iOS and macOS; they describe configurations, not an exact count
of desktop instances. Empty results and query errors are shown separately.
On macOS 14+, also add **HomeWidget macOS Configurable**. Open **Edit Widget**,
change **Name**, then select **Read widget configurations** in the app. The
configuration contains the edited name. Both widgets share the same images and
counter; the original **HomeWidget macOS** remains a static configuration.
In the app, select **Increment counter** to add one or **Reset counter** to
set the shared count to zero. Both actions refresh both widget kinds.
Select **Read shared data** after using either widget's Count button to update
the app's copy of the counter. These controls require a configured App Group.
Without an App Group, the widget shows **Configure App Group** and hides its
Count button. Counting is shared data; the configurable widget’s Name setting
does not set the count.

The example compiles [HomeWidgetConfiguration](macos/Runner/WidgetConfiguration.swift)
into both the host and extension and registers its lookup in AppDelegate before
querying. For a custom AppIntent widget, use the same arrangement:

```swift
if #available(macOS 14.0, *) {
  HomeWidgetPlugin.setConfigurationLookup(to: [
    "YourWidgetKind": YourConfigurationIntent.self
  ])
}
```

Import `home_widget` in that host file. Legacy `INIntent` configuration values
are read when WidgetKit supplies them. Modern values require the matching
lookup type on macOS 14 / iOS 17 and later. If no matching type is registered,
the row still includes kind and family, with no fabricated configuration.
Existing configuration value conversion is shared with iOS; this does not add
recursive conversion for arbitrary native values or start a background engine.

Click the macOS widget to open `homewidget-macos://widget?homeWidget` in the
host. The app shows the cached initial URI, latest URI, and event count. Running
clicks leave the initial URI unchanged; repeated clicks each produce an event.
URLs use the existing case-sensitive `homeWidget` query marker. No App Group is
needed for URL routing.

Retain the [AppDelegate](macos/Runner/AppDelegate.swift) startup forwarding if
adapting the host. It records URL batches and launch notifications until the
primary HomeWidget plugin is registered, then replays startup in order to that
plugin. Other URLs continue through Flutter's normal delegates individually,
so a mixed batch does not hide them. Keep your own application routing there
as needed. The standard generated plugin registration stays in place.

Subscribe to `HomeWidget.widgetClicked` early and query
`HomeWidget.initiallyLaunchedFromHomeWidget()` for an already delivered launch
URI. Initial queries are non-consuming. Listening later does not replay missed
events; the example also rechecks the initial URI on each live event. If you
change the URL scheme, update both the host's `CFBundleURLTypes` and the
Widget's `widgetURL`. URL routing does not prove background execution or
behavior after every app-termination scenario.

The host uses Flutter's macOS 12 deployment target; the Widget target is declared
for macOS 11. Flutter 3.47.8 raises the Widget build target to macOS 12 during
the build. These declarations do not establish compatibility with older
Flutter SDKs or prove that the example runs on macOS 11.

See Apple's [widget extension guide](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
for the WidgetKit target and configuration model.

### macOS background buttons

On macOS 14+, the widget's counter button runs `BackgroundIntent` in the host
without requesting foreground activation. Add the intent source to both targets;
only the host adds `ForegroundContinuableIntent` conformance and imports
`home_widget`. Keep `WIDGET_EXTENSION` defined for the extension. Flutter and
business plugins belong to the host, and the extension must not link them.

Configure the same authorized App Group for both targets, open the app once, and
register the callback after `HomeWidget.setAppGroupId`. The host must also call
`HomeWidgetBackgroundWorker.setPluginRegistrantCallback` to register
`home_widget` and any other plugins needed by the callback in each background
engine. This example uses `RegisterGeneratedPlugins`.

The macOS embedder resolves named Dart entrypoints in the selected root library.
Keep this wrapper in `lib/main.dart` (or your own build's root entry file),
with a top-level callback retained for Release:

```dart
import 'package:home_widget/home_widget.dart' as home_widget;

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.registerInteractivityCallback(macOSBackgroundCallback);
  await home_widget.callbackDispatcher();
}
```

The wrapper re-registers the same business callback to restore the cold isolate's
callback handle map. Native code establishes that engine's App Group before Dart
starts. Keep UI startup and unrelated app initialization in `main()`, outside this
wrapper. Re-register from the app after changing the callback or installing a new
build; stored handles are not portable between builds.

Business callbacks must manage their own concurrency and complete their returned
Future. The package forwards each request and waits for that Future; it does not
serialize, cancel or retry business operations. Widget execution and refresh are
scheduled by macOS, so keep background work short and do not rely on an
unlimited execution time or identical behavior after every termination state.
