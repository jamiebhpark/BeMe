// FeedView.swift
import SwiftUI

struct FeedView: View {

    // ── ① props ──────────────────────────────────────────
    let posts:      [Post]          // 원본
    let userCache:  [String: User]

    var onLike:   (Post) -> Void
    var onReport: (Post) -> Void
    var onDelete: (Post) -> Void

    // ── ② local state (하이라이트 재배치용) ───────────────
    @State private var displayedPosts: [Post] = []

    // ── ③ body ───────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                /* —— 하이라이트 바 —— */
                HighlightBarView(posts: displayedPosts) { tapped in
                    displayedPosts.removeAll { $0.id == tapped.id }
                    displayedPosts.insert(tapped, at: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)

                /* —— 일반 피드 —— */
                VStack(spacing: 24) {
                    ForEach(displayedPosts) { post in
                        PostCellView(
                            post: post,
                            user: author(for: post),
                            onLike:   { onLike(post) },
                            onReport: { onReport(post) },
                            onDelete: { onDelete(post) }
                        )
                        .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        // 🔑 최초 / 변경 시 동기화
        .onAppear            { displayedPosts = posts }
        .onChange(of: posts) { displayedPosts = $0 }
    }

    // ── helper ────────────────────────────────────────────
    private func author(for post: Post) -> User {
        userCache[post.userId] ??
        User(id: post.userId, nickname: "익명")
    }
}
