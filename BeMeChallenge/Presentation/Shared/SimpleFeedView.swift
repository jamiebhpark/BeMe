// Presentation/Shared/SimpleFeedView.swift
import SwiftUI

struct SimpleFeedView: View {
    let posts: [Post]
    let user:  User
    let onDelete: (Post) -> Void
    let onReport: (Post) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(posts) { post in
                    PostCellView(
                        post: post,
                        user: user,
                        onLike:   {},                    // 좋아요 불필요
                        onReport: { onReport(post) },
                        onDelete: { onDelete(post) },
                        showActions: true                // ← 마지막에 위치
                    )
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
