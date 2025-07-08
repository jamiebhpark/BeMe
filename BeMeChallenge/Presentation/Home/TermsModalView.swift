//
//  TermsModalView.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseAuth          // 🔑 UID 가져오기
import FirebaseMessaging

/// 로그인 직후 표시되는 약관 동의 모달
struct TermsModalView: View {
    // 외부에서 isPresented 바인딩
    @Binding var isPresented: Bool

    // AppStorage 플래그
    @AppStorage("agreedEULA")     private var agreedEULA     = false
    @AppStorage("allowMarketing") private var allowMarketing = false

    // 로컬 상태
    @State private var agreeTerms     = false
    @State private var agreePrivacy   = false
    @State private var agreeMarketing = false

    // 전역 객체
    @EnvironmentObject private var modalC: ModalCoordinator   // ✅ authVM 제거

    var body: some View {
        NavigationStack {
            Form {
                /* ── 문서 링크 ───────────────────────── */
                Section {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("최종 사용자 이용약관(EULA)")
                        Spacer()
                        Button("보기") { openEULA() }
                    }
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("개인정보 처리방침")
                        Spacer()
                        Button("보기") { openPrivacy() }
                    }
                }

                /* ── 동의 체크 ───────────────────────── */
                Section {
                    Toggle("EULA에 동의합니다. (필수)", isOn: $agreeTerms)
                    Toggle("개인정보 처리방침에 동의합니다. (필수)", isOn: $agreePrivacy)
                    Toggle("광고·마케팅 정보 수신 동의 (선택)", isOn: $agreeMarketing)
                }

                /* ── 계속 버튼 ───────────────────────── */
                Section {
                    Button("동의 및 계속") { saveConsents() }
                        .disabled(!(agreeTerms && agreePrivacy))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("약관 동의")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { isPresented = false }
                }
            }
        }
        .interactiveDismissDisabled()   // 스와이프로 닫기 방지
    }

    // 2) openEULA() 수정
    private func openEULA() {
        if let path = Bundle.main.path(forResource: "BeMe_EULA_KR_2025", ofType: "md"),
           let md   = try? String(contentsOfFile: path, encoding: .utf8) {
            modalC.presentMarkdown(md)          // ⬅️ MD 텍스트 전달
        }
    }
    private func openPrivacy() {
        if let url = URL(string: "https://quilt-cover-7b9.notion.site/beme-app-privacy-policy") {
            modalC.presentWeb(url)
        }
    }

    // MARK: - 저장
    private func saveConsents() {
        // 1) 로컬 저장
        agreedEULA     = true
        allowMarketing = agreeMarketing

        // 2) 서버 머지
        Task {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            do {
                try await UserService.shared.updateConsent(
                    uid: uid,
                    eula: true,
                    privacy: true,
                    marketing: agreeMarketing
                )
            } catch {
                modalC.showToast(ToastItem(
                    message: "⚠️ 동의 정보 저장 실패\n나중에 다시 시도해 주세요."
                ))
            }
        }

        // 3) 마케팅 토픽 구독/해제
        PushNotificationManager.shared.updateMarketingTopic(agreeMarketing)

        // 4) 모달 종료
        isPresented = false
    }
}
