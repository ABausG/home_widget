import AppIntents
import Flutter
import Intents
import UIKit
import WidgetKit

public class HomeWidgetPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

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

  private static func isRunningInAppExtension() -> Bool {
    let bundleURL = Bundle.main.bundleURL
    let bundlePathExtension = bundleURL.pathExtension
    return bundlePathExtension == "appex"
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HomeWidgetPlugin()

    let channel = FlutterMethodChannel(name: "home_widget", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)

    let eventChannel = FlutterEventChannel(
      name: "home_widget/updates", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)

    guard isRunningInAppExtension() == false else {
      return
    }

    let selector = NSSelectorFromString("addApplicationDelegate:")
    if registrar.responds(to: selector) {
      registrar.perform(selector, with: instance)
    }
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
      if HomeWidgetPlugin.groupId == nil {
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
        let preferences = UserDefaults.init(suiteName: HomeWidgetPlugin.groupId)
        if data != nil {
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
      if HomeWidgetPlugin.groupId == nil {
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
        let preferences = UserDefaults.init(suiteName: HomeWidgetPlugin.groupId)
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
      if let myArgs = args as? [String: Any?],
        let name = (myArgs["ios"] ?? myArgs["name"]) as? String
      {
        if #available(iOS 14.0, *) {
          #if arch(arm64) || arch(i386) || arch(x86_64)
            WidgetCenter.shared.reloadTimelines(ofKind: name)
            result(true)
          #endif
        } else {
          result(
            FlutterError(
              code: "-4", message: "Widgets are only available on iOS 14.0 and above", details: nil)
          )
        }
      } else {
        result(
          FlutterError(
            code: "-3", message: "InvalidArguments updateWidget must be called with name",
            details: nil))
      }
    } else if call.method == "initiallyLaunchedFromHomeWidget" {
      if HomeWidgetPlugin.groupId == nil {
        result(notInitializedError)
        return
      }
      result(initialUrl?.absoluteString)
    } else if call.method == "registerBackgroundCallback" {
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
    } else if call.method == "isRequestPinWidgetSupported" {
      result(false)
    } else if call.method == "requestPinWidget" {
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
                } else if #available(iOS 17.0, *), let intentType = HomeWidgetPlugin.configurationLookup[widget.kind] {
                  intent = widget.widgetConfigurationIntent(of: intentType)

                }

                if let intent = intent {

                  var intentData: [String: Any?] = [:]
                  if #available(iOS 17.0, *), let configurationIntent = intent as? (any WidgetConfigurationIntent) {
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
    if launchUrl != nil && isWidgetUrl(url: launchUrl!) {
      initialUrl = launchUrl?.absoluteURL
      latestUrl = initialUrl
    }
    return true
  }

  public func application(
    _ application: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if isWidgetUrl(url: url) {
      latestUrl = url
      return true
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
