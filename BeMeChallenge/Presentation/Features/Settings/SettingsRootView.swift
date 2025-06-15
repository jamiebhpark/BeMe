// Presentation/Features/Settings/SettingsRootView.swift
import SwiftUI

struct SettingsRootView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        List {
            Section("개인정보") {
                NavigationLink("개인정보 설정") {
                    ProfilePrivacyView()
                        .environmentObject(modalC)
                }
            }
            Section("커뮤니티") {
                NavigationLink("커뮤니티 가이드라인") {
                    CommunityGuidelineView()
                }
            }
            Section("지원") {
                NavigationLink("앱 정보")      { AboutView() }
                NavigationLink("도움말 & FAQ") { HelpFAQView() }
                NavigationLink("피드백 보내기"){ FeedbackView() }
            }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("닫기") { dismiss() }
            }
        }
    }
}
