import AppIntents
import Foundation
import Intents
import WidgetKit

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import FlutterMacOS
  import Security
#endif

public class HomeWidgetPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  @available(iOS 17.0, macOS 14.0, *)
  private static var configurationLookup: [String: any WidgetConfigurationIntent.Type] = [:]

  @available(iOS 17.0, macOS 14.0, *)
  public static func setConfigurationLookup(
    to configuration: [String: any WidgetConfigurationIntent.Type]
  ) {
    configurationLookup = configuration
  }

  private static var groupId: String?

  #if os(macOS)
    private var macOSLaunching = false
    private var macOSGroupId: String?
    private var backgroundAppGroup: String?
    private weak var backgroundEngine: FlutterEngine?
  #endif

  private var initialUrl: URL?
  private var latestUrl: URL? {
    didSet {
      if latestUrl != nil {
        eventSink?.self(latestUrl?.absoluteString)
      }
    }
  }

  private var eventSink: FlutterEventSink?

  private let notInitializedError = FlutterError(
    code: "-7", message: "AppGroupId not set. Call setAppGroupId first", details: nil)

  private func callArguments(_ call: FlutterMethodCall) -> [String: Any?]? {
    return call.arguments as? [String: Any?]
  }

  private func resolvedAppGroupId(from call: FlutterMethodCall) -> String? {
    if let args = callArguments(call),
      let appGroupId = args["appGroupId"] as? String
    {
      return appGroupId
    }
    return defaultAppGroupId
  }

  private static var isRunningInAppExtension: Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
  }

  private func isAppGroupAuthorized(_ appGroupId: String, result: FlutterResult) -> Bool {
    guard Self.isAppGroupAuthorized(appGroupId)
    else {
      result(
        FlutterError(
          code: "-9", message: "App Group is not authorized by this process's entitlement",
          details: appGroupId))
      return false
    }
    return true
  }

  private func widgetPreferences(for appGroupId: String, result: FlutterResult) -> UserDefaults? {
    guard isAppGroupAuthorized(appGroupId, result: result) else {
      return nil
    }
    guard let preferences = UserDefaults(suiteName: appGroupId) else {
      result(
        FlutterError(
          code: "-9", message: "App Group preferences are unavailable", details: appGroupId))
      return nil
    }
    return preferences
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HomeWidgetPlugin()

    let messenger = instance.prepareForRegistration(with: registrar)
    let channel = FlutterMethodChannel(name: "home_widget", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)

    let eventChannel = FlutterEventChannel(
      name: "home_widget/updates", binaryMessenger: messenger)
    eventChannel.setStreamHandler(instance)
    registerLifecycleDelegates(instance, with: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "setAppGroupId" {
      if let myArgs = call.arguments as? [String: Any?],
        let groupId = myArgs["groupId"] as? String
      {
        setAppGroupId(groupId, result: result)
      } else {
        result(
          FlutterError(
            code: "-6", message: "InvalidArguments setAppGroupId must be called with a group id",
            details: nil))
      }
    } else if call.method == "getWidgetContainerPath" {
      guard let resolvedGroupId = resolvedAppGroupId(from: call) else {
        result(notInitializedError)
        return
      }
      guard isAppGroupAuthorized(resolvedGroupId, result: result) else {
        return
      }
      guard
        let container = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: resolvedGroupId)
      else {
        result(
          FlutterError(
            code: "-10", message: "App Group container is unavailable", details: resolvedGroupId))
        return
      }
      result(container.path)
    } else if call.method == "saveWidgetData" {
      guard let resolvedGroupId = resolvedAppGroupId(from: call) else {
        result(notInitializedError)
        return
      }
      if let myArgs = call.arguments as? [String: Any?],
        let id = myArgs["id"] as? String,
        let data = myArgs["data"]
      {
        guard let preferences = widgetPreferences(for: resolvedGroupId, result: result) else {
          return
        }
        // Dart null values in method-channel arguments arrive as NSNull.
        if let data = data, !(data is NSNull) {
          let value: Any
          if let binaryData = data as? FlutterStandardTypedData {
            value = Data(binaryData.data)
          } else {
            value = data
          }
          guard PropertyListSerialization.propertyList(value, isValidFor: .binary) else {
            result(
              FlutterError(
                code: "-1", message: "Widget data must be a property-list value", details: nil))
            return
          }
          preferences.setValue(value, forKey: id)
        } else {
          preferences.removeObject(forKey: id)
        }
        result(true)
      } else {
        result(
          FlutterError(
            code: "-1", message: "InvalidArguments saveWidgetData must be called with id and data",
            details: nil))
      }
    } else if call.method == "getWidgetData" {
      guard let resolvedGroupId = resolvedAppGroupId(from: call) else {
        result(notInitializedError)
        return
      }
      if let myArgs = call.arguments as? [String: Any?],
        let id = myArgs["id"] as? String,
        let defaultValue = myArgs["defaultValue"]
      {
        guard let preferences = widgetPreferences(for: resolvedGroupId, result: result) else {
          return
        }
        result(preferences.value(forKey: id) ?? defaultValue)
      } else {
        result(
          FlutterError(
            code: "-2", message: "InvalidArguments getWidgetData must be called with id",
            details: nil))
      }
    } else if call.method == "updateWidget" {

      if let myArgs = call.arguments as? [String: Any?] {
        // Check ios first, then fall back to name
        // Handle NSNull explicitly since nil-coalescing doesn't work with NSNull
        let iosValue = myArgs["ios"]
        let nameValue = myArgs["name"]
        let widgetName: String?

        if let iosString = iosValue as? String {
          widgetName = iosString
        } else if let nameString = nameValue as? String {
          widgetName = nameString
        } else {
          widgetName = nil
        }

        if let name = widgetName {
          if #available(iOS 14.0, macOS 11.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: name)
            result(true)
          } else {
            result(
              FlutterError(
                code: "-4", message: "Widgets require iOS 14.0 or macOS 11.0 and above",
                details: nil)
            )
          }
        } else {
          result(
            FlutterError(
              code: "-3", message: "InvalidArguments updateWidget must be called with name",
              details: nil))
        }
      } else {
        result(
          FlutterError(
            code: "-3", message: "InvalidArguments updateWidget must be called with name",
            details: nil))
      }
    } else if call.method == "updateWidgetPreview" {
      // Generated previews are Android only. WidgetKit renders the gallery preview itself by
      // calling the Widget's getSnapshot with context.isPreview set, so there is no preview for
      // the plugin to push here.
      result(false)
    } else if call.method == "scheduleWidgetUpdates"
      || call.method == "cancelScheduledWidgetUpdates"
      || call.method == "canScheduleExactWidgetUpdates"
    {
      // Scheduling is Android only. On iOS a Widget decides for itself when its content changes
      // by returning future TimelineEntries from its TimelineProvider, so the plugin neither
      // schedules nor cancels anything here and cannot promise exact updates either: WidgetKit
      // renders entries on a best effort basis. Returning false keeps that honest instead of
      // reporting a schedule that does not exist.
      result(false)
    } else if call.method == "initiallyLaunchedFromHomeWidget" {
      result(initialUrl?.absoluteString)
    } else if call.method == "registerBackgroundCallback" {
      registerBackgroundCallback(call, result: result)
    } else if call.method == "isRequestPinWidgetSupported" {
      result(false)
    } else if call.method == "requestPinWidget" {
      result(nil)
    } else if call.method == "initiallyLaunchedFromHomeWidgetConfigure" {
      result(nil)
    } else if call.method == "finishHomeWidgetConfigure" {
      result(nil)
    } else if call.method == "getInstalledWidgets" {
      if #available(iOS 14.0, macOS 11.0, *) {
        WidgetCenter.shared.getCurrentConfigurations { result2 in
          switch result2 {
          case .success(let widgets):
            let widgetInfoList = widgets.map { widget in
              var configuration: [String: Any] = [String: Any]()

              var intent: Any?
              if widget.configuration != nil {
                intent = widget.configuration
              } else if #available(iOS 17.0, macOS 14.0, *),
                let intentType = HomeWidgetPlugin.configurationLookup[widget.kind]
              {
                intent = widget.widgetConfigurationIntent(of: intentType)

              }

              if let intent = intent {

                var intentData: [String: Any?] = [:]
                if #available(iOS 17.0, macOS 14.0, *),
                  let configurationIntent = intent as? (any WidgetConfigurationIntent)
                {
                  let mirror = Mirror(reflecting: configurationIntent)
                  for (name, value) in mirror.children {
                    if let name {
                      intentData[name] = value
                    }
                  }
                } else if let configurationIntent = intent as? INIntent {
                  let intentClass: AnyClass = type(of: configurationIntent)

                  var count: UInt32 = 0
                  if let properties = class_copyPropertyList(intentClass, &count) {
                    for i in 0..<count {
                      let property = property_getName(properties[Int(i)])
                      if let propertyName = String(utf8String: property) {

                        let value = configurationIntent.value(forKey: propertyName)
                        intentData[propertyName] = value
                      }

                    }
                    free(properties)
                  }
                }
                if !intentData.isEmpty {

                  for (internalPropertyName, rawValue) in intentData {
                    let propertyName =
                      internalPropertyName.hasPrefix("_") == true
                      ? String(internalPropertyName.dropFirst())
                      : internalPropertyName

                    let value: Any?

                    if let intentParameter = rawValue as? _AnyIntentParameter {
                      // Get the wrapped value from the IntentParameter. Used for WidgetConfigurationIntent
                      value = intentParameter.anyWrappedValue
                    } else {
                      // Use rawValue if it is not an IntentParameter
                      value = rawValue
                    }
                    switch value {
                    case is NSNull:
                      configuration[propertyName] = NSNull()

                    case let boolValue as Bool:
                      configuration[propertyName] = boolValue

                    case let intValue as Int32:
                      configuration[propertyName] = NSNumber(value: intValue)

                    case let intValue as Int:
                      configuration[propertyName] = NSNumber(value: intValue)

                    case let doubleValue as Double:
                      configuration[propertyName] = NSNumber(value: doubleValue)

                    case let stringValue as String:
                      configuration[propertyName] = stringValue

                    case let dataValue as Data:
                      configuration[propertyName] = FlutterStandardTypedData(bytes: dataValue)

                    case let arrayValue as [Any]:
                      configuration[propertyName] = arrayValue

                    case let dictionaryValue as [String: Any]:
                      configuration[propertyName] = dictionaryValue

                    case let dateValue as Date:
                      let dateFormatter = ISO8601DateFormatter()
                      configuration[propertyName] = dateFormatter.string(from: dateValue)

                    case let urlValue as URL:
                      configuration[propertyName] = urlValue.absoluteString

                    // Handle Codable types by trying to convert to a dictionary
                    case let codableValue as (any Codable):
                      let encoder = JSONEncoder()
                      do {
                        let data = try encoder.encode(codableValue)
                        if let jsonObject = try JSONSerialization.jsonObject(
                          with: data, options: []) as? [String: Any]
                        {
                          configuration[propertyName] = jsonObject
                        }
                      } catch {
                        if let value = value {
                          configuration[propertyName] = "\(value)"
                        } else {
                          configuration[propertyName] = nil
                        }

                      }

                    case let inObject as INObject:
                      configuration[propertyName] = [
                        "identifier": inObject.identifier,
                        "displayString": inObject.displayString,
                      ]

                    default:
                      if let value = value {
                        configuration[propertyName] = "\(value)"
                      } else {
                        configuration[propertyName] = nil
                      }
                    }
                  }
                }
              }

              var resultMap: [String: Any] = [
                "family": "\(widget.family)",
                "kind": widget.kind,
              ]

              if !configuration.isEmpty {
                resultMap["configuration"] = configuration
              }

              return resultMap
            }
            result(widgetInfoList)
          case .failure(let error):
            result(
              FlutterError(
                code: "-8",
                message: "Failed to get installed widgets: \(error.localizedDescription)",
                details: nil))
          }
        }
      } else {
        result(
          FlutterError(
            code: "-4", message: "Widgets require iOS 14.0 or macOS 11.0 and above", details: nil)
        )
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // Lifecycle adapters share URL state without exposing it outside the plugin.
  private func receiveWidgetUrl(_ url: URL, isInitial: Bool) -> Bool {
    guard isWidgetUrl(url: url) else {
      return false
    }
    if isInitial {
      initialUrl = url
    }
    latestUrl = url
    return true
  }

  private func isWidgetUrl(url: URL) -> Bool {
    let components = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
    return components?.queryItems?.contains(where: { (item) in item.name == "homeWidget" }) ?? false
  }
}

