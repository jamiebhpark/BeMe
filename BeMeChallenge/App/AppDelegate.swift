//
//  AppDelegate.swift
//  BeMeChallenge
//
//  Updated 2025-07-23
//  • admin 토픽 분리 + APNs 재시도
//  • 캐시된 FCM 토큰 활용
//  • 🆕 PendingDeepLink 보관 → HomeView 등장 시 소비
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

// 🆕 cold-launch 때 postId / commentId 를 잠시 보관
enum PendingDeepLink {
    static var postId:    String?
    static var commentId: String?
}

class AppDelegate: NSObject,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate {

    // MARK: 1. 앱 런칭 ────────────────────────────────
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // 1-A. Firebase
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        // 1-A-2. 🆕 cold-launch(푸시 클릭) → DeepLink 보관
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let p = remote["postId"] as? String {
            PendingDeepLink.postId    = p
            PendingDeepLink.commentId = remote["commentId"] as? String
        }

        // 1-B. 캐시된 FCM 토큰 구독
        Messaging.messaging().token { token, error in
            if let token {
                print("📬 기존 FCM 토큰:", token)
                Messaging.messaging().subscribe(toTopic: "new-challenge")
                PushNotificationManager.shared.syncFcmTokenIfNeeded()
                PushNotificationManager.shared.updateAdminTopic()
            } else if let error {
                print("⚠️ FCM token fetch error:", error.localizedDescription)
            }
        }

        // 1-C. 권한 & APNs
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            print("🔔 Push 권한:", granted, err ?? "")
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
                // 디버그용 재시도
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    application.registerForRemoteNotifications()
                }
            }
        }

        _ = NetworkMonitor.shared
        return true
    }

    // MARK: 2. APNs 토큰 ──────────────────────────────
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📬 APNs 토큰 수신:", hex)
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🚫 APNs 등록 실패:", error)
    }

    // MARK: 3. FCM 토큰 변경 ───────────────────────────
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ FCM 토큰 생성:", token)

        Messaging.messaging().subscribe(toTopic: "new-challenge")
        PushNotificationManager.shared.syncFcmTokenIfNeeded()
        PushNotificationManager.shared.updateAdminTopic()
    }

    // MARK: 4. 알림 표시 & 탭 ───────────────────────────
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {

        let info = response.notification.request.content.userInfo
        if let p = info["postId"] as? String {
            Navigator.shared.openPost(p, commentId: info["commentId"] as? String)
        }
        completion()
    }

    // MARK: 5. 배지 초기화 ──────────────────────────────
    func applicationDidBecomeActive(_ application: UIApplication) {
        PushNotificationManager.resetBadge()
    }

    // MARK: 6. Universal Links (선택) ──────────────────
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        guard let url = userActivity.webpageURL else { return false }
        if let cid = DeepLinkParser.challengeId(from: url) {
            Navigator.shared.openChallenge(cid)
            return true
        }
        return false
    }
}
