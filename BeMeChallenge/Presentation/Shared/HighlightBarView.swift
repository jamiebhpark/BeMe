//
//  Presentation/Shared/HighlightBarView.swift
//

import SwiftUI

/// 🔝 좋아요 Top-10 썸네일 바
struct HighlightBarView: View {
    let posts: [Post]
    let onSelect: (Post) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(popularPosts.prefix(10)) { post in
                    Button {
                        onSelect(post)
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            AsyncCachedImage(
                                url: URL(string: post.imageUrl),
                                content: { $0.resizable()
                                           .scaledToFill()
                                           .overlay(Color.black.opacity(0.15)) },
                                placeholder: { Color(.systemGray5) },
                                failure:     { Color(.systemGray5) }
                            )
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 8,
                                                        style: .continuous))

                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(totalLikes(post))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.9))
                            )
                            .offset(x: -4, y: -4)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 76, height: 76)
                    .accessibilityLabel("좋아요 \(totalLikes(post))개, 게시물 열기")
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)   // 👈 추가
        }
        .frame(height: 80)

        // ───────── Surface 카드 래퍼 ─────────
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("SurfaceSecondary"))
                .overlay(                                   // 1-pt 윤곽선
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color("SurfaceBorder"), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 3,
                        x: 0, y: 1)
        )
        .padding(.horizontal, 8)     // 카드 좌·우 8 pt → PostCell 과 동일
    }

    // MARK: – Helpers
    private func totalLikes(_ p: Post) -> Int {
        p.reactions["❤️", default: 0]
    }
    private var popularPosts: [Post] {
        posts.sorted { totalLikes($0) > totalLikes($1) }
    }
}
