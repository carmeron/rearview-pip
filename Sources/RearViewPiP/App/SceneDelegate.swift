import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create the main window
        let window = UIWindow(windowScene: windowScene)

        // Create the root view controller
        let mainVC = MainViewController()
        let navigationController = UINavigationController(rootViewController: mainVC)
        navigationController.isNavigationBarHidden = true  // Hide nav bar for full-screen video

        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window

        #if DEBUG
        print("[SceneDelegate] Scene connected — window created")
        #endif
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Scene was released by the system
        #if DEBUG
        print("[SceneDelegate] Scene did disconnect")
        #endif
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Scene became active — resume if needed
        #if DEBUG
        print("[SceneDelegate] Scene did become active")
        #endif
    }

    func sceneWillResignActive(_ scene: UIScene) {
        #if DEBUG
        print("[SceneDelegate] Scene will resign active")
        #endif
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        #if DEBUG
        print("[SceneDelegate] Scene will enter foreground")
        #endif
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        #if DEBUG
        print("[SceneDelegate] Scene did enter background")
        #endif
    }
}
