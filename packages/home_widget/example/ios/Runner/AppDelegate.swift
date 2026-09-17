import Flutter
import UIKit
import home_widget
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))

    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 17, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
