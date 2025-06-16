//
//  Presentation/Features/ChallengeDetail/ChallengeDetailView.swift
//  BeMeChallenge
//

import SwiftUI

struct ChallengeDetailView: View {
    let challengeId: String

    @StateObject private var vm = ChallengeDetailViewModel()
    @EnvironmentObject private var modalC: ModalCoordinator
    @Environment(\.dismiss) private var dismiss

    // MARK: - View ---------------------------------------------------------
    var body: some View {
        VStack {
            switch vm.postsState {

            // ── 로딩 ──────────────────────────────────────────────────
            case .idle, .loading:
                ProgressView()
                    .tint(Color("Lavender"))                 // 💜
                    .frame(maxHeight: .infinity)

            // ── 실패 ──────────────────────────────────────────────────
            case .failed(let error):
                VStack(spacing: 16) {
                    Text("로드 실패: \(error.localizedDescription)")
                        .multilineTextAlignment(.center)

                    // Gradient-styled retry button
                    Button {
                        Task { await vm.loadInitial(challengeId: challengeId) }
                    } label: {
                        Text("재시도")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color("Lavender"), Color("SkyBlue")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }
                    .frame(maxWidth: 200)
                }
                .padding()

            // ── 성공 ──────────────────────────────────────────────────
            case .loaded:
                FeedView(vm: vm, challengeId: challengeId)
            }
        }
        // ── NavigationBar --------------------------------------------------
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("챌린지")
                    }
                }
                .tint(Color("Lavender"))     // 💜 백 버튼 색상
            }
        }
        // 최초 로드
        .task { await vm.loadInitial(challengeId: challengeId) }
        // 모달 Alert 처리
        .alert(item: $modalC.modalAlert, content: makeAlert)
    }

    // MARK: - Alert Builder -----------------------------------------------
    private func makeAlert(for alert: ModalAlert) -> Alert {
        switch alert {

        case .manage(let post):
            return Alert(
                title: Text("게시물 관리"),
                primaryButton: .destructive(Text("삭제")) {
                    modalC.showAlert(.deleteConfirm(post: post))
                },
                secondaryButton: .default(Text("신고")) {
                    modalC.showAlert(.reportConfirm(post: post))
                }
            )

        case .deleteConfirm(let post):
            return Alert(
                title: Text("삭제 확인"),
                message: Text("정말 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("삭제")) {
                    vm.deletePost(post)
                    modalC.resetAlert()
                    modalC.showToast(ToastItem(message: "삭제 완료"))
                },
                secondaryButton: .cancel { modalC.resetAlert() }
            )

        case .reportConfirm(let post):
            return Alert(
                title: Text("신고 확인"),
                message: Text("이 게시물을 신고하시겠습니까?"),
                primaryButton: .destructive(Text("신고")) {
                    vm.report(post)
                    modalC.resetAlert()
                    modalC.showToast(ToastItem(message: "신고 접수"))
                },
                secondaryButton: .cancel { modalC.resetAlert() }
            )
        }
    }
}
