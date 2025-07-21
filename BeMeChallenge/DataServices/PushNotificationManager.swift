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
            guard granted else { return }
            Self.resetBadge()
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
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
        Task {
            do {
                if allow {
                    try await Messaging.messaging().subscribe(toTopic: "marketing-news")
                } else {
                    try await Messaging.messaging().unsubscribe(fromTopic: "marketing-news")
                }
            } catch {
                print("⚠️ Marketing topic update failed:", error.localizedDescription)
            }
        }
    }

    // MARK: – 관리자(admin) 토픽 구독/해제
    func updateAdminTopic() {
        guard let user = Auth.auth().currentUser else { return }

        Task {                                                    // 비동기 컨텍스트
            do {
                // ① 최신 ID 토큰 → 커스텀 클레임 확인 (강제 리프레시)
                let tok = try await user.getIDTokenResult(forcingRefresh: true)   // ✅ 변경
                let isAdmin = (tok.claims["isAdmin"] as? Bool) ?? false

                // ② 토픽 상태 반영
                if isAdmin {
                    try await Messaging.messaging().subscribe(toTopic: "admin")
                    print("📥 admin 구독 성공")
                } else {
                    try await Messaging.messaging().unsubscribe(fromTopic: "admin")
                    print("📤 admin 구독 해제")
                }
            } catch {
                print("⚠️ updateAdminTopic failed:", error.localizedDescription)
            }
        }
    }
}

// MARK: – UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent _: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound, .badge])
    }
}

// MARK: – MessagingDelegate
extension PushNotificationManager: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard fcmToken != nil else { return }

        syncFcmTokenIfNeeded()

        // 레거시 토픽 해제
        if let uid = Auth.auth().currentUser?.uid {
            Task { try? await Messaging.messaging().unsubscribe(fromTopic: "user-\(uid)") }
        }

        // 공통 토픽
        Task { try? await Messaging.messaging().subscribe(toTopic: "new-challenge") }

        // 관리자 / 마케팅 토픽
        updateAdminTopic()
        let allow = UserDefaults.standard.bool(forKey: "allowMarketing")
        updateMarketingTopic(allow)
    }
}
