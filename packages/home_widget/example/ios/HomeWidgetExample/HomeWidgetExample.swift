//
//  HomeWidgetExample.swift
//  HomeWidgetExample
//
//  Created by Anton Borries on 04.10.20.
//

import SwiftUI
import WidgetKit

private let widgetGroupId = "group.es.antonborri.exampleHomeWidget"

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ExampleEntry {
    ExampleEntry(date: Date(), title: "Placeholder Title", message: "Placeholder Message")
  }

  func getSnapshot(in context: Context, completion: @escaping (ExampleEntry) -> Void) {
    let data = UserDefaults.init(suiteName: widgetGroupId)
    let entry = ExampleEntry(
      date: Date(), title: data?.string(forKey: "title") ?? "No Title Set",
      message: data?.string(forKey: "message") ?? "No Message Set")
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
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

struct HomeWidgetExampleEntryView: View {
  var entry: Provider.Entry
  let data = UserDefaults.init(suiteName: widgetGroupId)
  let iconPath: String?

  init(entry: Provider.Entry) {
    self.entry = entry
    iconPath = data?.string(forKey: "dashIcon")

  }

  var body: some View {
    VStack.init(
      alignment: .center,
      spacing: nil,
      content: {
        if #available(iOSApplicationExtension 17, *) {
          Button(
            intent: BackgroundIntent(
              url: URL(string: "homeWidgetExample://titleClicked"), appGroup: widgetGroupId)
          ) {
            Text(entry.title).bold().font(
              .title)
          }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text(entry.title).bold().font(
            .title
          ).frame(
            maxWidth: .infinity, alignment: .leading)
        }
        Text(entry.message)
          .font(.body)
          .widgetURL(URL(string: "homeWidgetExample://message?message=\(entry.message)&homeWidget"))
          .frame(maxWidth: .infinity, alignment: .leading)
        if iconPath != nil {
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
    HomeWidgetExampleEntryView(
      entry: ExampleEntry(date: Date(), title: "Example Title", message: "Example Message")
    )
    .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
