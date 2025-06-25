//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//
//  *v3* – “전체 / 내 게시물” 세그먼트 지원
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ChallengeDetailViewModel: ObservableObject {

    // ────────────────────────────────────────────────
    // MARK: - 📤 OUTPUT
    // ────────────────────────────────────────────────
    @Published private(set) var posts:       [Post]          = []
    @Published private(set) var postsState:  Loadable<Void>  = .idle
    @Published private(set) var isLoadingMore               = false
    @Published private(set) var userCache:   [String: LiteUser] = [:]

    // 현재 선택된 세그먼트
    @Published var scope: FeedScope = .all {
        didSet { Task { await loadInitial(challengeId: currentCID) } }
    }

    // ────────────────────────────────────────────────
    // MARK: - 🔑 PRIVATE
    // ────────────────────────────────────────────────
    private let db = Firestore.firestore()
    private let pageSize = 20

    private var lastDoc:  DocumentSnapshot?
    private var currentCID = ""
    private var cancellables = Set<AnyCancellable>()

    private let userRepo: UserRepositoryProtocol = UserRepository()

    // MARK: - Init
    init() {
        // 로그아웃 시 상태 초기화
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in Task { @MainActor in self?.resetState() } }
            .store(in: &cancellables)
    }

    // ────────────────────────────────────────────────
    // MARK: - PUBLIC API
    // ────────────────────────────────────────────────

    /// 첫 페이지 로딩
    func loadInitial(challengeId cid: String) async {
        currentCID = cid
        resetState()
        postsState = .loading

        do {
            let (list, last) = try await fetchPage(after: nil)
            posts    = list
            lastDoc  = last
            postsState = .loaded(())
            prefetchAuthors(from: list)
        } catch {
            postsState = .failed(error)
        }
    }

    /// 추가 페이지
    func loadMore() async {
        guard !isLoadingMore, let lastDoc else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let (list, last) = try await fetchPage(after: lastDoc)
            posts += list
            self.lastDoc = last
            prefetchAuthors(from: list)
        } catch {
            print("🚨 pagination :", error.localizedDescription)
        }
    }

    /// ♥️ Optimistic Like
    func like(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1️⃣  UI 즉시 반영
        applyDelta(+1, for: post)

        // 2️⃣  서버 트랜잭션
        ReactionService.shared.updateReaction(
            forPost: post.id,
            reactionType: "❤️",
            userId: uid) { [weak self] result in
                if case .failure = result {
                    // 3️⃣  실패 시 롤백
                    Task { @MainActor in self?.applyDelta(-1, for: post) }
                }
            }
    }

    func report(_ post: Post) {
        ReportService.shared.reportPost(postId: post.id) { [weak self] res in
            if case .success = res {
                Task { @MainActor in self?.posts.removeAll { $0.id == post.id } }
            }
        }
    }

    func deletePost(_ post: Post) {
        db.collection("challengePosts").document(post.id).delete { [weak self] err in
            if err == nil {
                self?.posts.removeAll { $0.id == post.id }
            }
        }
    }

    // ────────────────────────────────────────────────
    // MARK: - PRIVATE HELPERS
    // ────────────────────────────────────────────────

    /// Firestore 쿼리 한 페이지
    private func fetchPage(after doc: DocumentSnapshot?) async throws
    -> ([Post], DocumentSnapshot?) {

        // 기본 필터
        var query = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: currentCID)
            .whereField("reported",    isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        // “내 게시물” 스코프
        if scope == .mine, let uid = Auth.auth().currentUser?.uid {
            query = query.whereField("userId", isEqualTo: uid)
        }

        if let doc { query = query.start(afterDocument: doc) }

        let snap = try await query.getDocuments()
        let list = snap.documents.compactMap(Post.init)
        return (list, snap.documents.last)
    }

    private func resetState() {
        posts = []; userCache.removeAll()
        lastDoc = nil; postsState = .idle
    }

    /// Like +/− 1 적용
    private func applyDelta(_ delta: Int, for post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        var p = posts[idx]
        var map = p.reactions
        map["❤️", default: 0] = max(0, map["❤️", default: 0] + delta)
        p = p.copy(withReactions: map)
        posts[idx] = p
    }

    /// 작성자 정보 프리패치
    private func prefetchAuthors(from page: [Post]) {
        let missing = Set(page.map(\.userId)).subtracting(userCache.keys)
        guard !missing.isEmpty else { return }

        userRepo.fetchUsers(withIds: Array(missing)) { [weak self] res in
            if case .success(let users) = res {
                for u in users {
                    self?.userCache[u.id] = LiteUser(
                        id:        u.id,
                        nickname:  u.nickname,
                        avatarURL: u.effectiveProfileImageURL
                    )
                }
            }
        }
    }
}
