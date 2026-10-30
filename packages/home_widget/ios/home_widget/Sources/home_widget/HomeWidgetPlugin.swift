import AppIntents
import Flutter
import Intents
import UIKit
import WidgetKit

public class HomeWidgetPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  FlutterSceneLifeCycleDelegate
{

  @available(iOS 17.0, *)
  private static var configurationLookup: [String: any WidgetConfigurationIntent.Type] = [:]

  @available(iOS 17.0, *)
  public static func setConfigurationLookup(
    to configuration: [String: any WidgetConfigurationIntent.Type]
  ) {
    configurationLookup = configuration
  }

  private static var groupId: String?

  private var initialUrl: URL?
  private var pendingUrls: [URL] = []
  private var sceneConnected = false

  private var eventSink: FlutterEventSink?

  private func launched(with url: URL) {
    guard initialUrl == nil else {
      clicked(url)
      return
    }
    initialUrl = url
    eventSink?(url.absoluteString)
  }

  private func clicked(_ url: URL) {
    if let eventSink = eventSink {
      eventSink(url.absoluteString)
    } else {
      pendingUrls.append(url)
    }
  }

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
    return HomeWidgetPlugin.groupId
  }

  private static func isRunningInAppExtension() -> Bool {
    let bundleURL = Bundle.main.bundleURL
    let bundlePathExtension = bundleURL.pathExtension
    return bundlePathExtension == "appex"
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = registerChannels(with: registrar)

    guard !isRunningInAppExtension() else {
      return
    }
    // The engine a widget interaction runs in only needs the channels: as an application delegate
    // it would sit in the delegate chain next to the app's own instance.
    if #available(iOS 17, *), HomeWidgetBackgroundWorker.isRegisteringPlugins {
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

  /// Sets up the `home_widget` method channel and the `home_widget/updates` event channel on
  /// the messenger of `registrar`, without adding the plugin as an application or scene delegate.
  @discardableResult
  public static func registerChannels(with registrar: FlutterPluginRegistrar) -> HomeWidgetPlugin {
    let instance = HomeWidgetPlugin()

    let channel = FlutterMethodChannel(name: "home_widget", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)

    let eventChannel = FlutterEventChannel(
      name: "home_widget/updates", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)

    return instance
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "setAppGroupId" {
      guard let args = call.arguments else {
        return
      }
      if let myArgs = args as? [String: Any?],
        let groupId = myArgs["groupId"] as? String
      {
        HomeWidgetPlugin.groupId = groupId
        result(true)
      } else {
        result(
          FlutterError(
            code: "-6", message: "InvalidArguments setAppGroupId must be called with a group id",
            details: nil))
      }
    } else if call.method == "saveWidgetData" {
      guard let resolvedGroupId = resolvedAppGroupId(from: call) else {
        result(notInitializedError)
        return
      }
      guard let args = call.arguments else {
        return
      }
      if let myArgs = args as? [String: Any?],
        let id = myArgs["id"] as? String,
        let data = myArgs["data"]
      {
        let preferences = UserDefaults.init(suiteName: resolvedGroupId)
        // Dart null values in method-channel arguments arrive as NSNull.
        if data != nil && !(data is NSNull) {
          if let binaryData = data as? FlutterStandardTypedData {
            preferences?.setValue(Data(binaryData.data), forKey: id)
          } else {
            preferences?.setValue(data, forKey: id)
          }
        } else {
          preferences?.removeObject(forKey: id)
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
      guard let args = call.arguments else {
        return
      }
      if let myArgs = args as? [String: Any?],
        let id = myArgs["id"] as? String,
        let defaultValue = myArgs["defaultValue"]
      {
        let preferences = UserDefaults.init(suiteName: resolvedGroupId)
        result(preferences?.value(forKey: id) ?? defaultValue)
      } else {
        result(
          FlutterError(
            code: "-2", message: "InvalidArguments getWidgetData must be called with id",
            details: nil))
      }
    } else if call.method == "updateWidget" {

      guard let args = call.arguments else {
        return
      }
      if let myArgs = args as? [String: Any?] {
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
          if #available(iOS 14.0, *) {
            #if arch(arm64) || arch(i386) || arch(x86_64)
              WidgetCenter.shared.reloadTimelines(ofKind: name)
              result(true)
            #endif
          } else {
            result(
              FlutterError(
                code: "-4", message: "Widgets are only available on iOS 14.0 and above",
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
      // [dispatcher, callback] or [dispatcher, callback, key, appGroupId]
      let arguments = call.arguments as! [Any]
      let key = arguments.count > 2 ? arguments[2] as? String : nil
      let appGroupId = arguments.count > 3 ? arguments[3] as? String : nil
      guard let resolvedGroupId = appGroupId ?? HomeWidgetPlugin.groupId else {
        result(notInitializedError)
        return
      }
      if #available(iOS 17.0, *) {
        let dispatcher = arguments[0] as! Int64
        let callback = arguments[1] as! Int64
        let preferences = UserDefaults.init(suiteName: resolvedGroupId)
        preferences?.setValue(dispatcher, forKey: HomeWidgetBackgroundWorker.dispatcherKey)
        preferences?.setValue(
          callback, forKey: HomeWidgetBackgroundWorker.callbackStorageKey(for: key))
        if HomeWidgetBackgroundWorker.engine == nil {
          HomeWidgetBackgroundWorker.setupEngine(dispatcher: dispatcher)
        }

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
    } else if call.method == "isRequestPinWidgetSupported" {
      result(false)
    } else if call.method == "requestPinWidget" {
      result(nil)
    } else if call.method == "initiallyLaunchedFromHomeWidgetConfigure" {
      result(nil)
    } else if call.method == "finishHomeWidgetConfigure" {
      result(nil)
    } else if call.method == "getInstalledWidgets" {
      if #available(iOS 14.0, *) {
        #if arch(arm64) || arch(i386) || arch(x86_64)
          WidgetCenter.shared.getCurrentConfigurations { result2 in
            switch result2 {
            case .success(let widgets):
              let widgetInfoList = widgets.map { widget in
                var configuration: [String: Any] = [String: Any]()

                var intent: Any?
                if widget.configuration != nil {
                  intent = widget.configuration
                } else if #available(iOS 17.0, *),
                  let intentType = HomeWidgetPlugin.configurationLookup[widget.kind]
                {
                  intent = widget.widgetConfigurationIntent(of: intentType)

                }

                if let intent = intent {

                  var intentData: [String: Any?] = [:]
                  if #available(iOS 17.0, *),
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
        #endif
      } else {
        result(
          FlutterError(
            code: "-4", message: "Widgets are only available on iOS 14.0 and above", details: nil)
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
    let urls = pendingUrls
    pendingUrls.removeAll()
    for url in urls {
      events(url.absoluteString)
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
  ) -> Bool {
    let launchUrl = (launchOptions[UIApplication.LaunchOptionsKey.url] as? NSURL)?.absoluteURL
    if let launchUrl = launchUrl, isWidgetUrl(url: launchUrl) {
      launched(with: launchUrl.absoluteURL)
    }
    return true
  }

  public func application(
    _ application: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if isWidgetUrl(url: url) {
      clicked(url)
      return true
    }
    return false
  }

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    let isLaunch = !sceneConnected
    sceneConnected = true
    guard let urlContexts = connectionOptions?.urlContexts else {
      return false
    }
    for context in urlContexts {
      let url = context.url
      if isWidgetUrl(url: url) {
        if isLaunch {
          launched(with: url)
        } else {
          clicked(url)
        }
        return true
      }
    }
    return false
  }

  public func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
    for context in urlContexts {
      let url = context.url
      if isWidgetUrl(url: url) {
        clicked(url)
        return true
      }
    }
    return false
  }

  private func isWidgetUrl(url: URL) -> Bool {
    let components = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
    return components?.queryItems?.contains(where: { (item) in item.name == "homeWidget" }) ?? false
  }
}

protocol _AnyIntentParameter {

  var anyWrappedValue: Any { get }
}

@available(iOS 16.0, *)
extension IntentParameter: _AnyIntentParameter {
  var anyWrappedValue: Any {
    return wrappedValue
  }
}
