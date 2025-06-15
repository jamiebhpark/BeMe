//  AccountDeletionView.swift
import SwiftUI
import FirebaseAuth

enum DeletionAlert: Identifiable {
    case confirmation, error(message: String)
    
    var id: Int {
        switch self {
        case .confirmation: return 1
        case .error: return 2
        }
    }
}

struct AccountDeletionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var deletionAlert: DeletionAlert?
    @State private var isReauthenticating = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("계정을 삭제하면 모든 데이터가 복구할 수 없게 삭제됩니다. 계속하시겠습니까?")
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
                .padding()
            
            Button("계정 삭제") {
                deletionAlert = .confirmation
            }
            .foregroundColor(.red)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .alert(item: $deletionAlert) { alert in
            switch alert {
            case .confirmation:
                return Alert(
                    title: Text("계정 삭제 확인"),
                    message: Text("정말 계정을 삭제하시겠습니까? 이 작업은 복구할 수 없습니다. 재인증이 필요할 수 있습니다."),
                    primaryButton: .destructive(Text("삭제")) {
                        deleteAccount()
                    },
                    secondaryButton: .cancel()
                )
            case .error(let message):
                return Alert(
                    title: Text("오류"),
                    message: Text(message),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
        .overlay(
            Group {
                if isReauthenticating {
                    ProgressView("재인증 중...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
            }
        )
    }
    
    func deleteAccount() {
        print("deleteAccount() 호출됨")
        guard let currentUser = Auth.auth().currentUser else {
            deletionAlert = .error(message: "사용자 정보를 찾을 수 없습니다.")
            print("현재 사용자 없음")
            return
        }
        currentUser.delete { error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    print("계정 삭제 실패: \(error.localizedDescription) (코드: \(error.code))")
                    if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        print("최근 인증 필요 에러 감지, 재인증 플로우 시작")
                        reauthenticateAndDelete()
                    } else {
                        deletionAlert = .error(message: error.localizedDescription)
                    }
                } else {
                    print("계정 삭제 성공")
                    authViewModel.signOut { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                dismiss()
                            case .failure(let error):
                                deletionAlert = .error(message: error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func reauthenticateAndDelete() {
        print("reauthenticateAndDelete() 호출됨")
        isReauthenticating = true
        
        guard let currentUser = Auth.auth().currentUser,
              let providerData = currentUser.providerData.first else {
            isReauthenticating = false
            deletionAlert = .error(message: "유효한 인증 제공자를 찾을 수 없습니다.")
            print("인증 제공자 정보 없음")
            return
        }
        
        let providerID = providerData.providerID
        if providerID == "google.com" {
            // Google 계정: 재인증 UI를 통해 재인증 후 삭제
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                isReauthenticating = false
                deletionAlert = .error(message: "루트 뷰 컨트롤러를 찾을 수 없습니다.")
                print("루트 뷰 컨트롤러 없음")
                return
            }
            AuthService.shared.reauthenticateWithGoogle(presenting: rootVC) { result in
                DispatchQueue.main.async {
                    self.isReauthenticating = false
                    switch result {
                    case .success(let credential):
                        currentUser.reauthenticate(with: credential) { _, error in
                            if let error = error {
                                print("재인증 실패: \(error.localizedDescription)")
                                self.deletionAlert = .error(message: error.localizedDescription)
                            } else {
                                print("재인증 후 계정 삭제 재시도")
                                self.deleteAccount()
                            }
                        }
                    case .failure(let error):
                        print("재인증 에러: \(error.localizedDescription)")
                        self.deletionAlert = .error(message: error.localizedDescription)
                    }
                }
            }
        } else if providerID == "apple.com" {
            // Apple 계정: 재인증은 일반적으로 사용자 상호작용이 필요하므로 재로그인을 유도합니다.
            isReauthenticating = false
            deletionAlert = .error(message: "Apple 계정은 재인증을 위해 앱을 재시작 후 다시 로그인해주세요.")
        } else {
            isReauthenticating = false
            deletionAlert = .error(message: "지원되지 않는 인증 제공자입니다.")
        }
    }
}
