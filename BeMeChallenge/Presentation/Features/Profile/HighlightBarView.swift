// HighlightBarView.swift
import SwiftUI

/// 🔝 좋아요가 많은 순으로 10개까지 썸네일을 보여주는 하이라이트 바
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
                                content: { img in
                                    img
                                        .resizable()
                                        .scaledToFill()
                                        .overlay(Color.black.opacity(0.15))
                                },
                                placeholder: { Color(.systemGray5) },
                                failure:     { Color(.systemGray5) }
                            )
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(totalLikes(post))")
                                    .font(.caption2).bold()
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.red.opacity(0.9)))
                            .offset(x: -4, y: -4)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 76, height: 76)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("좋아요 \(totalLikes(post))개, 게시물 열기"))
                }
            }
            .padding(.horizontal, 12)
        }
        // ── 여기만 수정 ──
        .frame(height: 80)   // 기존 70 → 80 으로 늘려서 썸네일 잘림 방지
    }

    private func totalLikes(_ post: Post) -> Int {
        post.reactions["❤️", default: 0]
    }
    private var popularPosts: [Post] {
        posts.sorted { totalLikes($0) > totalLikes($1) }
    }
}
