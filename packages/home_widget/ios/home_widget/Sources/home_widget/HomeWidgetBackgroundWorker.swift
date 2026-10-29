//
//  HomeWidgetBackgroundIntent.swift
//  home_widget
//
//  Created by Anton Borries on 25.08.23.
//

import Flutter
import Foundation
import Swift

@available(iOS 17, *)
public struct HomeWidgetBackgroundWorker {

  static let dispatcherKey: String = "home_widget.internal.background.dispatcher"
  static let callbackKey: String = "home_widget.internal.background.callback"

  static var engine: FlutterEngine?
  static var channel: FlutterMethodChannel?

  static var isSetupCompleted: Bool = false
  static var continuations: [CheckedContinuation<Void, Never>] = []

  private static var registerPlugins: FlutterPluginRegistrantCallback?

  public static func setPluginRegistrantCallback(registerPlugins: FlutterPluginRegistrantCallback) {
    self.registerPlugins = registerPlugins
  }

  /// Call this method to invoke the callback registered in your Flutter App.
  /// The url you provide will be used as arguments in the callback function in dart
  /// The AppGroup is necessary to retrieve the dart callbacks
  static public func run(url: URL?, appGroup: String) async {
    await run(url: url, appGroup: appGroup, key: nil)
  }

  /// Invokes the callback that was registered with the given key in your Flutter App.
  /// Falls back to the callback registered without a key if the key is nil or nothing was
  /// registered for it.
  ///
  /// When the process runs no background engine yet, because the app was launched for this call
  /// and has not registered a callback since, the engine is started from the dispatcher an
  /// earlier registration stored in the AppGroup.
  static public func run(url: URL?, appGroup: String, key: String?) async {
    let hasEngine = await MainActor.run { startEngineIfNeeded(appGroup: appGroup) }
    let callback = callbackHandle(in: UserDefaults.init(suiteName: appGroup), key: key)
    guard hasEngine, let callback = callback else {
      NSLog(
        "home_widget: No interactivity callback is registered in \(appGroup). "
          + "Call HomeWidget.registerInteractivityCallback in the app first.")
      return
    }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.main.async {
        if isSetupCompleted {
          continuation.resume()
        } else {
          continuations.append(continuation)
        }
      }
    }

    await sendEvent(url: url, callback: callback)
  }

  static func callbackStorageKey(for key: String?) -> String {
    guard let key = key else {
      return callbackKey
    }
    return "\(callbackKey).\(key)"
  }

  static func callbackHandle(in preferences: UserDefaults?, key: String?) -> Int64? {
    if let key = key,
      let keyed = preferences?.object(forKey: callbackStorageKey(for: key)) as? Int64
    {
      return keyed
    }
    return preferences?.object(forKey: callbackKey) as? Int64
  }

  /// Whether a background engine is running, after starting one from the dispatcher stored in
  /// the AppGroup if there was none. Must be called on the main thread.
  static func startEngineIfNeeded(appGroup: String) -> Bool {
    if engine != nil {
      return true
    }
    guard
      let dispatcher = UserDefaults.init(suiteName: appGroup)?.object(forKey: dispatcherKey)
        as? Int64
    else {
      return false
    }
    return setupEngine(dispatcher: dispatcher, requiresCallback: true)
  }

  /// Starts the background engine at the dispatcher. With `requiresCallback` no engine is
  /// started for a dispatcher the callback cache does not know, which would run the main
  /// entrypoint of the app instead.
  @discardableResult
  static func setupEngine(dispatcher: Int64, requiresCallback: Bool = false) -> Bool {
    let backgroundEngine = FlutterEngine(
      name: "home_widget_background", project: nil, allowHeadlessExecution: true)
    let flutterCallbackInfo = FlutterCallbackCache.lookupCallbackInformation(dispatcher)
    if requiresCallback && flutterCallbackInfo == nil {
      return false
    }
    engine = backgroundEngine

    channel = FlutterMethodChannel(
      name: "home_widget/background", binaryMessenger: backgroundEngine.binaryMessenger,
      codec: FlutterStandardMethodCodec.sharedInstance()
    )

    _ = backgroundEngine.run(
      withEntrypoint: flutterCallbackInfo?.callbackName,
      libraryURI: flutterCallbackInfo?.callbackLibraryPath)
    if let registerPlugins = registerPlugins {
      registerPlugins(backgroundEngine)
    } else if let registrar = backgroundEngine.registrar(forPlugin: "home_widget") {
      HomeWidgetPlugin.register(with: registrar)
    }

    channel?.setMethodCallHandler(handle)
    return true
  }

  public static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "HomeWidget.backgroundInitialized":
      isSetupCompleted = true
      while !continuations.isEmpty {
        let continuation = continuations.removeFirst()
        continuation.resume()
      }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func sendEvent(url: URL?, callback: Int64) async {
    guard let _channel = channel else {
      return
    }
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        _channel.invokeMethod("", arguments: [callback, url?.absoluteString]) { _ in
          continuation.resume()
        }
      }
    }
  }
}
