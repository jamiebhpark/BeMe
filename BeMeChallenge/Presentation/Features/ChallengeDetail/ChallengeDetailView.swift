//
//  ChallengeDetailView.swift
//  BeMeChallenge
//

import SwiftUI

struct ChallengeDetailView: View {
    let challengeId: String

    @StateObject private var vm = ChallengeDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    /// ① 관리 다이얼로그 토글용
    @State private var showManageDialog = false
    /// ② 선택된 포스트 저장용
    @State private var selectedPost: Post?

    var body: some View {
        VStack(spacing: 0) {
            // ① 세그먼트
            Picker("", selection: $vm.scope) {
                ForEach(FeedScope.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color("Lavender"))
            .padding(.horizontal)

            // ② 본문
            switch vm.postsState {
            case .idle, .loading:
                ProgressView().frame(maxHeight: .infinity)

            case .failed(let err):
                VStack(spacing: 12) {
                    Text("로드 실패: \(err.localizedDescription)")
                    Button("재시도") {
                        Task { await vm.loadInitial(challengeId: challengeId) }
                    }
                }
                .frame(maxHeight: .infinity)

            case .loaded:
                FeedView(vm: vm)
            }
        }
        // 네비게이션 바 뒤로
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Label("뒤로", systemImage: "chevron.left")
                }
                .tint(Color("Lavender"))
            }
        }
        // 최초 진입
        .task { await vm.loadInitial(challengeId: challengeId) }

        // ③ “.manage” Alert 발생 시 확인 (iOS 17+ onChange API)
        .onChange(of: modalC.modalAlert?.id) { _oldId, _newId in
            guard case .manage(let post)? = modalC.modalAlert else { return }
            selectedPost = post
            showManageDialog = true
            modalC.resetAlert()
        }

        // ④ 삭제·신고·차단·취소 4가지 옵션을 한 번에 보여주는 confirmationDialog
        .confirmationDialog(
            "게시물 관리",
            isPresented: $showManageDialog,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let post = selectedPost {
                    modalC.showAlert(.deleteConfirm(post: post))
                }
            }
            Button("신고") {
                if let post = selectedPost {
                    modalC.showAlert(.reportConfirm(post: post))
                }
            }
            Button("차단", role: .destructive) {
                if let post = selectedPost {
                    modalC.showAlert(.blockConfirm(
                        userId:   post.userId,
                        userName: post.userId
                    ))
                }
            }
            Button("취소", role: .cancel) { }
        }

        // ⑤ deleteConfirm, reportConfirm, blockConfirm 에 대한 실제 Alert 처리
        .alert(item: $modalC.modalAlert, content: makeAlert)
    }

    // MARK: - Alert Builder
    private func makeAlert(for alert: ModalAlert) -> Alert {
        switch alert {
        case .deleteConfirm(let post):
            return Alert(
                title: Text("삭제 확인"),
                message: Text("정말 이 게시물을 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("삭제")) {
                    vm.deletePost(post)
                    modalC.resetAlert()
                    modalC.showToast(.init(message: "삭제 완료"))
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
                    modalC.showToast(.init(message: "신고 접수"))
                },
                secondaryButton: .cancel {
                    modalC.resetAlert()
                }
            )

        case .blockConfirm(let userId, let userName):
            return Alert(
                title: Text("\(userName)님을 차단하시겠습니까?"),
                message: Text("차단된 사용자의 게시물은 더 이상 보이지 않습니다."),
                primaryButton: .destructive(Text("차단")) {
                    BlockService.shared.block(userId: userId) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                modalC.showToast(.init(message: "차단되었습니다"))
                            case .failure:
                                modalC.showToast(.init(message: "차단에 실패했습니다"))
                            }
                        }
                    }
                    modalC.resetAlert()
                },
                secondaryButton: .cancel {
                    modalC.resetAlert()
                }
            )

        default:
            // manage는 onChange로 처리했으므로 여기엔 오지 않습니다.
            return Alert(title: Text(""))
        }
    }
}
