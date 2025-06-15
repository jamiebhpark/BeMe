// Presentation/Features/Profile/ProfilePrivacyView.swift
import SwiftUI

struct ProfilePrivacyView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        Form {
            Section(header: Text("알림 설정")) {
                PushSettingsRow()    // ← vm 인자 제거
            }

            Section(header: Text("계정 관리")) {
                NavigationLink {
                    AccountDeletionView()
                        .environmentObject(authVM)
                } label: {
                    Text("계정 삭제")
                        .foregroundColor(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}
