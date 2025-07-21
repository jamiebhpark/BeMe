//
//  PostDetailView.swift
//  BeMeChallenge
//
//  관리자 전용: 신고-푸시로 열린 게시물 확인 + 조치(삭제·신고·차단)
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// 관리자 전용: 신고·푸시로 열린 게시물 확인 + 조치(삭제·신고·차단)
struct PostDetailView: View {
    let post: Post
    var allowComments: Bool = true      // 댓글 버튼 노출 여부

    // MARK: Env & State
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator
    @EnvironmentObject private var authVM: AuthViewModel  // 관리자 판별
    @State private var showComments = false
    @State private var showManageDlg = false
    @State private var author: LiteUser?

    var body: some View {
        NavigationStack {
            ScrollView {
                PostCellView(
                    post: post,
                    user: author,
                    onLike: {},                          // 좋아요 비활성
                    onReport: { modalC.showAlert(.reportConfirm(post: post)) },
                    onDelete: { modalC.showAlert(.deleteConfirm(post: post)) },
                    showActions: true                    // 우측 ‘…’ 메뉴 활성
                )
                .environmentObject(modalC)
                .padding()
            }
            .navigationTitle("게시물")
            .navigationBarTitleDisplayMode(.inline)
            .task { await fetchAuthor() }

            // 툴바: 닫기 / 댓글 (선택)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Color("TextPrimary"))
                }
                if allowComments {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showComments = true } label: {
                            Label("댓글", systemImage: "bubble.right")
                        }
                        .tint(Color("Lavender"))
                    }
                }
            }

            // 댓글 Sheet
            .sheet(isPresented: $showComments) {
                CommentsSheet(post: post)
                    .environmentObject(modalC)
            }

            // ‘…’ 메뉴 트리거
            .onChange(of: modalC.modalAlert?.id) { _, _ in
                if case .manage(_) = modalC.modalAlert {
                    showManageDlg = true
                }
            }

            // ① 관리 메뉴 다이얼로그
            .confirmationDialog(
                "게시물 관리",
                isPresented: $showManageDlg,
                titleVisibility: .visible,
                actions: buildManageMenu
            )

            // ② 삭제·신고·차단 Alert (manage 제외)
            .alert(item: Binding<ModalAlert?>(
                get: {
                    guard let alert = modalC.modalAlert else { return nil }
                    switch alert {
                    case .deleteConfirm, .reportConfirm, .blockConfirm:
                        return alert
                    default:
                        return nil
                    }
                },
                set: { newVal in
                    modalC.modalAlert = newVal
                }
            )) { alert in
                makeAlert(for: alert)
            }
        }
    }

    // MARK: 작성자 정보 로드
    @MainActor
    private func fetchAuthor() async {
        let snap = try? await Firestore.firestore()
            .collection("users")
            .document(post.userId)
            .getDocument()
        guard let data = snap?.data() else { return }
        author = LiteUser(
            id: post.userId,
            nickname: data["nickname"] as? String ?? "익명",
            avatarURL: (data["profileImageURL"] as? String).flatMap(URL.init)
        )
    }

    // MARK: ‘…’ 메뉴 빌더
    @ViewBuilder private func buildManageMenu() -> some View {
        let currentUID = Auth.auth().currentUser?.uid
        let isOwner = post.userId == currentUID
        let isAdmin = authVM.isAdmin

        if isOwner || isAdmin {
            Button("삭제", role: .destructive) {
                modalC.showAlert(.deleteConfirm(post: post))
            }
        } else {
            Button("신고", role: .destructive) {
                modalC.showAlert(.reportConfirm(post: post))
            }
            Button("차단", role: .destructive) {
                modalC.showAlert(
                    .blockConfirm(userId: post.userId,
                                  userName: author?.nickname ?? "익명")
                )
            }
        }
        Button("취소", role: .cancel) { modalC.resetAlert() }
    }

    // MARK: Alert Builder
    private func makeAlert(for alert: ModalAlert) -> Alert {
        switch alert {
        case .deleteConfirm(let pst):
            return Alert(
                title: Text("삭제 확인"),
                message: Text("정말 이 게시물을 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("삭제")) { deletePost(pst) },
                secondaryButton: .cancel { modalC.resetAlert() }
            )
        case .reportConfirm(let pst):
            return Alert(
                title: Text("신고 확인"),
                message: Text("이 게시물을 신고하시겠습니까?"),
                primaryButton: .destructive(Text("신고")) { reportPost(pst) },
                secondaryButton: .cancel { modalC.resetAlert() }
            )
        case .blockConfirm(let uid, _):
            return Alert(
                title: Text("차단 확인"),
                message: Text("차단된 사용자의 게시물은 더 이상 보이지 않습니다."),
                primaryButton: .destructive(Text("차단")) {
                    BlockService.shared.block(userId: uid) { _ in
                        modalC.showToast(.init(message: "차단되었습니다"))
                    }
                    modalC.resetAlert()
                },
                secondaryButton: .cancel { modalC.resetAlert() }
            )
        default:
            return Alert(title: Text(""))
        }
    }

    // MARK: 삭제 / 신고 액션
    private func deletePost(_ pst: Post) {
        Firestore.firestore()
            .collection("challengePosts")
            .document(pst.id)
            .delete { err in
                modalC.resetAlert()
                if let err = err {
                    modalC.showToast(.init(message: "삭제 실패: \(err.localizedDescription)"))
                } else {
                    modalC.showToast(.init(message: "삭제 완료"))
                    dismiss()
                }
            }
    }

    private func reportPost(_ pst: Post) {
        Functions.functions(region: "asia-northeast3")
            .httpsCallable("reportPost")
            .call(["postId": pst.id]) { _, err in
                modalC.resetAlert()
                if let err = err {
                    modalC.showToast(.init(message: "신고 실패: \(err.localizedDescription)"))
                } else {
                    modalC.showToast(.init(message: "신고 접수"))
                }
            }
    }
}
