import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        requestPushPermission(application)

        return true
    }

    private func requestPushPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in

            if let error = error {
                print("Notification permission error:", error.localizedDescription)
                return
            }

            print("Push permission granted:", granted)

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        print("APNs token:", deviceToken.map { String(format: "%02.2hhx", $0) }.joined())
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications:", error.localizedDescription)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Notification received while app is open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    // User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped:", userInfo)
    }
}

extension AppDelegate: MessagingDelegate {

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        print("FCM Token:", fcmToken)

        // Send this token to your backend if you want targeted notifications
    }
}