protocol _AnyIntentParameter {

  var anyWrappedValue: Any { get }
}

@available(iOS 16.0, macOS 13.0, *)
extension IntentParameter: _AnyIntentParameter {
  var anyWrappedValue: Any {
    return wrappedValue
  }
}

#if os(iOS)
  // MARK: - iOS

  extension HomeWidgetPlugin: FlutterSceneLifeCycleDelegate {
    private var defaultAppGroupId: String? {
      return HomeWidgetPlugin.groupId
    }

    private func prepareForRegistration(
      with registrar: FlutterPluginRegistrar
    ) -> FlutterBinaryMessenger {
      return registrar.messenger()
    }

    private static func isAppGroupAuthorized(_ appGroupId: String) -> Bool {
      return true
    }

    private func setAppGroupId(_ groupId: String, result: FlutterResult) {
      HomeWidgetPlugin.groupId = groupId
      result(true)
    }

    private func registerBackgroundCallback(
      _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
      if HomeWidgetPlugin.groupId == nil {
        result(notInitializedError)
        return
      }
      if #available(iOS 17.0, *) {
        let callbackHandles = call.arguments as! [Int64]
        let dispatcher = callbackHandles[0]
        let callback = callbackHandles[1]
        let preferences = UserDefaults.init(suiteName: HomeWidgetPlugin.groupId)
        preferences?.setValue(dispatcher, forKey: HomeWidgetBackgroundWorker.dispatcherKey)
        preferences?.setValue(callback, forKey: HomeWidgetBackgroundWorker.callbackKey)
        HomeWidgetBackgroundWorker.setupEngine(dispatcher: dispatcher)

        result(true)
        return
      } else {
        result(
          FlutterError(
            code: "-5",
            message:
              "Interactivity is only available on iOS 17.0",
            details: nil))
      }
    }

    private static func registerLifecycleDelegates(
      _ instance: HomeWidgetPlugin, with registrar: FlutterPluginRegistrar
    ) {
      guard !Self.isRunningInAppExtension else {
        return
      }

      // Runtime registration avoids compile errors when this module is built for app extensions.
      let applicationDelegateSelector = NSSelectorFromString("addApplicationDelegate:")
      if registrar.responds(to: applicationDelegateSelector) {
        registrar.perform(applicationDelegateSelector, with: instance)
      }
      let sceneDelegateSelector = NSSelectorFromString("addSceneDelegate:")
      if registrar.responds(to: sceneDelegateSelector) {
        registrar.perform(sceneDelegateSelector, with: instance)
      }
    }

    public func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
    ) -> Bool {
      let launchUrl = (launchOptions[UIApplication.LaunchOptionsKey.url] as? NSURL)?.absoluteURL
      if let launchUrl = launchUrl {
        _ = receiveWidgetUrl(launchUrl.absoluteURL, isInitial: true)
      }
      return true
    }

    public func application(
      _ application: UIApplication, open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
      return receiveWidgetUrl(url, isInitial: false)
    }

    public func scene(
      _ scene: UIScene,
      willConnectTo session: UISceneSession,
      options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
      guard let urlContexts = connectionOptions?.urlContexts else {
        return false
      }
      for context in urlContexts {
        if receiveWidgetUrl(context.url, isInitial: true) {
          return true
        }
      }
      return false
    }

    public func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool
    {
      for context in urlContexts {
        if receiveWidgetUrl(context.url, isInitial: false) {
          return true
        }
      }
      return false
    }
  }
