import AppIntents
import Flutter
import UIKit
import XCTest
import home_widget

class RunnerTests: XCTestCase {

  private func invoke(
    _ method: String, arguments: Any? = nil, on plugin: HomeWidgetPlugin
  ) -> Any? {
    let codec = FlutterStandardMethodCodec.sharedInstance()
    let call = codec.decodeMethodCall(
      codec.encode(FlutterMethodCall(methodName: method, arguments: arguments)))
    var value: Any?
    var completions = 0
    plugin.handle(call) { result in
      completions += 1
      value = result
    }
    XCTAssertEqual(completions, 1, method)
    return value
  }

  private func isolatedSuite() -> String {
    let group = "home_widget.tests.\(UUID().uuidString)"
    addTeardownBlock { UserDefaults(suiteName: group)?.removePersistentDomain(forName: group) }
    return group
  }

  func testDefaultAndPerCallGroupsKeepStorageSeparate() {
    let plugin = HomeWidgetPlugin()
    let defaultGroup = isolatedSuite()
    let otherGroup = isolatedSuite()
    XCTAssertEqual(
      invoke("setAppGroupId", arguments: ["groupId": defaultGroup], on: plugin) as? Bool, true)
    XCTAssertEqual(
      invoke("saveWidgetData", arguments: ["id": "value", "data": "default"], on: plugin)
        as? Bool, true)
    XCTAssertEqual(
      invoke(
        "saveWidgetData", arguments: ["id": "value", "data": "override", "appGroupId": otherGroup],
        on: plugin) as? Bool, true)

    XCTAssertEqual(UserDefaults(suiteName: defaultGroup)?.string(forKey: "value"), "default")
    XCTAssertEqual(UserDefaults(suiteName: otherGroup)?.string(forKey: "value"), "override")
    XCTAssertEqual(
      invoke("getWidgetData", arguments: ["id": "value", "defaultValue": NSNull()], on: plugin)
        as? String, "default")
    XCTAssertEqual(
      invoke(
        "getWidgetData",
        arguments: ["id": "value", "defaultValue": NSNull(), "appGroupId": otherGroup], on: plugin)
        as? String, "override")
  }

  func testTypedDataNullDeletionAndMissingValueRoundTrip() {
    let plugin = HomeWidgetPlugin()
    let group = isolatedSuite()
    let bytes = Data([0, 1, 127, 128, 255])
    let args: [String: Any] = [
      "id": "binary", "data": FlutterStandardTypedData(bytes: bytes), "appGroupId": group,
    ]
    XCTAssertEqual(invoke("saveWidgetData", arguments: args, on: plugin) as? Bool, true)
    XCTAssertEqual(UserDefaults(suiteName: group)?.data(forKey: "binary"), bytes)
    let result = invoke(
      "getWidgetData", arguments: ["id": "binary", "defaultValue": NSNull(), "appGroupId": group],
      on: plugin)
    let codec = FlutterStandardMethodCodec.sharedInstance()
    let decoded = codec.decodeEnvelope(codec.encodeSuccessEnvelope(result))
    XCTAssertEqual((decoded as? FlutterStandardTypedData)?.data, bytes)

    XCTAssertEqual(
      invoke(
        "saveWidgetData", arguments: ["id": "binary", "data": NSNull(), "appGroupId": group],
        on: plugin) as? Bool, true)
    XCTAssertNil(UserDefaults(suiteName: group)?.object(forKey: "binary"))
    XCTAssertEqual(
      invoke(
        "getWidgetData",
        arguments: ["id": "binary", "defaultValue": "missing", "appGroupId": group],
        on: plugin) as? String, "missing")
    let missing = invoke(
      "getWidgetData",
      arguments: ["id": "binary", "defaultValue": NSNull(), "appGroupId": group], on: plugin)
    XCTAssertNil(missing)
    XCTAssertNil(codec.decodeEnvelope(codec.encodeSuccessEnvelope(missing)))
  }

  func testInvalidStorageArgumentsCompleteWithExistingErrors() {
    let plugin = HomeWidgetPlugin()
    let group = isolatedSuite()
    for (method, arguments, code) in [
      ("setAppGroupId", ["groupId": 42] as [String: Any], "-6"),
      ("saveWidgetData", ["data": "value", "appGroupId": group], "-1"),
      ("getWidgetData", ["id": 42, "appGroupId": group], "-2"),
    ] {
      let error = invoke(method, arguments: arguments, on: plugin) as? FlutterError
      XCTAssertEqual(error?.code, code, method)
    }
  }

  func testMissingAppGroupArgumentsCompleteWithExistingError() {
    let plugin = HomeWidgetPlugin()
    let inputs: [Any?] = [nil, NSNull(), [:] as [String: Any]]
    for arguments in inputs {
      let error = invoke("setAppGroupId", arguments: arguments, on: plugin) as? FlutterError
      XCTAssertEqual(error?.code, "-6")
    }
  }

