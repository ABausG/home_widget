//
//  HomeWidgetBackgroundIntent.swift
//  home_widget
//
//  Created by Anton Borries on 25.08.23.
//

import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

@available(iOS 17, *)
public struct HomeWidgetBackgroundWorker {
  static let dispatcherKey = "home_widget.internal.background.dispatcher"
  static let callbackKey = "home_widget.internal.background.callback"
  private static let engineName = "home_widget_background"
  private static let channelName = "home_widget/background"
  private static let initializedMethod = "HomeWidget.backgroundInitialized"

}

#if os(iOS)
  @available(iOS 17, *)
  extension HomeWidgetBackgroundWorker {
    static var engine: FlutterEngine?
    static var channel: FlutterMethodChannel?

    static var isSetupCompleted: Bool = false
    static var continuations: [CheckedContinuation<Void, Never>] = []

    private static var registerPlugins: FlutterPluginRegistrantCallback?

    public static func setPluginRegistrantCallback(registerPlugins: FlutterPluginRegistrantCallback)
    {
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
        name: engineName, project: nil, allowHeadlessExecution: true)

      channel = FlutterMethodChannel(
        name: channelName, binaryMessenger: engine!.binaryMessenger,
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
      case initializedMethod:
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
#elseif os(macOS)
  extension HomeWidgetBackgroundWorker {
    private static var engine: FlutterEngine?
    private static var channel: FlutterMethodChannel?
    private static var isSetupCompleted = false
    private static var continuations: [CheckedContinuation<Bool, Never>] = []
    private static var registerPlugins: ((FlutterPluginRegistry) -> Void)?
    private static var appGroup: String?
    private static var handles: [Int64] = []
    private static var activeCalls = 0
    private static var initializationTimeout: DispatchWorkItem?

    /// Register the plugins required by your callback, including home_widget.
    public static func setPluginRegistrantCallback(
      registerPlugins: @escaping (FlutterPluginRegistry) -> Void
    ) {
      if Thread.isMainThread {
        self.registerPlugins = registerPlugins
      } else {
        DispatchQueue.main.sync { self.registerPlugins = registerPlugins }
      }
    }

    /// Call this method to invoke the callback registered in your Flutter App.
    /// The url you provide will be used as arguments in the callback function in dart
    /// The AppGroup is necessary to retrieve the dart callbacks
    public static func run(url: URL?, appGroup: String) async {
      let ready: Bool = await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
          guard Bundle.main.bundleURL.pathExtension != "appex",
            HomeWidgetPlugin.isAppGroupAuthorized(appGroup),
            let preferences = UserDefaults(suiteName: appGroup),
            let stored = callbackHandles([
              preferences.object(forKey: dispatcherKey) ?? NSNull(),
              preferences.object(forKey: callbackKey) ?? NSNull(),
            ]),
            setupEngine(appGroup: appGroup, handles: stored)
          else {
            NSLog("home_widget background initialization failed")
            continuation.resume(returning: false)
            return
          }
          if isSetupCompleted {
            continuation.resume(returning: true)
          } else {
            continuations.append(continuation)
          }
        }
      }
      if ready { await sendEvent(url: url, appGroup: appGroup) }
    }

    static func setupEngine(appGroup: String, handles: [Int64]) -> Bool {
      dispatchPrecondition(condition: .onQueue(.main))
      if engine != nil, self.appGroup == appGroup, self.handles == handles { return true }
      // Reconfiguration must not discard an in-flight Dart reply.
      guard activeCalls == 0 else { return false }
      shutDownEngine()
      self.appGroup = appGroup
      self.handles = handles
      let worker = FlutterEngine(
        name: engineName, project: nil, allowHeadlessExecution: true)
      engine = worker
      channel = FlutterMethodChannel(
        name: channelName, binaryMessenger: worker.binaryMessenger)
      channel?.setMethodCallHandler { [weak worker] call, result in
        guard let worker, engine === worker else {
          result(FlutterError(code: "-11", message: "Background engine was replaced", details: nil))
          return
        }
        handle(call, result: result)
      }
      let timeout = DispatchWorkItem { [weak worker] in
        guard let worker, engine === worker, !isSetupCompleted else { return }
        NSLog("home_widget background initialization timed out")
        shutDownEngine()
      }
      initializationTimeout = timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
      if let registerPlugins {
        registerPlugins(worker)
      } else {
        HomeWidgetPlugin.register(with: worker.registrar(forPlugin: "home_widget"))
      }
      guard worker.run(withEntrypoint: "homeWidgetBackgroundMain") else {
        shutDownEngine()
        return false
      }
      return true
    }

    private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case initializedMethod:
        isSetupCompleted = true
        initializationTimeout?.cancel()
        initializationTimeout = nil
        result(true)
        let waiting = continuations
        continuations.removeAll()
        for continuation in waiting { continuation.resume(returning: true) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    private static func sendEvent(url: URL?, appGroup: String) async {
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
          guard isSetupCompleted, self.appGroup == appGroup, let channel else {
            NSLog("home_widget background engine is not ready for this App Group")
            continuation.resume()
            return
          }
          activeCalls += 1
          channel.invokeMethod(
            "", arguments: [handles[1], (url?.absoluteString as Any?) ?? NSNull()]
          ) { result in
            activeCalls -= 1
            if let error = result as? FlutterError {
              NSLog("home_widget background callback error: %@ %@", error.code, error.message ?? "")
            } else if let result = result as AnyObject?, result === FlutterMethodNotImplemented {
              NSLog("home_widget background callback was not handled")
            }
            continuation.resume()
          }
        }
      }
    }

    // Flutter hashes callback names into signed Int64; negative and zero are valid.
    static func callbackHandles(_ value: Any?) -> [Int64]? {
      guard let numbers = value as? [NSNumber], numbers.count == 2,
        numbers.allSatisfy({
          CFGetTypeID($0) != CFBooleanGetTypeID()
            && ["c", "s", "i", "l", "q"].contains(String(cString: $0.objCType))
        })
      else { return nil }
      return numbers.map(\.int64Value)
    }

    static func backgroundEngine(
      for messenger: FlutterBinaryMessenger
    ) -> (engine: FlutterEngine, appGroup: String)? {
      guard let engine, let appGroup,
        ObjectIdentifier(messenger as AnyObject)
          == ObjectIdentifier(engine.binaryMessenger as AnyObject)
      else { return nil }
      return (engine, appGroup)
    }

    static func isCurrentBackgroundEngine(_ worker: FlutterEngine, handles: [Int64]) -> Bool {
      engine === worker && self.handles == handles
    }

    private static func shutDownEngine() {
      initializationTimeout?.cancel()
      initializationTimeout = nil
      let worker = engine
      engine = nil
      channel?.setMethodCallHandler(nil)
      channel = nil
      if let worker {
        worker.shutDownEngine()
      }
      appGroup = nil
      handles = []
      isSetupCompleted = false
      let waiting = continuations
      continuations.removeAll()
      for continuation in waiting { continuation.resume(returning: false) }
    }
  }
#endif
