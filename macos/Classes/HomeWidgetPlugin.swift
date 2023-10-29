import Cocoa
import FlutterMacOS
import WidgetKit

public class HomeWidgetPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
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

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HomeWidgetPlugin()

        let channel = FlutterMethodChannel(name: "home_widget", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(name: "home_widget/updates", binaryMessenger: registrar.messenger)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "setAppGroupId" {
            guard let args = call.arguments else {
                return
            }
            if let myArgs = args as? [String: Any?],
               let groupId = myArgs["groupId"] as? String {
                HomeWidgetPlugin.groupId = groupId
                result(true)
            } else {
                result(FlutterError(code: "-6", message: "InvalidArguments setAppGroupId must be called with a group id", details: nil))
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
               let data = myArgs["data"] {
                let preferences = UserDefaults(suiteName: HomeWidgetPlugin.groupId)
                if data != nil {
                    preferences?.setValue(data, forKey: id)
                } else {
                    preferences?.removeObject(forKey: id)
                }
                result(true)
            } else {
                result(FlutterError(code: "-1", message: "InvalidArguments saveWidgetData must be called with id and data", details: nil))
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
               let defaultValue = myArgs["defaultValue"] {
                let preferences = UserDefaults(suiteName: HomeWidgetPlugin.groupId)
                result(preferences?.value(forKey: id) ?? defaultValue)
            } else {
                result(FlutterError(code: "-2", message: "InvalidArguments getWidgetData must be called with id", details: nil))
            }
        } else if call.method == "updateWidget" {
            guard let args = call.arguments else {
                return
            }
            if let myArgs = args as? [String: Any?],
               let name = (myArgs["ios"] ?? myArgs["name"]) as? String {
                if #available(macOS 11.0, *) {
                    #if arch(arm64) || arch(i386) || arch(x86_64)
                        WidgetCenter.shared.reloadTimelines(ofKind: name)
                        result(true)
                    #endif
                } else {
                    result(FlutterError(code: "-4", message: "Widgets are only available on macOS 11.0 and above", details: nil))
                }
            } else {
                result(FlutterError(code: "-3", message: "InvalidArguments updateWidget must be called with name", details: nil))
            }
        } else if call.method == "initiallyLaunchedFromHomeWidget" {
            if HomeWidgetPlugin.groupId == nil {
                result(notInitializedError)
                return
            }
            result(initialUrl?.absoluteString)
        } else if call.method == "registerBackgroundCallback" {
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func isWidgetUrl(url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.contains(where: { item in item.name == "homeWidget" }) ?? false
    }
}
