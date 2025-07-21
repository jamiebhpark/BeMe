//
//  CommentsSheet.swift
//  BeMeChallenge
//
//  Updated: 2025-07-26 – 댓글 신고 플래그 기반 하이라이트
//

import SwiftUI
import FirebaseAuth

struct CommentsSheet: View {

    let post: Post

    // VM & Env
    @StateObject private var vm: CommentsViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject      private var modalC: ModalCoordinator

    // Local UI State
    @State private var input = ""
    @State private var showingEditAlert  = false
    @State private var editedText        = ""
    @State private var editingComment: Comment?

    // Init
    init(post: Post) {
        self.post = post
        _vm = StateObject(wrappedValue: CommentsViewModel(postId: post.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            listSection
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
        .alert("댓글 수정", isPresented: $showingEditAlert) {
            TextField("", text: $editedText, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
            Button("저장") {
                if let c = editingComment {
                    vm.edit(c, newText: editedText)
                }
            }
            Button("취소", role: .cancel) { }
        } message: { Text("300자까지 입력 가능합니다.") }
        .onAppear { scrollToFlagged() }
    }

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

    private var listSection: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(vm.comments) { c in
                    CommentRow(comment: c,
                               user: vm.userCache[c.userId],
                               isFlagged: c.reported)
                        .listRowSeparator(.hidden)
                        .contextMenu { contextMenu(for: c) }
                }
            }
            .listStyle(.plain)
            // ↑ 여기서 iOS17 deprecation fix: 두 파라미터 클로저 사용
            .onChange(of: vm.comments) { _old, _new in
                scrollToFlagged(using: proxy)
            }
            .onAppear {
                scrollToFlagged(using: proxy)
            }
        }
    }

    /// 신고된 첫 댓글로 스크롤
    private func scrollToFlagged(using proxy: ScrollViewProxy? = nil) {
        guard let flagged = vm.comments.first(where: { $0.reported })?.id else { return }
        if let p = proxy {
            withAnimation { p.scrollTo(flagged, anchor: .center) }
        }
    }

    // Context Menu
    @ViewBuilder
    private func contextMenu(for c: Comment) -> some View {
        let me       = Auth.auth().currentUser?.uid
        let isOwner  = c.userId == me
        let canDelete = isOwner || c.isAdmin

        if isOwner {
            Button("수정") {
                editingComment = c
                editedText     = c.text
                showingEditAlert = true
            }
        }

        if canDelete {
            Button("삭제", role: .destructive) { vm.delete(c) }
        } else {
            Button("신고", role: .destructive) { vm.report(c) }
            Button("차단", role: .destructive) {
                BlockService.shared.block(userId: c.userId) { result in
                    DispatchQueue.main.async {
                        let msg: String
                        if case .success = result {
                            msg = "차단되었습니다"
                        } else {
                            msg = "차단 실패"
                        }
                        modalC.showToast(.init(message: msg))
                    }
                }
            }
        }
    }

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
    private func CommentRow(
        comment: Comment,
        user: LiteUser?,
        isFlagged: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            avatar(for: user)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(displayName(for: user))
                        .font(.subheadline).bold()
                    if isFlagged {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                    }
                    Text(comment.createdAt, formatter: Self.df)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.text).font(.subheadline)
                if comment.editedAt != nil {
                    Text("(수정됨)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .background(isFlagged ? Color.yellow.opacity(0.35) : Color.clear)
        .id(comment.id)
    }

    // MARK: Helpers
    private func avatar(for user: LiteUser?) -> some View {
        Group {
            if let url = user?.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Image("defaultAvatar").resizable()
                    }
                }
            } else {
                Image("defaultAvatar").resizable()
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private func displayName(for user: LiteUser?) -> String {
        let raw = user?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "익명" : raw
    }

    private static let df: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "yy.MM.dd HH:mm"; return df
    }()
}

#if canImport(UIKit)
private extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif
