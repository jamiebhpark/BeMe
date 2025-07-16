//
//  CommentsSheet.swift
//  BeMeChallenge
//
//  Updated: 2025-07-15 – 댓글 *수정* 기능 & 빈 상태 메시지
//

import SwiftUI
import FirebaseAuth

struct CommentsSheet: View {

    let post: Post
    @StateObject private var vm: CommentsViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    @State private var input = ""

    // 🆕 수정 관련 State ---------------------------
    @State private var showingEditAlert  = false
    @State private var editedText        = ""
    @State private var editingComment: Comment?
    // --------------------------------------------

    // MARK: Init
    init(post: Post) {
        self.post = post
        _vm = StateObject(wrappedValue: CommentsViewModel(postId: post.id))
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            header
            list
            inputBar
        }
        .onTapGesture { hideKeyboard() }
        .overlay(alignment: .top) {
            if let toast = modalC.toast {
                ToastBannerView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1_000)
                    .padding(.top, 8)
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
        // 🆕 Alert with TextField ------------------
        .alert("댓글 수정",
               isPresented: $showingEditAlert,
               actions: {
                   TextField("", text: $editedText, axis: .vertical)
                       .lineLimit(3, reservesSpace: true)
                   Button("저장") {
                       if let target = editingComment {
                           vm.edit(target, newText: editedText)
                       }
                   }
                   Button("취소", role: .cancel) { }
               },
               message: { Text("300자까지 입력 가능합니다.") })
    }

    // MARK: Header
    private var header: some View {
        HStack {
            Text("댓글 \(vm.comments.count)")
                .font(.headline)
            Spacer()
            Button("닫기") { dismiss() }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: List (+ 빈 상태)
    private var list: some View {
        ScrollViewReader { proxy in
            ZStack {
                List {
                    ForEach(vm.comments) { c in
                        CommentRow(comment: c, user: vm.userCache[c.userId])
                            .listRowSeparator(.hidden)
                            .contextMenu { contextMenu(for: c) }   // 🆕
                    }
                }
                .listStyle(.plain)
                .onChange(of: vm.comments.count) { _, _ in
                    if let last = vm.comments.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if vm.comments.isEmpty {
                    Text("아직 댓글이 없습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // 🆕 컨텍스트 메뉴 빼서 함수화
    @ViewBuilder
    private func contextMenu(for c: Comment) -> some View {
        if c.userId == Auth.auth().currentUser?.uid {
            Button("수정") {
                editingComment = c
                editedText = c.text
                showingEditAlert = true
            }
            Button("삭제", role: .destructive) { vm.delete(c) }
        } else {
            Button("신고", role: .destructive) { vm.report(c) }
        }
        // 🔥 [NEW] 작성자 차단
        Button("차단", role: .destructive) {
            BlockService.shared.block(userId: c.userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        modalC.showToast(.init(message: "차단되었습니다"))
                    case .failure:
                        modalC.showToast(.init(message: "차단에 실패했습니다"))
                    }
                }
            }
        }
    }

    // MARK: Input bar
    private var inputBar: some View {
        HStack {
            TextField("댓글 달기…", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button("전송") {
                vm.addComment(text: input)
                input = ""
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    // MARK: Row
    @ViewBuilder
    private func CommentRow(comment: Comment, user: LiteUser?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            avatar(for: user)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(displayName(for: user))
                        .font(.subheadline).bold()
                    Text(comment.createdAt, formatter: Self.df)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.text)
                    .font(.subheadline)
                if comment.editedAt != nil {
                    Text("(수정됨)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .id(comment.id)
    }

    private func avatar(for user: LiteUser?) -> some View {
        Group {
            if let url = user?.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Image("defaultAvatar").resizable()
                    }
                }.id(url)
            } else {
                Image("defaultAvatar").resizable()
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private func displayName(for user: LiteUser?) -> String {
        let name = user?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "익명" : name
    }

    private static let df: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "yy.MM.dd HH:mm"; return df
    }()
}

/* ------------- 작은 유틸 ------------- */
#if canImport(UIKit)
private extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif
