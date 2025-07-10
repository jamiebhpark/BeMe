//
//  BeMeChallengeApp.swift
//  BeMeChallenge
//
//  Updated: 2025-07-10 – ModalCoordinator.shared 바인딩
//

import SwiftUI
import Firebase
import FirebaseMessaging
import FirebaseAuth

// URL → Identifiable
extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

@main
struct BeMeChallengeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Persistent flags
    @AppStorage("agreedEULA")        private var agreedEULA        = false
    @AppStorage("allowMarketing")    private var allowMarketing    = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    // ViewModels & Coordinators
    @StateObject private var authVM  = AuthViewModel()
    @StateObject private var modalC: ModalCoordinator   // ← wrapper만 선언

    // 싱글턴 바인딩
    init() {
        let coordinator = ModalCoordinator()
        _modalC = StateObject(wrappedValue: coordinator)
        ModalCoordinator.shared = coordinator              // ← ★ 핵심
    }

    var body: some Scene {
        WindowGroup {

            /* 0️⃣ 루트 분기 */
            Group {
                if !authVM.isLoggedIn {
                    LoginViewWrapper()
                } else if !agreedEULA {
                    TermsModalView(isPresented: .constant(true))
                } else if !hasSeenOnboarding {
                    OnboardingViewWrapper()
                } else {
                    MainTabView()
                }
            }

            /* 1️⃣ 전역 객체 */
            .environmentObject(authVM)
            .environmentObject(modalC)

            /* 2️⃣ 로그인 상태 체크 */
            .onAppear { authVM.checkLoginStatus() }

            /* 3️⃣ 토픽 관리 ─ 로그인 시 */
            .onReceive(NotificationCenter.default.publisher(for: .didSignIn)) { _ in
                if let uid = Auth.auth().currentUser?.uid {
                    Messaging.messaging().unsubscribe(fromTopic: "user-\(uid)")
                }
                Messaging.messaging().subscribe(toTopic: "new-challenge")
                PushNotificationManager.shared.syncFcmTokenIfNeeded()
            }

            /* 3-b) 토픽 관리 ─ 로그아웃 시 */
            .onReceive(NotificationCenter.default.publisher(for: .didSignOut)) { _ in
                if let uid = Auth.auth().currentUser?.uid {
                    Messaging.messaging().unsubscribe(fromTopic: "user-\(uid)")
                }
                Messaging.messaging().unsubscribe(fromTopic: "new-challenge")
            }

            /* 4️⃣ 마케팅 토픽 */
            .onChange(of: allowMarketing) { _, newVal in
                PushNotificationManager.shared.updateMarketingTopic(newVal)
            }

            /* 5️⃣ 오프라인 업로드 완료 토스트 */
            .onReceive(NotificationCenter.default.publisher(for: .uploadQueueDidFlush)) { _ in
                modalC.showToast(ToastItem(message: "📤 오프라인 업로드 완료!"))
            }

            /* 7️⃣ 전역 Toast 배너 */
            .overlay(alignment: .top) {
                if let toast = modalC.toast {
                    ToastBannerView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1_000)
                        .padding(.top, 10)
                }
            }

            /* 8️⃣ 외부 URL Sheet */
            .sheet(item: $modalC.webURL) { url in
                SafariView(url: url)
            }

            /* 9️⃣ Markdown Sheet(EULA 등) */
            .sheet(item: $modalC.markdownText) { md in
                MarkdownSheet(text: md)
                    .environmentObject(modalC)
            }
        }
    }
}
