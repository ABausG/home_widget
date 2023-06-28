//
//  HomeWidgetExample.swift
//  HomeWidgetExample
//
//  Created by Anton Borries on 04.10.20.
//

import WidgetKit
import SwiftUI

private let widgetGroupId = "YOUR_APP_GROUP_ID"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ExampleEntry {
        ExampleEntry(date: Date(), title: "Placeholder Title", message: "Placeholder Message")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ExampleEntry) -> ()) {
        let data = UserDefaults.init(suiteName:widgetGroupId)
        let entry = ExampleEntry(date: Date(), title: data?.string(forKey: "title") ?? "No Title Set", message: data?.string(forKey: "message") ?? "No Message Set")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { (entry) in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct ExampleEntry: TimelineEntry {
    let date: Date
    let title: String
    let message: String
}

struct HomeWidgetExampleEntryView : View {
    var entry: Provider.Entry
    let data = UserDefaults.init(suiteName:widgetGroupId)
    let iconPath: String?
    
    init(entry: Provider.Entry) {
        self.entry = entry
        iconPath = data?.string(forKey: "dashIcon")
        
    }
    
    var body: some View {
        VStack.init(alignment: .leading, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
            Text(entry.title).bold().font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
            Text(entry.message)
                .font(.body)
                .widgetURL(URL(string: "homeWidgetExample://message?message=\(entry.message)&homeWidget"))
            if (iconPath != nil) {
                Image(uiImage: UIImage(contentsOfFile: iconPath!)!).resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
            }
        }
        )
    }
}

@main
struct HomeWidgetExample: Widget {
    let kind: String = "HomeWidgetExample"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HomeWidgetExampleEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct HomeWidgetExample_Previews: PreviewProvider {
    static var previews: some View {
        HomeWidgetExampleEntryView(entry: ExampleEntry(date: Date(), title: "Example Title", message: "Example Message"))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
