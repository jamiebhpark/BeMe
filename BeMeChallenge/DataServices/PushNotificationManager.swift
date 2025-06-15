// PushNotificationManager.swift
import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UIKit

final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    // 권한 요청 + APNs 등록
    func registerForPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            if let err { print("권한 요청 에러:", err.localizedDescription); return }
            print("푸시 알림 권한 승인:", granted)
            if granted { DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() } }
        }
        Messaging.messaging().delegate = self
    }

    /// **users/{uid}.fcmToken** 필드 동기화 (Skeleton 생성 이후 호출)
    func syncFcmTokenIfNeeded() {
        guard
            let uid   = Auth.auth().currentUser?.uid,
            let token = Messaging.messaging().fcmToken
        else { return }

        Firestore.firestore().document("users/\(uid)")
            .setData(["fcmToken": token], merge: true) { err in
                if let err {
                    print("FCM 토큰 업로드 실패:", err.localizedDescription)
                } else {
                    print("사용자 토큰 업데이트 성공")
                }
            }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {
        print("알림 응답:", response.notification.request.content.userInfo)
        completion()
    }
}

// MARK: - MessagingDelegate
extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {

        guard let fcmToken else { return }
        print("업데이트된 FCM 토큰:", fcmToken)

        // (1) Firestore에 저장
        syncFcmTokenIfNeeded()

        // (2) 이미 로그인 상태라면 토픽 구독(중복 호출 무해)
        if Auth.auth().currentUser != nil {
            Messaging.messaging().subscribe(toTopic: "new-challenge")
        }
    }
}

