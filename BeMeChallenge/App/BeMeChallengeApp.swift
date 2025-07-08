//
//  BeMeChallengeApp.swift
//  BeMeChallenge
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

    // ViewModels
    @StateObject private var authVM  = AuthViewModel()
    @StateObject private var modalC  = ModalCoordinator()

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
                // ① 기존 NSFW 차단용 토픽(user-<uid>) 해제
                if let uid = Auth.auth().currentUser?.uid {
                    Messaging.messaging().unsubscribe(fromTopic: "user-\(uid)")
                }
                // ② 새 챌린지 푸시만 구독
                Messaging.messaging().subscribe(toTopic: "new-challenge")
                PushNotificationManager.shared.syncFcmTokenIfNeeded()
            }

            /* 3-b) 토픽 관리 ─ 로그아웃 시 */
            .onReceive(NotificationCenter.default.publisher(for: .didSignOut)) { _ in
                // ① 기존 NSFW 차단용 토픽(user-<uid>) 해제
                if let uid = Auth.auth().currentUser?.uid {
                    Messaging.messaging().unsubscribe(fromTopic: "user-\(uid)")
                }
                // ② 새 챌린지 푸시 해제
                Messaging.messaging().unsubscribe(fromTopic: "new-challenge")
            }

            /* 4️⃣ 마케팅 토픽 (iOS 17+ 권장 서명) */
            .onChange(of: allowMarketing) { _, newVal in
                PushNotificationManager.shared.updateMarketingTopic(newVal)
            }

            /* 5️⃣ 오프라인 업로드 완료 토스트 */
            .onReceive(NotificationCenter.default.publisher(for: .uploadQueueDidFlush)) { _ in
                modalC.showToast(ToastItem(message: "📤 오프라인 업로드 완료!"))
            }

            /* 6️⃣ (삭제) 서버 차단 푸시 토스트 수신 관련 로직 제거 */

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
