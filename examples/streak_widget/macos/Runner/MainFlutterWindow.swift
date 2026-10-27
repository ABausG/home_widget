import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let controller = FlutterViewController()
    let frame = self.frame
    contentViewController = controller
    setFrame(frame, display: true)
    RegisterGeneratedPlugins(registry: controller)
    super.awakeFromNib()
  }
}
