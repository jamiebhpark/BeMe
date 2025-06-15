// Presentation/Features/ChallengeDetail/ChallengeDetailView.swift
import SwiftUI

struct ChallengeDetailView: View {
    let challengeId: String
    @StateObject private var vm = ChallengeDetailViewModel()
    @EnvironmentObject private var modalC: ModalCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            switch vm.postsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxHeight: .infinity)

            case .failed(let error):
                VStack(spacing: 16) {
                    Text("로드 실패: \(error.localizedDescription)")
                        .multilineTextAlignment(.center)
                    Button("재시도") {
                        vm.fetch(challengeId)
                    }
                }
                .padding()

            case .loaded(let posts):
                // 이제 initialPostID 없이 호출
                FeedView(
                    posts:     posts,
                    userCache: vm.userCache,
                    onLike:    vm.like,
                    onReport:  { post in modalC.showAlert(.reportConfirm(post: post)) },
                    onDelete:  { post in
                        vm.deletePost(post)
                        modalC.resetAlert()
                        DispatchQueue.main.async {
                            modalC.showToast(ToastItem(message: "삭제 완료"))
                        }
                    }
                )
            }
        }
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
            }
        }
        .onAppear { vm.fetch(challengeId) }
        .alert(item: $modalC.modalAlert, content: makeAlert)
    }

    private func makeAlert(for alert: ModalAlert) -> Alert {
        switch alert {
        case .manage(let post):
            return Alert(
                title: Text("게시물 관리"),
                primaryButton: .destructive(Text("삭제")) {
                    DispatchQueue.main.async {
                        modalC.showAlert(.deleteConfirm(post: post))
                    }
                },
                secondaryButton: .default(Text("신고")) {
                    DispatchQueue.main.async {
                        modalC.showAlert(.reportConfirm(post: post))
                    }
                }
                )

        case .deleteConfirm(let post):
            return Alert(
                title: Text("삭제 확인"),
                message: Text("정말 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("삭제")) {
                    vm.deletePost(post)
                    modalC.resetAlert()
                    DispatchQueue.main.async {
                        modalC.showToast(ToastItem(message: "삭제 완료"))
                    }
                },
                secondaryButton: .cancel {
                    modalC.resetAlert()
                }
            )

        case .reportConfirm(let post):
            return Alert(
                title: Text("신고 확인"),
                message: Text("이 게시물을 신고하시겠습니까?"),
                primaryButton: .destructive(Text("신고")) {
                    vm.report(post)
                    modalC.resetAlert()
                    DispatchQueue.main.async {
                        modalC.showToast(ToastItem(message: "신고 접수"))
                    }
                },
                secondaryButton: .cancel {
                    modalC.resetAlert()
                }
            )
        }
    }
}
