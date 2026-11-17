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
    // Les rappels (30 min, 24 h) non : Zieuton ouvert vérifie déjà lui-même (FOU-126, pas de doublon).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        completionHandler(NoticePlan.showsInForeground(id) ? [.banner, .list, .sound] : [])
    }

    // Notification touchée : « prêt » ouvre Instagram sur « Télécharger » ; « C'est demandé » et les rappels ouvrent
    // l'écran d'attente, qui vérifie tout de suite où en est Instagram.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        DispatchQueue.main.async {
            if id == NoticePlan.ready { WebViewController.current?.openExport() }
            else { WebViewController.current?.showHome() }
            completionHandler()
        }
    }
}
