// GENERATED CODE - DO NOT MODIFY BY HAND

import AppIntents
import Foundation
import home_widget

@available(iOS 17, *)
struct InteractiveCounterHomeWidgetIntent: AppIntent {
  static let title: LocalizedStringResource = "Interactive Counter interaction"
  static let isDiscoverable: Bool = false

  @Parameter(title: "URL")
  var url: URL?

  @Parameter(title: "App Group")
  var appGroup: String?

  @Parameter(title: "Key")
  var key: String?

  init() {}

  init(url: URL?, appGroup: String?, key: String?) {
    self.url = url
    self.appGroup = appGroup
    self.key = key
  }

  func perform() async throws -> some IntentResult {
    if let appGroup = appGroup {
      await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup, key: key)
    }
    return .result()
  }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension InteractiveCounterHomeWidgetIntent: ForegroundContinuableIntent {}
