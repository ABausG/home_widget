import AppIntents

@available(macOS 14.0, *)
struct HomeWidgetConfiguration: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Home Widget configuration"

  @Parameter(title: "Name", default: "Home Widget") var name: String
}
