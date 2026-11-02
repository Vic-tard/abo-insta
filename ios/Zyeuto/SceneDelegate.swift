import UIKit

/// Reçoit les fichiers envoyés à Zyeuto depuis le menu Partager (ou « Ouvrir dans… »).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let web = WebViewController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = web
        window.makeKeyAndVisible()
        self.window = window
        // App fermée : le fichier partagé arrive ici.
        connectionOptions.urlContexts.forEach { web.receive(fileAt: $0.url) }
    }

    // App déjà ouverte : le fichier partagé arrive ici.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { web.receive(fileAt: $0.url) }
    }

    // Zyeuto passe en arrière-plan : on demande à iOS de le réveiller pour guetter le fichier Instagram.
    func sceneDidEnterBackground(_ scene: UIScene) {
        ExportWatcher.shared.scheduleBackgroundCheck()
    }
}
