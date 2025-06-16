//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ChallengeDetailViewModel: ObservableObject {

    // ─────────────────────── Published ───────────────────────
    @Published var posts: [Post]              = []          // 피드 데이터
    @Published var postsState: Loadable<Void> = .idle       // 로딩/에러 표시
    @Published var isLoadingMore: Bool        = false       // 하단 스피너
    @Published private(set) var userCache: [String: User] = [:]

    // ─────────────────────── Private ────────────────────────
    private let db         = Firestore.firestore()
    private let pageSize   = 20
    private var lastDoc: DocumentSnapshot?                 // 페이지 커서
    private let userRepo: UserRepositoryProtocol = UserRepository()
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Init  (로그아웃 시 상태 초기화)
    init() {
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                Task { @MainActor in self?.resetState() }
            }
            .store(in: &cancellables)
    }

    // ─────────────────────── Public API ─────────────────────

    /// ① 첫 페이지
    func loadInitial(challengeId: String) async {
        resetState()
        postsState = .loading
        do {
            let (list, last) = try await fetchPage(challengeId, after: nil)
            posts = list
            lastDoc = last
            postsState = .loaded(())
            prefetchAuthors(from: list)
        } catch {
            postsState = .failed(error)
        }
    }

    /// ② 추가 페이지
    func loadMore(challengeId: String) async {
        guard !isLoadingMore, let lastDoc else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let (list, last) = try await fetchPage(challengeId, after: lastDoc)
            posts += list
            self.lastDoc = last
            prefetchAuthors(from: list)
        } catch {
            print("pagination err:", error.localizedDescription)
        }
    }

    /// ③ 좋아요 토글 + Optimistic UI
    func like(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1) 화면에 *즉시* 반영
        let key   = "❤️"
        let liked = post.reactions[key, default: 0] > 0
        let delta = liked ? -1 : 1
        applyOptimisticLike(postId: post.id, delta: delta)

        // 2) 트랜잭션 실행
        ReactionService.shared.updateReaction(
            forPost: post.id,
            reactionType: key,
            userId: uid
        ) { [weak self] result in
            if case .failure(let err) = result {
                print("❤️ 좋아요 실패:", err.localizedDescription)
                // 3) 실패 시 UI 롤백
                Task { @MainActor in
                    self?.applyOptimisticLike(postId: post.id, delta: -delta)
                }
            }
        }
    }

    /// ④ 신고
    func report(_ post: Post) {
        ReportService.shared.reportPost(postId: post.id) { _ in }
    }

    /// ⑤ 삭제
    func deletePost(_ post: Post) {
        db.collection("challengePosts").document(post.id).delete { [weak self] err in
            if let err = err {
                print("delete err:", err.localizedDescription)
            } else {
                self?.posts.removeAll { $0.id == post.id }
            }
        }
    }

    // ─────────────────────── Private helpers ─────────────────────

    /// Optimistic Like 적용 / 롤백
    private func applyOptimisticLike(postId: String, delta: Int) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        var p = posts[idx]
        var map = p.reactions
        map["❤️", default: 0] += delta
        if map["❤️"]! < 0 { map["❤️"] = 0 }          // 음수 방지
        p = Post(id: p.id,
                 challengeId: p.challengeId,
                 userId: p.userId,
                 imageUrl: p.imageUrl,
                 createdAt: p.createdAt,
                 reactions: map,
                 reported: p.reported,
                 caption: p.caption)
        posts[idx] = p
    }

    private func resetState() {
        posts          = []
        lastDoc        = nil
        postsState     = .idle
        userCache.removeAll()
    }

    /// 페이지 쿼리
    private func fetchPage(_ cid: String,
                           after doc: DocumentSnapshot?) async throws
        -> ([Post], DocumentSnapshot?)
    {
        var q = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: cid)
            .whereField("reported",    isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if let doc { q = q.start(afterDocument: doc) }

        let snap = try await q.getDocuments()
        let list = snap.documents.compactMap(Post.init)
        return (list, snap.documents.last)
    }

    /// 작성자 캐싱
    private func prefetchAuthors(from posts: [Post]) {
        let missing = Set(posts.map { $0.userId }).subtracting(userCache.keys)
        guard !missing.isEmpty else { return }

        userRepo.fetchUsers(withIds: Array(missing)) { [weak self] result in
            if case .success(let users) = result {
                for u in users {
                    if let uid = u.id { self?.userCache[uid] = u }
                }
            }
        }
    }
}