#elseif os(macOS)
  // MARK: - macOS

  extension HomeWidgetPlugin {
    private var defaultAppGroupId: String? {
      return macOSGroupId
    }

    private func prepareForRegistration(
      with registrar: FlutterPluginRegistrar
    ) -> FlutterBinaryMessenger {
      let messenger = registrar.messenger
      if let background = HomeWidgetBackgroundWorker.backgroundEngine(for: messenger) {
        backgroundAppGroup = background.appGroup
        backgroundEngine = background.engine
        macOSGroupId = background.appGroup
      }
      return messenger
    }

    static func isAppGroupAuthorized(_ appGroupId: String) -> Bool {
      // A suite can be created even when the process cannot access the shared group.
      guard let task = SecTaskCreateFromSelf(nil),
        let groups = SecTaskCopyValueForEntitlement(
          task, "com.apple.security.application-groups" as CFString, nil) as? [String]
      else { return false }
      return groups.contains(appGroupId)
    }

    private func setAppGroupId(_ groupId: String, result: FlutterResult) {
      if let backgroundGroup = backgroundAppGroup, backgroundGroup != groupId {
        result(
          FlutterError(code: "-11", message: "Background App Group cannot change", details: nil)
        )
        return
      }
      macOSGroupId = groupId
      result(true)
    }

    private func registerBackgroundCallback(
      _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
      guard let group = macOSGroupId else {
        result(notInitializedError)
        return
      }
      guard let preferences = widgetPreferences(for: group, result: result) else { return }
      guard let handles = HomeWidgetBackgroundWorker.callbackHandles(call.arguments)
      else {
        result(
          FlutterError(
            code: "-6", message: "Expected dispatcher and callback handles", details: nil))
        return
      }
      guard !Self.isRunningInAppExtension else {
        result(
          FlutterError(
            code: "-11", message: "Background execution belongs to the host app", details: nil))
        return
      }
      if backgroundAppGroup != nil {
        guard let backgroundEngine,
          HomeWidgetBackgroundWorker.isCurrentBackgroundEngine(backgroundEngine, handles: handles)
        else {
          result(
            FlutterError(
              code: "-11", message: "Background callback registration is stale or mismatched",
              details: nil))
          return
        }
      } else {
        guard HomeWidgetBackgroundWorker.setupEngine(appGroup: group, handles: handles) else {
          result(
            FlutterError(
              code: "-11", message: "Background engine could not start or is busy", details: nil))
          return
        }
        preferences.set(handles[0], forKey: HomeWidgetBackgroundWorker.dispatcherKey)
        preferences.set(handles[1], forKey: HomeWidgetBackgroundWorker.callbackKey)
      }
      result(true)
    }

    private static func registerLifecycleDelegates(
      _ instance: HomeWidgetPlugin, with registrar: FlutterPluginRegistrar
    ) {
      guard instance.backgroundAppGroup == nil, !Self.isRunningInAppExtension
      else {
        return
      }

      registrar.addApplicationDelegate(instance)
    }

    public func handleWillFinishLaunching(_ notification: Notification) {
      macOSLaunching = true
    }

    public func handleDidFinishLaunching(_ notification: Notification) {
      macOSLaunching = false
    }

    public func handleOpen(_ urls: [URL]) -> Bool {
      guard !urls.isEmpty else { return false }
      let isInitial = macOSLaunching
      var handled = false
      for url in urls {
        if receiveWidgetUrl(url, isInitial: isInitial && initialUrl == nil) {
          handled = true
        }
      }
      return handled
    }
  }
#endif
