import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        if let windowScene = scene as? UIWindowScene {
            if #available(iOS 16.0, *) {
                let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                windowScene.requestGeometryUpdate(preferences, errorHandler: nil)
            }
        }
    }

    override func sceneDidEnterBackground(_ scene: UIScene) {
        super.sceneDidEnterBackground(scene)
        // 锁屏或切后台会让 Scene 进入后台，保持播放会话激活
        keepPadAudioSessionActive(reason: "scene background")
    }

    override func sceneWillEnterForeground(_ scene: UIScene) {
        super.sceneWillEnterForeground(scene)
        keepPadAudioSessionActive(reason: "scene foreground")
    }
}
