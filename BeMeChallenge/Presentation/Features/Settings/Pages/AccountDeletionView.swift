//
//  Presentation/Settings/Pages/AccountDeletionView.swift
//

import SwiftUI
import FirebaseAuth

// ──────────────────────────────────────────────
// MARK: – Alert 타입
// ──────────────────────────────────────────────
enum DeletionAlert: Identifiable, Hashable {
    case confirmation
    case error(message: String)

    // Identifiable 요구 사항
    var id: Int { self.hashValue }
}

// ──────────────────────────────────────────────
// MARK: – View
// ──────────────────────────────────────────────
struct AccountDeletionView: View {

    @Environment(\.dismiss)          private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var alert: DeletionAlert?
    @State private var isReauthenticating = false

    var body: some View {
        VStack(spacing: 32) {

            // 안내 문구
            Text("계정을 삭제하면 **모든 데이터가 즉시 삭제**되어 복구할 수 없습니다.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Color("TextPrimary"))
                .padding(.horizontal)

            // 삭제 버튼
            Button(action: { alert = .confirmation }) {
                Text("계정 삭제")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)

                    // 붉은 그라디언트
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color(red: 1.0, green: 0.4, blue: 0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 8)
        }
        .padding(.top, 40)   // ←✅ 상단 여백 추가
        .navigationTitle("계정 삭제")
        .navigationBarTitleDisplayMode(.inline)

        // 알림
        .alert(item: $alert, content: buildAlert)

        // 재인증 로딩 오버레이
        .overlay {
            if isReauthenticating {
                ProgressView("재인증 중…")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(12)
            }
        }
    }
}

// ──────────────────────────────────────────────
// MARK: – Alert / Actions
// ──────────────────────────────────────────────
private extension AccountDeletionView {

    func buildAlert(for alert: DeletionAlert) -> Alert {
        switch alert {
        case .confirmation:
            return Alert(
                title: Text("계정 삭제 확인"),
                message: Text("정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."),
                primaryButton: .destructive(Text("삭제"), action: deleteAccount),
                secondaryButton: .cancel()
            )

        case .error(let msg):
            return Alert(
                title: Text("오류"),
                message: Text(msg),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    // 계정 삭제 시도 ------------------------------------------------------
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            alert = .error(message: "로그인 정보를 찾을 수 없습니다.")
            return
        }

        user.delete { err in
            if let err = err as NSError? {
                // 최근 로그인 필요 → 재인증 플로우
                if err.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    reauthenticateAndDelete()
                } else {
                    alert = .error(message: err.localizedDescription)
                }
            } else {
                // 삭제 성공 → 앱 로그아웃
                authViewModel.signOut { result in
                    if case .failure(let e) = result {
                        alert = .error(message: e.localizedDescription)
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }

    // 재인증 → 삭제 재시도 ----------------------------------------------
    func reauthenticateAndDelete() {
        guard
            let user = Auth.auth().currentUser,
            let providerID = user.providerData.first?.providerID
        else {
            alert = .error(message: "재인증 정보를 찾을 수 없습니다.")
            return
        }

        isReauthenticating = true

        if providerID == "google.com" {
            // Google 재인증
            guard
                let scene   = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC  = scene.windows.first?.rootViewController
            else {
                isReauthenticating = false
                alert = .error(message: "재인증 화면을 표시할 수 없습니다.")
                return
            }

            AuthService.shared.reauthenticateWithGoogle(presenting: rootVC) { result in
                isReauthenticating = false
                switch result {
                case .success(let cred):
                    user.reauthenticate(with: cred) { _, error in
                        if let e = error {
                            alert = .error(message: e.localizedDescription)
                        } else {
                            deleteAccount()            // ✅ 재시도
                        }
                    }
                case .failure(let e):
                    alert = .error(message: e.localizedDescription)
                }
            }

        } else if providerID == "apple.com" {
            // Apple ⇒ 재로그인 안내
            isReauthenticating = false
            alert = .error(message: "Apple 계정은 재로그인 후 다시 시도해 주세요.")

        } else {
            isReauthenticating = false
            alert = .error(message: "지원하지 않는 인증 제공자입니다.")
        }
    }
}
