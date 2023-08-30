//
//  BackgroundIntent.swift
//  Runner
//
//  Created by Anton Borries on 26.08.23.
//

import Foundation
import AppIntents
import home_widget
import Flutter

@available(iOS 16, *)
public struct BackgroundIntent : AppIntent {
    static public var title: LocalizedStringResource = "HomeWidget Background Intent"

    @Parameter(title: "Widget URI")
    var url: URL?
    
    @Parameter(title: "AppGroup")
    var appGroup: String?
    
    public init(){}
    
    public init(url: URL?, appGroup: String?) {
        self.url = url
        self.appGroup = appGroup
    }
    
    public func perform() async throws -> some IntentResult {
        await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup!)
    
        return .result()
    }
}

@available(iOS 16, *)
@available(iOSApplicationExtension, unavailable)
extension BackgroundIntent : ForegroundContinuableIntent {}
