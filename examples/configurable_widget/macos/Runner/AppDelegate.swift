import Cocoa
import FlutterMacOS
import home_widget

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    HomeWidgetPlugin.setConfigurationLookup(to: ["ConfigurableWidget": ConfigurationAppIntent.self])
    super.applicationWillFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }
}
