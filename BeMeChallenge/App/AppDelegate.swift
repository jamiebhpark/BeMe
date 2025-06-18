//
//  AppDelegate.swift
//  BeMeChallenge
//
//  Firebase Dynamic Links 제거 + NetworkMonitor 경고 해결
//

import UIKit
import Firebase
import FirebaseMessaging   // APNs 토큰 전달

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: – App Launch
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        FirebaseApp.configure()
        PushNotificationManager.shared.registerForPushNotifications()

        _ = NetworkMonitor.shared     // ⚠️ unused-expression 경고 명시적으로 무시

        return true
    }
    
    // 포그라운드 복귀 시에도 남아 있을 배지를 제거
    func applicationDidBecomeActive(_ application: UIApplication) {
        PushNotificationManager.resetBadge()
    }

    // MARK: – APNs 토큰
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: – Universal Link (옵션)
    /// Dynamic Links를 제거했으므로, Universal Link 처리가 필요하다면
    /// SceneDelegate 또는 별도 딥링크 매니저에서 `incomingURL` 을 직접 파싱하세요.
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        guard let url = userActivity.webpageURL else { return false }

        // 예시: https://beme.app/challenge/<cid>
        if let cid = DeepLinkParser.challengeId(from: url) {
            print("딥링크 챌린지 ID: \(cid)")
            // TODO: Navigator.shared.openChallenge(cid)
            return true
        }

        return false
    }
}
