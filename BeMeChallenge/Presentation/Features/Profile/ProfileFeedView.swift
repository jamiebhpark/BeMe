//
//  Presentation/Features/Profile/ProfileFeedView.swift
//

import SwiftUI

struct ProfileFeedView: View {
    @ObservedObject var profileVM: ProfileViewModel
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        switch profileVM.profileState {

        // 로딩
        case .idle, .loading:
            ProgressView()
                .frame(maxHeight: .infinity)
                .task { profileVM.refresh() }

        // 실패
        case .failed(let err):
            VStack(spacing: 16) {
                Text("로드 실패: \(err.localizedDescription)")
                Button("재시도") { profileVM.refresh() }
            }
            .padding()

        // 성공
        case .loaded(let p):
            let me = User(
                id: p.id ?? "",
                nickname: p.nickname,
                bio: p.bio,
                location: p.location,
                profileImageURL: p.profileImageURL,
                profileImageUpdatedAt: p.profileImageUpdatedAt,
                fcmToken: nil
            )

            SimpleFeedView(
                posts: profileVM.userPosts,
                user:  me,
                onDelete: { post in
                    profileVM.deletePost(post)
                    modalC.showToast(.init(message: "삭제 완료"))
                },
                onReport: { post in
                    profileVM.reportPost(post)
                    modalC.showToast(.init(message: "신고 접수"))
                }
            )
            .navigationTitle("내 포스트")
            .navigationBarTitleDisplayMode(.inline)
            .alert(item: $modalC.modalAlert, content: alertBuilder)
        }
    }

    // Alert builder
    private func alertBuilder(for alert: ModalAlert) -> Alert {
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
                    profileVM.deletePost(post)
                    modalC.resetAlert()
                    modalC.showToast(.init(message: "삭제 완료"))
                },
                secondaryButton: .cancel { modalC.resetAlert() }
            )

        case .reportConfirm(let post):
            return Alert(
                title: Text("신고 확인"),
                message: Text("이 게시물을 신고하시겠습니까?"),
                primaryButton: .destructive(Text("신고")) {
                    profileVM.reportPost(post)
                    modalC.resetAlert()
                    modalC.showToast(.init(message: "신고 접수"))
                },
                secondaryButton: .cancel { modalC.resetAlert() }
            )
        }
    }
}
