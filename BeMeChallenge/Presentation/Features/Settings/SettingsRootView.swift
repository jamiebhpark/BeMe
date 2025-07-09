//  SettingsRootView.swift

import SwiftUI

struct SettingsRootView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    @State private var showLogoutConfirm = false

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
                NavigationLink("앱 정보")      { AboutView() }
                NavigationLink("도움말 & FAQ") { HelpFAQView() }
                NavigationLink("피드백 보내기") { FeedbackView() }
            }

            // ── 차단 목록 ───────────────────────────────
            Section(header: Text("차단")) {
                NavigationLink("차단된 사용자") {
                    BlockedUsersView()
                }
            }

            // ── 계정 ──────────────────────────────────
            Section {
                Button("로그아웃", role: .destructive) {
                    showLogoutConfirm = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "정말 로그아웃하시겠어요?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("로그아웃", role: .destructive) {
                AuthViewModel().signOut()
                dismiss()
            }
            Button("취소", role: .cancel) { }
        }
    }
}
