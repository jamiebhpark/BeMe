// BeMeChallengeApp.swift
import SwiftUI
import Firebase
import FirebaseMessaging               // ⬅️ 추가

@main
struct BeMeChallengeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var modalC = ModalCoordinator()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !authVM.isLoggedIn {
                    LoginViewWrapper()
                } else if !hasSeenOnboarding {
                    OnboardingViewWrapper()
                } else {
                    MainTabView()
                }
            }
            // 모든 화면에 AuthViewModel, ModalCoordinator 주입
            .environmentObject(authVM)
            .environmentObject(modalC)
            .onAppear { authVM.checkLoginStatus() }
            
            // ───────────────────────────────────────────────
            // ⬇️ 로그인-로그아웃 노티를 받아 토픽을 Subscribe/Unsubscribe
            // ───────────────────────────────────────────────
            .onReceive(NotificationCenter.default.publisher(for: .didSignIn)) { _ in
                Messaging.messaging().subscribe(toTopic: "new-challenge")
                PushNotificationManager.shared.syncFcmTokenIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSignOut)) { _ in
                Messaging.messaging().unsubscribe(fromTopic: "new-challenge")
                
            }
            // ───────── UploadQueue 완료 토스트 (🆕) ─────────
            .onReceive(NotificationCenter.default.publisher(for: .uploadQueueDidFlush)) { _ in
                modalC.showToast(ToastItem(message: "📤 오프라인 업로드 완료!"))
            }
        }
    }
}
