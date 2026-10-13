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
  static var currentDispatcher: Int64?

  private static var registerPlugins: FlutterPluginRegistrantCallback?

  public static func setPluginRegistrantCallback(registerPlugins: FlutterPluginRegistrantCallback) {
    self.registerPlugins = registerPlugins
  }

  /// Call this method to invoke the callback registered in your Flutter App.
  /// The url you provide will be used as arguments in the callback function in dart
  /// The AppGroup is necessary to retrieve the dart callbacks
  static public func run(url: URL?, appGroup: String) async {
    if isSetupCompleted == false {
      await withCheckedContinuation { continuation in
        continuations.append(continuation)
      }
    }

    let preferences = UserDefaults.init(suiteName: appGroup)
    let dispatcher = preferences?.object(forKey: dispatcherKey) as! Int64
    NSLog("Dispatcher: \(dispatcher)")

    await sendEvent(url: url, appGroup: appGroup)
  }

  /// Spins up the headless background `FlutterEngine` that runs the Dart
  /// interactivity callback and wires the `home_widget/background` method
  /// channel used to dispatch widget-triggered events into Dart. If a custom
  /// `FlutterPluginRegistrantCallback` has been supplied via
  /// `setPluginRegistrantCallback` it is invoked to register any additional
  /// plugins needed by the background isolate; otherwise only the
  /// `home_widget` channels are registered on the background engine to avoid
  /// perturbing the host app's plugin delegate chain. Re-entrant: if the same
  /// dispatcher is re-registered after a completed setup the call is a no-op;
  /// if the dispatcher changes, or the previous setup never finished handshake
  /// with Dart (`HomeWidget.backgroundInitialized` was never received), the
  /// previous engine is torn down and a fresh one is spun up so the caller
  /// always has a usable background isolate.
  static func setupEngine(dispatcher: Int64) {
    if engine != nil && currentDispatcher == dispatcher && isSetupCompleted {
      return
    }

    if let previous = engine {
      channel?.setMethodCallHandler(nil)
      previous.destroyContext()
      engine = nil
      channel = nil
      isSetupCompleted = false
      // Unblock any pending `run` waiters — the engine they were waiting on is
      // gone and a new one is about to be created that will emit its own
      // `backgroundInitialized`. Leaving them suspended would deadlock.
      while !continuations.isEmpty {
        continuations.removeFirst().resume()
      }
    }
    currentDispatcher = dispatcher

    engine = FlutterEngine(
      name: "home_widget_background", project: nil, allowHeadlessExecution: true)

    channel = FlutterMethodChannel(
      name: "home_widget/background", binaryMessenger: engine!.binaryMessenger,
      codec: FlutterStandardMethodCodec.sharedInstance()
    )
    let flutterCallbackInfo = FlutterCallbackCache.lookupCallbackInformation(dispatcher)

    engine?.run(
      withEntrypoint: flutterCallbackInfo?.callbackName,
      libraryURI: flutterCallbackInfo?.callbackLibraryPath)
    if registerPlugins != nil {
      registerPlugins?(engine!)
    } else {
      // Register only the channels on the background engine — do NOT add a
      // second HomeWidgetPlugin to the main app's UIApplication delegate chain,
      // which breaks URL/life-cycle callbacks in other plugins (issue #408).
      HomeWidgetPlugin.registerChannels(
        with: engine!.registrar(forPlugin: "home_widget")!)
    }

    channel?.setMethodCallHandler(handle)
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

  static func sendEvent(url: URL?, appGroup: String) async {
    guard let _channel = channel else {
      return
    }
    let preferences = UserDefaults.init(suiteName: appGroup)
    guard let _callback = preferences?.object(forKey: callbackKey) as? Int64 else {
      return
    }
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        _channel.invokeMethod("", arguments: [_callback, url?.absoluteString]) { _ in
          continuation.resume()
        }
      }
    }
  }
}
