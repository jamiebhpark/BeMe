//
//  PushNotificationManager.swift
//  BeMeChallenge
//

import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UIKit

final class PushNotificationManager: NSObject, ObservableObject {

    // MARK: – Singleton
    static let shared = PushNotificationManager()

    // MARK: – 배지 & 알림 초기화
    static func resetBadge() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        if #available(iOS 17.0, *) {
            center.setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    // MARK: – APNs 권한 요청 & 등록
    func registerForPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                Self.resetBadge()
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        Messaging.messaging().delegate = self
    }

    // MARK: – FCM 토큰 Firestore에 저장
    func syncFcmTokenIfNeeded() {
        guard
            let uid   = Auth.auth().currentUser?.uid,
            let token = Messaging.messaging().fcmToken
        else { return }

        Firestore.firestore()
            .document("users/\(uid)")
            .setData(["fcmToken": token], merge: true)
    }

    // MARK: – 마케팅 토픽 구독/해제
    func updateMarketingTopic(_ allow: Bool) {
        let topic = "marketing-news"
        if allow {
            Messaging.messaging().subscribe(toTopic: topic)
        } else {
            Messaging.messaging().unsubscribe(fromTopic: topic)
        }
    }
}

// MARK: – UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound, .badge])  // 포그라운드에서도 기본 알림만
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {
        completion()
    }
}

// MARK: – MessagingDelegate
extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {
        guard fcmToken != nil else { return }
        syncFcmTokenIfNeeded()

        // ① 레거시 토픽(user-<uid>) 해제
        if let uid = Auth.auth().currentUser?.uid {
            Messaging.messaging().unsubscribe(fromTopic: "user-\(uid)")
        }
        // ② 새 챌린지 토픽만 구독
        Messaging.messaging().subscribe(toTopic: "new-challenge")

        // ③ allowMarketing에 따라 마케팅 토픽 구독/해제
        let allow = UserDefaults.standard.bool(forKey: "allowMarketing")
        updateMarketingTopic(allow)
    }
}
