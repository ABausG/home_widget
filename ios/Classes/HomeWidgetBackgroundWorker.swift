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

  static func setupEngine(dispatcher: Int64) {
    engine = FlutterEngine(
      name: "home_widget_background", project: nil, allowHeadlessExecution: true)

    channel = FlutterMethodChannel(
      name: "home_widget/background", binaryMessenger: engine!.binaryMessenger,
      codec: FlutterStandardMethodCodec.sharedInstance()
    )
    let flutterCallbackInfo = FlutterCallbackCache.lookupCallbackInformation(dispatcher)
    let callbackName = flutterCallbackInfo?.callbackName
    let callbackLibrary = flutterCallbackInfo?.callbackLibraryPath

    let started = engine?.run(
      withEntrypoint: flutterCallbackInfo?.callbackName,
      libraryURI: flutterCallbackInfo?.callbackLibraryPath)
    if registerPlugins != nil {
      registerPlugins?(engine!)
    } else {
      HomeWidgetPlugin.register(with: engine!.registrar(forPlugin: "home_widget")!)
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
      _channel.invokeMethod("", arguments: [_callback, url?.absoluteString]) { _ in
        continuation.resume()
      }
    }
  }
}
