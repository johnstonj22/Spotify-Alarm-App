import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        UserDefaults.standard.set(true, forKey: AppNotificationKeys.pendingAlarmNotificationTap)
        NotificationCenter.default.post(name: .alarmNotificationTapped, object: nil)
    }
}

extension Notification.Name {
    static let alarmNotificationTapped = Notification.Name("alarmNotificationTapped")
}

enum AppNotificationKeys {
    static let pendingAlarmNotificationTap = "pendingAlarmNotificationTap"
}
