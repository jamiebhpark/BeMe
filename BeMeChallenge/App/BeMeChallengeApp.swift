//
//  BeMeChallengeApp.swift
//  BeMeChallenge
//

import SwiftUI
import Firebase
import FirebaseMessaging               // ⬅️ FCM

@main
struct BeMeChallengeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @StateObject private var authVM  = AuthViewModel()
    @StateObject private var modalC  = ModalCoordinator()

    var body: some Scene {
        WindowGroup {

            // ────────────────────────────────
            // 0) 루트 컨텐츠
            // ────────────────────────────────
            Group {
                if !authVM.isLoggedIn {
                    LoginViewWrapper()
                } else if !hasSeenOnboarding {
                    OnboardingViewWrapper()
                } else {
                    MainTabView()
                }
            }
            // ────────────────────────────────
            // 1) 전역 EnvironmentObjects
            // ────────────────────────────────
            .environmentObject(authVM)
            .environmentObject(modalC)

            // ────────────────────────────────
            // 2) 앱 시작 시 로그인 상태 확인
            // ────────────────────────────────
            .onAppear { authVM.checkLoginStatus() }

            // ────────────────────────────────
            // 3) 로그인 / 로그아웃 시 FCM 토픽 관리
            // ────────────────────────────────
            .onReceive(NotificationCenter.default.publisher(for: .didSignIn)) { _ in
                Messaging.messaging().subscribe(toTopic: "new-challenge")
                PushNotificationManager.shared.syncFcmTokenIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSignOut)) { _ in
                Messaging.messaging().unsubscribe(fromTopic: "new-challenge")
            }

            // ────────────────────────────────
            // 4) 오프라인 업로드 완료 토스트
            // ────────────────────────────────
            .onReceive(NotificationCenter.default.publisher(for: .uploadQueueDidFlush)) { _ in
                modalC.showToast(ToastItem(message: "📤 오프라인 업로드 완료!"))
            }

            // ────────────────────────────────
            // 5) 전역 Toast 배너 overlay   🆕
            // ────────────────────────────────
            .overlay(alignment: .top) {
                if let toast = modalC.toast {
                    ToastBannerView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1_000)            // 항상 최상단
                        .padding(.top, 10)        // 상태 바 여백
                }
            }
        }
    }
}
