import Cocoa
import FlutterMacOS
import Security

class MainFlutterWindow: NSWindow {
  private var exampleChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "home_widget_example/config",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "appGroupId" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let task = SecTaskCreateFromSelf(nil)
      let groups = task.flatMap {
        SecTaskCopyValueForEntitlement(
          $0, "com.apple.security.application-groups" as CFString, nil) as? [String]
      }
      result(groups?.first)
    }
    exampleChannel = channel

    super.awakeFromNib()
  }
}
