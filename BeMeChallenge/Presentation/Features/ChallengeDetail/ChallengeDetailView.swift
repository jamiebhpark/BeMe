//
//  ChallengeDetailView.swift
//  BeMeChallenge
//
//  v7-fix – confirmationDialog 빌드 오류 해결
//

import SwiftUI
import FirebaseAuth

struct ChallengeDetailView: View {
    let challengeId: String

    @StateObject private var vm = ChallengeDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    // ───────── Alert · Sheet 상태 ─────────
    @State private var showManageDialog   = false
    @State private var selectedPost: Post?
    @State private var commentSheetPost: Post?

    // 🆕 캡션 수정
    @State private var editingPost:  Post?
    @State private var captionInput       = ""
    @State private var showCaptionEditor  = false

    var body: some View {
        VStack(spacing: 0) {

            // ① 세그먼트
            Picker("", selection: $vm.scope) {
                ForEach(FeedScope.allCases) { Text($0.rawValue).tag($0) }
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
                    Button("재시도") { Task { await vm.loadInitial(challengeId: challengeId) } }
                }
                .frame(maxHeight: .infinity)

            case .loaded:
                FeedView(vm: vm)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "comment",
                              let id   = url.host,
                              let post = vm.posts.first(where: { $0.id == id })
                        else { return .systemAction }
                        commentSheetPost = post
                        return .handled
                    })
            }
        }

        // 뒤로가기
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Label("뒤로", systemImage: "chevron.left")
                }
                .tint(Color("Lavender"))
            }
        }

        // 최초 로드
        .task { await vm.loadInitial(challengeId: challengeId) }

        // ③ .manage Alert 감지 → 사용자 정의 dialog 띄우기
        .onChange(of: modalC.modalAlert?.id) { _, _ in
            guard case .manage(let post)? = modalC.modalAlert else { return }
            selectedPost     = post
            showManageDialog = true
            modalC.resetAlert()
        }

        // ④ 게시물 관리 메뉴 (작성자 vs 타인 구분)
        .confirmationDialog(
            "게시물 관리",
            isPresented: $showManageDialog,
            titleVisibility: .visible
        ) {
            if let post = selectedPost {
                if Auth.auth().currentUser?.uid == post.userId {
                    // ── 작성자 ──
                    Button("캡션 수정") {
                        captionInput       = post.caption ?? ""
                        editingPost        = post
                        showCaptionEditor  = true
                    }
                    Button("삭제", role: .destructive) {
                        modalC.showAlert(.deleteConfirm(post: post))
                    }
                } else {
                    // ── 타인 ──
                    Button("신고", role: .destructive) {
                        modalC.showAlert(.reportConfirm(post: post))
                    }
                    Button("차단", role: .destructive) {
                        modalC.showAlert(.blockConfirm(
                            userId:   post.userId,
                            userName: post.userId   // 닉네임으로 바꾸려면 수정
                        ))
                    }
                }
            }
            Button("취소", role: .cancel) { }
        }

        // ⑤ delete / report / block Alert
        .alert(item: $modalC.modalAlert, content: makeAlert)

        // ⑥ 💬 댓글 Sheet
        .sheet(item: $commentSheetPost) { post in
            CommentsSheet(post: post)
                .environmentObject(modalC)
        }

        // ⑦ 캡션 수정 Alert
        .alert(
            "캡션 수정",
            isPresented: $showCaptionEditor,
            actions: {
                TextField("80자 이내", text: $captionInput)
                Button("저장") {
                    if let p = editingPost {
                        vm.updateCaption(p, to: captionInput)
                    }
                }
                Button("취소", role: .cancel) { }
            },
            message: { Text("부적절한 표현 또는 80자를 초과하면 저장되지 않습니다.") }
        )
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
                secondaryButton: .cancel { modalC.resetAlert() })

        case .reportConfirm(let post):
            return Alert(
                title: Text("신고 확인"),
                message: Text("이 게시물을 신고하시겠습니까?"),
                primaryButton: .destructive(Text("신고")) {
                    vm.report(post)
                    modalC.resetAlert()
                    modalC.showToast(.init(message: "신고 접수"))
                },
                secondaryButton: .cancel { modalC.resetAlert() })

        case .blockConfirm(let uid, let name):
            return Alert(
                title: Text("\(name)님을 차단하시겠습니까?"),
                message: Text("차단된 사용자의 게시물은 더 이상 보이지 않습니다."),
                primaryButton: .destructive(Text("차단")) {
                    BlockService.shared.block(userId: uid) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                modalC.showToast(.init(message: "차단되었습니다"))
                            case .failure:
                                modalC.showToast(.init(message: "차단 실패"))
                            }
                        }
                    }
                    modalC.resetAlert()
                },
                secondaryButton: .cancel { modalC.resetAlert() })

        default:
            return Alert(title: Text(""))
        }
    }
}
