//
//  ChallengeDetailView.swift
//  BeMeChallenge
//
//  Updated: 2025-07-10 – 댓글 Sheet 중복 방지(.sheet) 라우팅 추가
//

import SwiftUI

struct ChallengeDetailView: View {
    let challengeId: String

    @StateObject private var vm = ChallengeDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    // ───────── Alert · Sheet 상태 ─────────
    @State private var showManageDialog = false
    @State private var selectedPost: Post?            // 관리(삭제·신고·차단)
    @State private var commentSheetPost: Post? = nil  // 💬 댓글 Sheet (전역 1개)

    var body: some View {
        VStack(spacing: 0) {

            /* ① 세그먼트 */
            Picker("", selection: $vm.scope) {
                ForEach(FeedScope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .tint(Color("Lavender"))
            .padding(.horizontal)

            /* ② 본문 */
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
                    // 🔹 Feed 셀에서 댓글 버튼 눌렀을 때 전역 Sheet 로 전파
                    .environment(\.openURL, OpenURLAction { url in
                        if url.scheme == "comment", let id = url.host,
                           let post = vm.posts.first(where: { $0.id == id }) {
                            commentSheetPost = post
                            return .handled
                        }
                        return .systemAction
                    })
            }
        }

        /* 네비게이션 뒤로 */
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Label("뒤로", systemImage: "chevron.left")
                }
                .tint(Color("Lavender"))
            }
        }

        /* 최초 데이터 로드 */
        .task { await vm.loadInitial(challengeId: challengeId) }

        /* ③ .manage Alert 발생 감지 → confirmationDialog 띄우기 */
        .onChange(of: modalC.modalAlert?.id) { _, _ in
            guard case .manage(let post)? = modalC.modalAlert else { return }
            selectedPost = post
            showManageDialog = true
            modalC.resetAlert()
        }

        /* ④ 게시물 관리 시트 */
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

        /* ⑤ 실 Alert 처리(delete / report / block) */
        .alert(item: $modalC.modalAlert, content: makeAlert)

        /* ⑥ 💬 댓글 Sheet ― 전역에 1개만 (중복 방지) */
        .sheet(item: $commentSheetPost) { post in
            CommentsSheet(post: post)
                .environmentObject(modalC)
        }
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
            return Alert(title: Text(""))
        }
    }
}
