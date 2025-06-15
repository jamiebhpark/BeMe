// AppDelegate.swift
import UIKit
import Firebase
import FirebaseDynamicLinks
import FirebaseMessaging   // 이 줄 추가

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        PushNotificationManager.shared.registerForPushNotifications()
        
        NetworkMonitor.shared
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let incomingURL = userActivity.webpageURL {
            print("Received URL: \(incomingURL.absoluteString)")
            let handled = DynamicLinks.dynamicLinks().handleUniversalLink(incomingURL) { dynamicLink, error in
                if let error = error {
                    print("Dynamic Link 처리 오류: \(error.localizedDescription)")
                    return
                }
                if let challengeId = DynamicLinksManager.shared.handleDynamicLink(dynamicLink) {
                    // 추출된 챌린지 ID를 사용해 관련 화면으로 이동 (앱 내비게이션 처리)
                    print("동적 링크로 전달된 챌린지 ID: \(challengeId)")
                }
            }
            return handled
        }
        return false
    }
}
