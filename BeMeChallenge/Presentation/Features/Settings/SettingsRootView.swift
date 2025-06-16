// SettingsRootView.swift
// (불필요한 import, 코멘트 삭제 없이 전체 파일 통째로 교체해도 됩니다)

import SwiftUI

struct SettingsRootView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        List {

            // ── 개인정보 ───────────────────────────────
            Section(header: Text("개인정보")) {
                NavigationLink("개인정보 설정") {
                    ProfilePrivacyView()
                        .environmentObject(modalC)
                }
            }

            // ── 커뮤니티 ───────────────────────────────
            Section(header: Text("커뮤니티")) {
                NavigationLink("커뮤니티 가이드라인") {
                    CommunityGuidelineView()
                }
            }

            // ── 지원 ──────────────────────────────────
            Section(header: Text("지원")) {
                NavigationLink("앱 정보")        { AboutView() }
                NavigationLink("도움말 & FAQ")   { HelpFAQView() }
                NavigationLink("피드백 보내기")  { FeedbackView() }
            }

            // ── 계정 ──────────────────────────────────
            Section {
                Button("로그아웃", role: .destructive) {
                    AuthViewModel().signOut()
                    dismiss()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}
