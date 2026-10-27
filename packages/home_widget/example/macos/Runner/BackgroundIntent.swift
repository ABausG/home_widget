import AppIntents
import Foundation

#if !WIDGET_EXTENSION
  import home_widget
#endif

private enum BackgroundIntentError: Error {
  case hostRequired
  case missingAppGroup
}

@available(macOS 14.0, *)
struct BackgroundIntent: AppIntent {
  static var title: LocalizedStringResource = "Update HomeWidget counter"
  static var openAppWhenRun = false

  @Parameter(title: "Widget URI") var url: URL?
  @Parameter(title: "App Group") var appGroup: String?

  init() {}

  init(url: URL?, appGroup: String?) {
    self.url = url
    self.appGroup = appGroup
  }

  func perform() async throws -> some IntentResult {
    #if WIDGET_EXTENSION
      // The same intent is included in both targets; the host owns Flutter.
      throw BackgroundIntentError.hostRequired
    #else
      guard let appGroup else { throw BackgroundIntentError.missingAppGroup }
      await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup)
    #endif
    return .result()
  }
}

#if !WIDGET_EXTENSION
  @available(macOS 14.0, *)
  extension BackgroundIntent: ForegroundContinuableIntent {}
#endif
