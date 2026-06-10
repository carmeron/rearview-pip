import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure global app appearance
        configureAppearance()

        #if DEBUG
        print("[AppDelegate] Application did finish launching")
        #endif

        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Called when user discards a scene session
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // App is about to go to background — PiP should remain active
        // via the background audio keep-alive mechanism
        #if DEBUG
        print("[AppDelegate] Application will resign active")
        #endif
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // App has entered background
        // The BackgroundAudioKeepAlive keeps the audio session alive
        // so PiP continues to function
        #if DEBUG
        print("[AppDelegate] Application did enter background")
        #endif
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        #if DEBUG
        print("[AppDelegate] Application will enter foreground")
        #endif
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
        print("[AppDelegate] Application did become active")
        #endif
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up resources
        #if DEBUG
        print("[AppDelegate] Application will terminate")
        #endif
    }

    // MARK: - Appearance

    private func configureAppearance() {
        // Configure navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        // Disable screen auto-lock (keep display on while app is active)
        UIApplication.shared.isIdleTimerDisabled = true
    }
}
