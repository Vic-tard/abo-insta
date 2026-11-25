import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Notifications de l'export Instagram : visibles même quand Zieuton est ouvert, et touchables.
        UNUserNotificationCenter.current().delegate = self
        // Zieuton fermé : iOS peut le réveiller pour voir si le fichier Instagram est prêt.
        ExportWatcher.registerBackgroundTask()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Zieuton ouvert : « C'est demandé » et « prêt » s'affichent quand même en haut de l'écran.
    // Les rappels (15 min, 1 h, 4 h, 24 h) non : Zieuton ouvert vérifie déjà lui-même (FOU-126, pas de doublon).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        completionHandler(NoticePlan.showsInForeground(id) ? [.banner, .list, .sound] : [])
    }

    // Coque 25 (25 nov., Victor) : toute notification de l'export touchée (rappel, « C'est demandé », « prêt ») ouvre la demande
    // dans Zieuton et lance une vérification chez Instagram, même après un démarrage à froid. Instagram ne s'ouvre jamais seul.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        DispatchQueue.main.async {
            if NoticePlan.all.contains(id) { AppDelegate.openCheck(tries: 20) }
            completionHandler()
        }
    }

    /// Démarrage à froid : l'écran de Zieuton peut ne pas exister encore quand iOS transmet le toucher. On attend qu'il soit là
    /// (essais toutes les 0,25 s pendant 5 s) ; la page, elle, s'ouvre sur la demande dès qu'elle est prête.
    private static func openCheck(tries: Int) {
        if let screen = WebViewController.current { screen.openCheck(); return }
        guard tries > 0 else { NSLog("Zieuton : notification touchée, écran introuvable"); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { AppDelegate.openCheck(tries: tries - 1) }
    }
}