  func testMissingStorageArgumentsCompleteAndInvalidDataKeepsExistingValue() {
    let plugin = HomeWidgetPlugin()
    let group = isolatedSuite()
    XCTAssertEqual(
      invoke("setAppGroupId", arguments: ["groupId": group], on: plugin) as? Bool, true)
    let inputs: [Any?] = [nil, NSNull(), [], [:] as [String: Any]]
    for (method, code) in [("saveWidgetData", "-1"), ("getWidgetData", "-2")] {
      for arguments in inputs {
        XCTAssertEqual(
          (invoke(method, arguments: arguments, on: plugin) as? FlutterError)?.code, code)
      }
    }
    XCTAssertEqual(
      invoke("saveWidgetData", arguments: ["id": "value", "data": "keep"], on: plugin) as? Bool,
      true)
    let error =
      invoke(
        "saveWidgetData", arguments: ["id": "value", "data": ["nested": NSNull()]], on: plugin)
      as? FlutterError
    XCTAssertEqual(error?.code, "-1")
    XCTAssertEqual(UserDefaults(suiteName: group)?.string(forKey: "value"), "keep")
  }

  func testWidgetContainerPathUsesDefaultAndPerCallGroups() {
    let plugin = HomeWidgetPlugin()
    let defaultGroup = "group.homewidget.tests.\(UUID().uuidString)"
    let otherGroup = "group.homewidget.tests.\(UUID().uuidString)"
    XCTAssertEqual(
      invoke("setAppGroupId", arguments: ["groupId": defaultGroup], on: plugin) as? Bool, true)
    for (arguments, group) in [
      (nil as Any?, defaultGroup),
      (["appGroupId": otherGroup], otherGroup),
      (["appGroupId": NSNull()], defaultGroup),
    ] {
      let value = invoke("getWidgetContainerPath", arguments: arguments, on: plugin)
      if let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: group)
      {
        XCTAssertEqual(value as? String, container.path)
      } else {
        let error = value as? FlutterError
        XCTAssertEqual(error?.code, "-10")
        XCTAssertEqual(error?.details as? String, group)
      }
    }
    XCTAssertEqual(
      invoke("getWidgetContainerPath", on: plugin) as? String,
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: defaultGroup)?.path)
  }

  func testInstalledWidgetQueryCompletesWithChannelEncodableRows() {
    let completed = expectation(description: "WidgetKit configurations")
    completed.assertForOverFulfill = true
    HomeWidgetPlugin().handle(FlutterMethodCall(methodName: "getInstalledWidgets", arguments: nil))
    {
      result in
      guard let rows = result as? [[String: Any]] else {
        XCTFail("Expected WidgetKit configuration rows, got \(String(describing: result))")
        completed.fulfill()
        return
      }
      for row in rows {
        XCTAssertNotNil(row["kind"] as? String)
        XCTAssertNotNil(row["family"] as? String)
      }
      let codec = FlutterStandardMethodCodec.sharedInstance()
      XCTAssertNotNil(codec.decodeEnvelope(codec.encodeSuccessEnvelope(rows)) as? [[String: Any]])
      completed.fulfill()
    }
    wait(for: [completed], timeout: 10)
  }

  func testWidgetRefreshNamesAndMalformedArgumentsCompleteOnce() {
    let plugin = HomeWidgetPlugin()
    let kind = "HomeWidgetRefreshTests.\(UUID().uuidString)"
    let invalid: [Any?] = [
      nil, NSNull(), [], [:], ["ios": NSNull()], ["ios": 42, "name": false],
    ]
    for arguments in invalid {
      let error = invoke("updateWidget", arguments: arguments, on: plugin) as? FlutterError
      XCTAssertEqual(error?.code, "-3")
    }
    let valid: [[String: Any]] = [
      ["ios": kind, "name": "ignored"],
      ["ios": NSNull(), "name": kind],
      ["ios": 42, "name": kind],
      ["name": kind],
      ["ios": "", "name": kind],
    ]
    for arguments in valid {
      XCTAssertEqual(invoke("updateWidget", arguments: arguments, on: plugin) as? Bool, true)
    }
  }

  func testUnsupportedMethodsKeepIOSReturnValues() {
    let plugin = HomeWidgetPlugin()
    for method in [
      "updateWidgetPreview", "scheduleWidgetUpdates", "cancelScheduledWidgetUpdates",
      "canScheduleExactWidgetUpdates", "isRequestPinWidgetSupported",
    ] {
      XCTAssertEqual(invoke(method, on: plugin) as? Bool, false, method)
    }
    for method in [
      "requestPinWidget", "initiallyLaunchedFromHomeWidgetConfigure", "finishHomeWidgetConfigure",
    ] {
      XCTAssertNil(invoke(method, on: plugin), method)
    }
  }

  private func initialUrl(of plugin: HomeWidgetPlugin) -> String? {
    var value: String?
    var completed = false
    plugin.handle(
      FlutterMethodCall(methodName: "initiallyLaunchedFromHomeWidget", arguments: nil)
    ) { result in
      value = result as? String
      completed = true
    }
    XCTAssertTrue(completed)
    return value
  }

  func testColdLaunchCachesWidgetUrlAndEmitsEvent() {
    let plugin = HomeWidgetPlugin()
    let url = URL(string: "homewidget://launch?homeWidget")!
    var events: [String] = []
    XCTAssertNil(plugin.onListen(withArguments: nil) { events.append($0 as! String) })

    XCTAssertTrue(
      plugin.application(
        UIApplication.shared,
        didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url]
      ))

    XCTAssertEqual(initialUrl(of: plugin), url.absoluteString)
    XCTAssertEqual(events, [url.absoluteString])
  }

  func testRunningClicksPreserveInitialUrlAndEmitRepeatedEvents() {
    let plugin = HomeWidgetPlugin()
    let launch = URL(string: "homewidget://launch?homeWidget=true")!
    let click = URL(string: "homewidget://click?homeWidget=false")!
    XCTAssertTrue(
      plugin.application(
        UIApplication.shared,
        didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: launch]
      ))
    var events: [String] = []
    XCTAssertNil(plugin.onListen(withArguments: nil) { events.append($0 as! String) })
    XCTAssertTrue(events.isEmpty, "Listening does not replay the initial event")

    XCTAssertTrue(plugin.application(UIApplication.shared, open: click))
    XCTAssertTrue(plugin.application(UIApplication.shared, open: click))

    XCTAssertEqual(initialUrl(of: plugin), launch.absoluteString)
    XCTAssertEqual(events, [click.absoluteString, click.absoluteString])
  }

  func testWarmClickDoesNotCreateInitialUrl() {
    let plugin = HomeWidgetPlugin()
    XCTAssertTrue(
      plugin.application(UIApplication.shared, open: URL(string: "homewidget://click?homeWidget")!))
    XCTAssertNil(initialUrl(of: plugin))
  }

  func testOrdinaryUrlsAreNotConsumedOrEmitted() {
    let plugin = HomeWidgetPlugin()
    var events: [String] = []
    XCTAssertNil(plugin.onListen(withArguments: nil) { events.append($0 as! String) })
    for url in [
      URL(string: "homewidget://ordinary")!,
      URL(string: "homewidget://ordinary?other=homeWidget")!,
      URL(string: "homewidget://ordinary?homewidget=true")!,
    ] {
      XCTAssertTrue(
        plugin.application(
          UIApplication.shared,
          didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url]
        ))
      XCTAssertFalse(plugin.application(UIApplication.shared, open: url))
    }
    XCTAssertNil(initialUrl(of: plugin))
    XCTAssertTrue(events.isEmpty)
  }

  func testCancelStopsEventsAndLateListenerCanQueryInitialUrl() {
    let plugin = HomeWidgetPlugin()
    let url = URL(string: "homewidget://launch?homeWidget")!
    XCTAssertTrue(
      plugin.application(
        UIApplication.shared,
        didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url]
      ))
    var events: [String] = []
    XCTAssertNil(plugin.onListen(withArguments: nil) { events.append($0 as! String) })
    XCTAssertTrue(events.isEmpty)
    XCTAssertEqual(initialUrl(of: plugin), url.absoluteString)
    XCTAssertNil(plugin.onCancel(withArguments: nil))
    XCTAssertTrue(plugin.application(UIApplication.shared, open: url))
    XCTAssertTrue(events.isEmpty)
    XCTAssertEqual(initialUrl(of: plugin), url.absoluteString)
  }

  func testLifecycleSelectorsRemainVisibleToFlutter() {
    let plugin = HomeWidgetPlugin()
    let selectors = [
      "application:didFinishLaunchingWithOptions:",
      "application:openURL:options:",
      "scene:willConnectToSession:options:",
      "scene:openURLContexts:",
    ]
    for selector in selectors {
      XCTAssertTrue(plugin.responds(to: NSSelectorFromString(selector)), selector)
    }
    XCTAssertTrue(plugin.conforms(to: FlutterSceneLifeCycleDelegate.self))
  }

}

// Compile the public Swift call signatures used by existing hosts and AppIntents.
@available(iOS 17.0, *)
private func checkPublicSwiftEntryPoints() {
  let _: (FlutterPluginRegistrar) -> Void = HomeWidgetPlugin.register(with:)
  let _: ([String: any WidgetConfigurationIntent.Type]) -> Void =
    HomeWidgetPlugin.setConfigurationLookup(to:)
  let _: (@escaping FlutterPluginRegistrantCallback) -> Void =
    HomeWidgetBackgroundWorker.setPluginRegistrantCallback(registerPlugins:)
  let _: (URL?, String) async -> Void = HomeWidgetBackgroundWorker.run(url:appGroup:)
  let _: (FlutterMethodCall, @escaping FlutterResult) -> Void = HomeWidgetBackgroundWorker.handle
}
