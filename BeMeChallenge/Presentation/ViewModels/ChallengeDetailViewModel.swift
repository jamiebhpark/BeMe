//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

@MainActor
final class ChallengeDetailViewModel: ObservableObject {

    // MARK: Published
    @Published private(set) var postsState: Loadable<[Post]> = .idle
    @Published private(set) var userCache: [String: User] = [:]

    // MARK: Private
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let userRepo: UserRepositoryProtocol = UserRepository()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init – 로그아웃 시 리스너 해제
    init() {
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                Task { @MainActor in self?.cancelListener() }
            }
            .store(in: &cancellables)
    }

    // MARK: Public API
    /// challengeId 에 해당하는 포스트 스트림 시작
    func fetch(_ challengeId: String) {
        cancelListener()
        postsState = .loading

        listener = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: challengeId)
            .whereField("reported", isEqualTo: false)     // ← ✅ 추가
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err { self.postsState = .failed(err); return }

                let posts = snap?.documents.compactMap(Post.init) ?? []  // ✅

                self.postsState = .loaded(posts)
                self.prefetchAuthors(from: posts)
            }
    }

    /// 특정 포스트에 좋아요를 토글 요청합니다.
    func like(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        ReactionService.shared.updateReaction(
            forPost: post.id,
            reactionType: "❤️",
            userId: uid
        ) { result in
            if case .failure(let err) = result {
                // 빌드 에러 방지를 위해 modalC 대신 print 사용
                print("❤️ 좋아요 실패:", err.localizedDescription)
            }
        }
    }

    func report(_ post: Post) {
        ReportService.shared.reportPost(postId: post.id) { _ in }
    }

    func deletePost(_ post: Post) {
        db.collection("challengePosts").document(post.id).delete { [weak self] err in
            if let err { print("delete err:", err.localizedDescription); return }
            guard case .loaded(var list) = self?.postsState else { return }
            list.removeAll { $0.id == post.id }
            self?.postsState = .loaded(list)
        }
    }

    // MARK: Listener 종료
    private func cancelListener() {
        listener?.remove(); listener = nil
        postsState = .idle
        userCache.removeAll()
    }

    // MARK: Helper – 작성자 캐시 선읽기
    private func prefetchAuthors(from posts: [Post]) {
        let missing = Set(posts.map { $0.userId }).subtracting(userCache.keys)
        guard !missing.isEmpty else { return }

        userRepo.fetchUsers(withIds: Array(missing)) { [weak self] result in
            guard let self else { return }
            if case .success(let users) = result {
                for u in users {
                    if let uid = u.id {
                        self.userCache[uid] = u
                    }
                }
            }
        }
    }
}
