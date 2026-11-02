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

    // Zieuton ouvert : la notification s'affiche quand même en haut de l'écran.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    // Notification touchée : « prêt », « rappel » ou « dernier jour » ouvrent Instagram sur « Télécharger ».
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        DispatchQueue.main.async {
            if id == "zy-asked" { WebViewController.current?.showHome() }
            else { WebViewController.current?.openExport() }
            completionHandler()
        }
    }
}
