//
//  Presentation/Features/Settings/Pages/ProfilePrivacyView.swift
//

import SwiftUI

struct ProfilePrivacyView: View {

    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        Form {

            // ── 푸시 알림 설정 ───────────────────────────────
            Section(header: Text("알림 설정")
                        .foregroundColor(Color("TextPrimary"))) {
                PushSettingsRow()   // ViewModel 인자 제거로 교체 완료
            }

            // ── 계정 관리 ──────────────────────────────────
            Section(header: Text("계정 관리")
                        .foregroundColor(Color("TextPrimary"))) {
                NavigationLink {
                    AccountDeletionView()
                        .environmentObject(authVM)
                } label: {
                    Text("계정 삭제")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("개인정보 보호")
        .navigationBarTitleDisplayMode(.inline)
    }
}
