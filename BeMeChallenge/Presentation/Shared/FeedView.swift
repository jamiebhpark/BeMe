//
//  FeedView.swift
//  BeMeChallenge
//

import SwiftUI

struct FeedView: View {

    // ─────────────────────────────────────────────
    @ObservedObject var vm: ChallengeDetailViewModel
    let challengeId: String

    @State private var displayed: [Post] = []
    private let bottomThreshold = 3                // 페이징 트리거

    // MARK: – View
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {

                    // ── Highlight Bar ──────────────────────────
                    HighlightBarView(posts: displayed) { tapped in
                        displayed.removeAll { $0.id == tapped.id }
                        displayed.insert(tapped, at: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 16)

                    // ── Feed 셀 ───────────────────────────────
                    ForEach(displayed) { post in
                        PostCellView(
                            post: post,
                            user: author(for: post),
                            onLike:   { likeOptimistically(post) },
                            onReport: { vm.report(post) },
                            onDelete: { vm.deletePost(post) }
                        )
                        .padding(.horizontal, 8)
                        .onAppear {
                            if indexOf(post) >= displayed.count - bottomThreshold {
                                Task { await vm.loadMore(challengeId: challengeId) }
                            }
                        }
                    }

                    if vm.isLoadingMore {
                        ProgressView().padding(.vertical, 16)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            // ── 동기화 루틴들 ────────────────────────────────
            .onAppear {
                displayed = vm.posts
                prefetchImages(from: vm.posts)
            }
            .onChange(of: vm.posts) { _, newPosts in  // oldValue는 필요 없으니 “_” 로 무시
                displayed = newPosts
                prefetchImages(from: newPosts)
            }
            .onReceive(vm.$postsState) { state in
                if case .loaded = state,
                   let first = vm.posts.first {
                    proxy.scrollTo(first.id, anchor: .top)
                }
            }
            .task {
                if vm.posts.isEmpty {
                    await vm.loadInitial(challengeId: challengeId)
                }
            }
        }
    }

    // MARK: – Optimistic Like ---------------------------------------------
    private func likeOptimistically(_ post: Post) {
        guard let idx = displayed.firstIndex(where: { $0.id == post.id }) else { return }

        // 1️⃣ reactions 사본을 수정
        var newReactions = displayed[idx].reactions
        let key = "❤️"
        let cur = newReactions[key, default: 0]
        newReactions[key] = cur == 0 ? 1 : 0      // 토글

        // 2️⃣ 수정된 딕셔너리로 새 Post 생성
        let updated = Post(
            id:           post.id,
            challengeId:  post.challengeId,
            userId:       post.userId,
            imageUrl:     post.imageUrl,
            createdAt:    post.createdAt,
            reactions:    newReactions,
            reported:     post.reported,
            caption:      post.caption
        )

        // 3️⃣ 배열 교체 → UI 즉시 반영
        displayed[idx] = updated

        // 4️⃣ 백엔드 업데이트
        vm.like(post)
    }

    // MARK: – Helpers ------------------------------------------------------
    private func author(for post: Post) -> User {
        vm.userCache[post.userId] ?? User(id: post.userId, nickname: "익명")
    }

    private func indexOf(_ post: Post) -> Int {
        displayed.firstIndex(of: post) ?? 0
    }

    private func prefetchImages(from posts: [Post]) {
        let urls = posts.prefix(8).compactMap { URL(string: $0.imageUrl) }
        ImageCache.prefetch(urls: urls)
    }
}
