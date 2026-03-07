import Flutter
import UIKit

@available(iOS 13.0, *)
extension HomeWidgetPlugin: FlutterSceneLifeCycleDelegate {

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let urlContexts = connectionOptions?.urlContexts else { return false }
    for context in urlContexts {
      let url = context.url
      if isWidgetUrl(url: url) {
        initialUrl = url
        latestUrl = url
        break
      }
    }
    return false
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    for context in URLContexts {
      let url = context.url
      if isWidgetUrl(url: url) {
        latestUrl = url
        return true
      }
    }
    return false
  }
}