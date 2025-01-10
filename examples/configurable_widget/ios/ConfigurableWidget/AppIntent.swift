//
//  AppIntent.swift
//  ConfigurableWidget
//
//  Created by Anton Borries on 23.10.24.
//

import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Configuration"
  static var description = IntentDescription("This is an example widget.")

  // An example simple parameter
  @Parameter(title: "Name", default: "World")
  var name: String

  @Parameter(title: "Punctuation")
  var punctuation: PunctuationEntity

  func perform() async throws -> Never {
    return Never()
  }
}

// Make Entity Codable so home_widget
// That way home_widget can best extract the values from a configuration
@available(iOS 17.0, *)
struct PunctuationEntity: AppEntity, Codable {
  let id: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Punctuation"
  static var defaultQuery = PunctuationQuery()

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(id)")
  }
}

@available(iOS 17.0, *)
struct PunctuationQuery: EntityQuery {

  func punctuations() -> [PunctuationEntity] {
    let userDefaults = UserDefaults(suiteName: "group.es.antonborri.configurableWidget")

    do {
      let jsonPunctuations = (userDefaults?.string(forKey: "punctuations") ?? "[\"!\"]").data(
        using: .utf8)!
      let stringArray = try JSONDecoder().decode([String].self, from: jsonPunctuations)
      return stringArray.map { punctuation in
        PunctuationEntity(id: punctuation)

      }
    } catch {
      return [PunctuationEntity(id: "!")]
    }

  }

  func entities(for identifiers: [PunctuationEntity.ID]) async throws -> [PunctuationEntity] {
    let results = punctuations().filter { identifiers.contains($0.id) }
    return results
  }

  func suggestedEntities() async throws -> [PunctuationEntity] {
    return punctuations()
  }

  func defaultResult() async -> PunctuationEntity? {
    try? await suggestedEntities().first
  }

}
