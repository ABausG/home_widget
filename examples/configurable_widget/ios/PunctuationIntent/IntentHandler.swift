//
//  IntentHandler.swift
//  PunctuationIntent
//
//  Created by Anton Borries on 16.02.25.
//

import Intents

class IntentHandler: INExtension, GreetingIntentIntentHandling {
   
   func providePunctuationOptionsCollection(for intent: GreetingIntentIntent) async throws -> INObjectCollection<Punctuation> {
       let userDefaults = UserDefaults(suiteName: "group.es.antonborri.configurableWidget")
       
       do {
           let jsonPunctuations = (userDefaults?.string(forKey: "punctuations") ?? "[\"!\"]").data(using: .utf8)!
           let stringArray = try JSONDecoder().decode([String].self, from: jsonPunctuations)
           let items = stringArray.map { punctuation in
               Punctuation(identifier: punctuation, display: punctuation)
           }
           return INObjectCollection(items: items)
           
       } catch {
           return INObjectCollection(items: [Punctuation(identifier: "!", display: "!")])
       }
   }
}
