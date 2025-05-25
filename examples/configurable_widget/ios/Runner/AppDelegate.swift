import Flutter
import UIKit
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 17.0, *) {
      HomeWidgetPlugin.setConfigurationLookup(to: [
        "ConfigurableWidget": ConfigurationAppIntent.self
      ])
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
