//
//  CommentsSheet.swift
//  BeMeChallenge
//
//  Updated: 2025-07-10 – 빈 상태 메시지 추가
//

import SwiftUI
import FirebaseAuth

struct CommentsSheet: View {

    let post: Post
    @StateObject private var vm: CommentsViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    @State private var input = ""

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
        // 🔻 여기 ↓ 추가
        .overlay(alignment: .top) {
            if let toast = modalC.toast {
                ToastBannerView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1_000)
                    .padding(.top, 8)
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
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
                            .contextMenu {
                                if c.userId == Auth.auth().currentUser?.uid {
                                    Button("삭제", role: .destructive) { vm.delete(c) }
                                } else {
                                    Button("신고", role: .destructive) { vm.report(c) }
                                }
                            }
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

                // ➕ 빈 상태 안내
                if vm.comments.isEmpty {
                    Text("아직 댓글이 없습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
