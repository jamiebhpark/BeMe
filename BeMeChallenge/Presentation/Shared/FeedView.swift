//
//  Presentation/Shared/FeedView.swift
//  BeMeChallenge
//

import SwiftUI

struct FeedView: View {

    // ───────────── Dependencies ─────────────
    @ObservedObject var vm: ChallengeDetailViewModel
    // challengeId 은 더 이상 사용되지 않으므로 제거
    // (필요하다면 init 파라미터에서도 빼 주세요)

    // ───────────── Local state ───────────────
    @State private var displayed: [Post] = []
    private let bottomThreshold = 3          // 페이징 트리거

    // ───────────── View ─────────────────────
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {

                    highlightBarSection

                    ForEach(displayed) { post in
                        feedCell(for: post)
                            .onAppear { checkPagination(at: post) }
                    }

                    emptyStateSection
                    loadingMoreSpinner
                }
            }
            .refreshable {
                await vm.loadInitial(challengeId: vm.currentCID)
                // loadInitial 가 끝나면 refresh 인디케이터가 자동으로 사라집니다.
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear      { syncWithVM() }
            .onChange(of: vm.posts) { _, _ in syncWithVM() }
        }
    }

    // MARK: – Section Builders ·································

    /// 🔹 Top highlight thumbnails
    private var highlightBarSection: some View {
        HighlightBarView(posts: displayed) { tapped in
            displayed.removeAll { $0.id == tapped.id }
            displayed.insert(tapped, at: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
    }

    /// 🔹 단일 피드 셀 — 분리해 두면 컴파일러가 훨씬 빨라집니다
    @ViewBuilder
    private func feedCell(for post: Post) -> some View {
        PostCellView(
            post:     post,
            user:     author(for: post),
            onLike:   { likeOptimistic(post) },
            onReport: { vm.report(post) },
            onDelete: { vm.deletePost(post) }
        )
        .padding(.horizontal, 8)
    }

    /// 🔹 빈 상태 안내
    private var emptyStateSection: some View {
        Group {
            if displayed.isEmpty, case .loaded = vm.postsState{
                Text(vm.scope == .mine
                     ? "아직 업로드한 게시물이 없습니다."
                     : "게시물이 없습니다.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 40)
            }
        }
    }

    /// 🔹 하단 로딩 스피너
    private var loadingMoreSpinner: some View {
        Group {
            if vm.isLoadingMore {
                ProgressView().padding(.vertical, 20)
            }
        }
    }

    // MARK: – Pagination trigger
    private func checkPagination(at post: Post) {
        if indexOf(post) >= displayed.count - bottomThreshold {
            Task { await vm.loadMore() }
        }
    }

    // MARK: – Optimistic Like
    private func likeOptimistic(_ post: Post) {
        guard let idx = displayed.firstIndex(where: { $0.id == post.id }) else { return }

        var reactions = displayed[idx].reactions
        let key = "❤️"
        let alreadyLiked = reactions[key, default: 0] > 0
        reactions[key, default: 0] += alreadyLiked ? -1 : 1
        reactions[key] = max(reactions[key]!, 0)          // 음수 방지

        displayed[idx] = displayed[idx].copy(withReactions: reactions)
        vm.like(post)                                     // 서버 트랜잭션
    }

    // MARK: – Helpers
    private func author(for post: Post) -> LiteUser {
        vm.userCache[post.userId] ??
        LiteUser(id: post.userId, nickname: "익명", avatarURL: nil)
    }

    private func indexOf(_ post: Post) -> Int {
        displayed.firstIndex(of: post) ?? 0
    }

    private func syncWithVM() {
        displayed = vm.posts
        prefetchImages(from: vm.posts)
    }

    private func prefetchImages(from list: [Post]) {
        let urls = list.prefix(8).compactMap { URL(string: $0.imageUrl) }
        ImageCache.prefetch(urls: urls)
    }
}
