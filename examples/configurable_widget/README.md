# configurable_widget

A new Flutter project.

## macOS

Run `flutter run -d macos`. This example requires macOS 14 or later.
Open `macos/Runner.xcworkspace` in Xcode and select your signing team for Runner
and each Widget Extension. Use your own bundle identifiers, keeping each
extension identifier prefixed by the host identifier.

Enable the same App Group for the host and all extensions. Replace the sample
group in the Debug/Release entitlements and the widget sources; it must match
the group used by the Dart code. Then run the signed app and add the widgets
from your Mac's widget gallery.

Edit the widget's Name and Punctuation, then refresh the app's widget list to
read the configuration. `AppIntent.swift` belongs to both the host and extension;
AppDelegate registers the same intent type for configuration lookup.
