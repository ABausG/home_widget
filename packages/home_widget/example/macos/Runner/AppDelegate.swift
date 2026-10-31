import Cocoa
import FlutterMacOS
import home_widget

@main
class AppDelegate: FlutterAppDelegate {
  private weak var widgetPlugin: HomeWidgetPlugin?
  private var willLaunch: Notification?
  private var didLaunch: Notification?
  private var launched = false
  private var pendingURLs: [(urls: [URL], duringLaunch: Bool)] = []
  private var forwardingScheduled = false

  override func addApplicationLifecycleDelegate(_ delegate: FlutterAppLifecycleDelegate) {
    super.addApplicationLifecycleDelegate(delegate)
    guard widgetPlugin == nil, let plugin = delegate as? HomeWidgetPlugin else { return }
    widgetPlugin = plugin
    scheduleURLForwarding()
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    if #available(macOS 14.0, *) {
      HomeWidgetPlugin.setConfigurationLookup(to: [
        "HomeWidgetMacOSConfigurableExample": HomeWidgetConfiguration.self
      ])
    }
    HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
      RegisterGeneratedPlugins(registry: registry)
    }
    super.applicationWillFinishLaunching(notification)
    willLaunch = notification
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    launched = true
    didLaunch = notification
    scheduleURLForwarding()
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    guard !urls.isEmpty else { return }
    pendingURLs.append((urls, !launched))
    scheduleURLForwarding()
  }

  private func scheduleURLForwarding() {
    guard launched, widgetPlugin != nil, !forwardingScheduled,
      didLaunch != nil || !pendingURLs.isEmpty
    else { return }
    forwardingScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.forwardingScheduled = false
      guard let plugin = self.widgetPlugin else { return }
      let batches = self.pendingURLs
      self.pendingURLs.removeAll()
      // Replay startup only to HomeWidget, including URLs received before registration.
      if let notification = self.willLaunch { plugin.handleWillFinishLaunching(notification) }
      for batch in batches where batch.duringLaunch {
        self.forward(batch.urls, to: plugin)
      }
      if let notification = self.didLaunch { plugin.handleDidFinishLaunching(notification) }
      self.willLaunch = nil
      self.didLaunch = nil
      for batch in batches where !batch.duringLaunch {
        self.forward(batch.urls, to: plugin)
      }
    }
  }

  private func forward(_ urls: [URL], to plugin: HomeWidgetPlugin) {
    // Keep mixed launch batches intact, without swallowing other plugins' URLs.
    _ = plugin.handleOpen(urls)
    for url in urls {
      let isWidget =
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?.contains { $0.name == "homeWidget" } ?? false
      if !isWidget { super.application(NSApp, open: [url]) }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
