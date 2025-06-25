//
//  ProfileViewModel.swift
//  BeMeChallenge
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine
import UIKit

// ──────────────────────────────────────────────────────────────
@MainActor
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Published
    @Published private(set) var profileState: Loadable<UserProfile> = .idle
    @Published private(set) var userPosts: [Post] = []
    
    // MARK: - Private
    private let db      = Firestore.firestore()
    private let storage = Storage.storage()
    
    private var profileListener: ListenerRegistration?
    private var postsListener:   ListenerRegistration?
    private var cancellables     = Set<AnyCancellable>()
    
    // MARK: - Init
    init() {
        startListeners()
        
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                print("🔌 sign-out → stopListeners")
                self?.stopListeners()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .didSignIn)
            .sink { [weak self] _ in
                print("⚡️ sign-in → startListeners")
                self?.startListeners()
            }
            .store(in: &cancellables)
    }
    
    // MARK: Listener 관리 ---------------------------------------------------
    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("▶️ startListeners for uid:", uid)
        
        // ── 프로필 -------------------------------------
        profileState = .loading
        profileListener = db.document("users/\(uid)")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                
                if let err {
                    print("❌ profileListener error:", err)
                    self.profileState = .failed(err)
                    return
                }
                
                guard let data = snap?.data() else {
                    print("ℹ️ user doc missing – create skeleton")
                    self.db.document("users/\(uid)")
                        .setData(["nickname": "익명"], merge: true)
                    return
                }
                
                if data["nickname"] == nil {
                    print("ℹ️ nickname missing – patch")
                    self.db.document("users/\(uid)")
                        .setData(["nickname": "익명"], merge: true)
                    return
                }
                
                if let user = User(document: snap!) {
                    self.profileState = .loaded(user)
                } else {
                    self.profileState = .failed(self.simpleErr("프로필 디코딩 실패"))
                }
            }
        
        // ── 내 포스트 ----------------------------------
        postsListener = db.collection("challengePosts")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                if snap.metadata.hasPendingWrites { return }   // pending 쓰기 무시
                self.userPosts = snap.documents.compactMap(Post.init(document:))
            }
    }
    
    private func stopListeners() {
        print("⏹ stopListeners")
        profileListener?.remove(); profileListener = nil
        postsListener?.remove();   postsListener   = nil
        profileState = .idle
        userPosts.removeAll()
    }
    
    func refresh() {
        print("🔄 manual refresh")
        stopListeners()
        startListeners()
    }
    
    // MARK: 프로필 정보 업데이트 --------------------------------------------
    func updateProfile(nickname: String,
                       bio: String?,
                       location: String?) async -> Result<Void, Error> {
        print("🔥 updateProfile: started")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            return .failure(simpleErr("로그인이 필요합니다"))
        }
        
        let raw: [String: Any?] = [
            "nickname": nickname,
            "bio":      bio,
            "location": location
        ]
        let data = raw.compactMapValues { $0 }
        
        return await withCheckedContinuation { cont in
            db.collection("users").document(uid).updateData(data) { err in
                if let err {
                    print("❌ updateProfile error:", err)
                    cont.resume(returning: .failure(err))
                } else {
                    print("✅ updateProfile success")
                    cont.resume(returning: .success(()))
                }
            }
        }
    }
    
    // MARK: 프로필 사진 -------------------------------------------------------
    func updateProfilePicture(_ image: UIImage,
                              completion: @escaping (Result<Void, Error>) -> Void) {
        print("👆 사진 업데이트 버튼 탭")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.failure(simpleErr("로그인이 필요합니다")))
        }
        guard let data = image.resized(maxPixel: 1024)
                .jpegData(compressionQuality: 0.8) else {
            return completion(.failure(simpleErr("이미지 인코딩 실패")))
        }
        
        let ref = storage.reference().child("profile_images/\(uid).jpg")
        print("🔥 updateProfilePicture: putData 시작")
        
        ref.putData(data, metadata: nil) { _, err in
            if let err {
                print("❌ putData 실패:", err)
                return completion(.failure(err))
            }
            print("✅ putData 성공, downloadURL 요청")
            
            ref.downloadURL { [weak self] url, err in
                guard let self else { return }
                if let err {
                    print("❌ downloadURL 실패:", err)
                    return completion(.failure(err))
                }
                guard let url else {
                    return completion(.failure(self.simpleErr("URL 획득 실패")))
                }
                print("✅ downloadURL 획득, Firestore update 시도")
                
                self.db.collection("users").document(uid).updateData([
                    "profileImageURL":       url.absoluteString,
                    "profileImageUpdatedAt": FieldValue.serverTimestamp()
                ]) { err in
                    if let err {
                        print("❌ Firestore update 실패:", err)
                        completion(.failure(err))
                    } else {
                        print("✅ Firestore update 성공")
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    /// 기본 아바타로 되돌리기
    func resetProfilePicture() async -> Result<Void, Error> {
        print("👆 기본 아바타 버튼 탭")
        guard let uid = Auth.auth().currentUser?.uid else {
            return .failure(simpleErr("로그인이 필요합니다"))
        }
        return await withCheckedContinuation { cont in
            print("🔥 resetProfilePicture: update 시작")
            db.collection("users").document(uid).updateData([
                "profileImageURL":       FieldValue.delete(),
                "profileImageUpdatedAt": FieldValue.delete()
            ]) { err in
                if let err {
                    print("❌ resetProfilePicture 실패:", err)
                    cont.resume(returning: .failure(err))
                } else {
                    print("✅ resetProfilePicture 성공")
                    cont.resume(returning: .success(()))
                }
            }
        }
    }
    
    // MARK: 게시물 관리 -----------------------------------------------------
    func deletePost(_ post: Post) {
        db.collection("challengePosts")
            .document(post.id)
            .delete { [weak self] err in
                if err == nil {
                    Task { @MainActor in
                        self?.userPosts.removeAll { $0.id == post.id }
                    }
                }
            }
    }
    
    func reportPost(_ post: Post) {
        ReportService.shared.reportPost(postId: post.id) { [weak self] result in
            if case .success = result {
                Task { @MainActor in
                    self?.userPosts.removeAll { $0.id == post.id }
                }
            }
        }
    }
    
    // MARK: Helper
    private func simpleErr(_ msg: String) -> NSError {
        .init(domain: "Profile", code: -1,
              userInfo: [NSLocalizedDescriptionKey: msg])
    }
    
    // MARK: Post Reaction (옵티미스틱 UI)
    func toggleLike(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 1) 로컬 먼저 반영
        if let idx = userPosts.firstIndex(where: { $0.id == post.id }) {
            let p = userPosts[idx]
            var reactions = p.reactions
            let key = "❤️"
            let currentlyLiked = (reactions[key] ?? 0) > 0
            reactions[key] = currentlyLiked ? reactions[key]! - 1
                                            : (reactions[key] ?? 0) + 1
            userPosts[idx] = p.copy(withReactions: reactions)
        }
        
        // 2) 서버 호출
        ReactionService.shared.updateReaction(
            forPost: post.id,
            reactionType: "❤️",
            userId: uid
        ) { [weak self] result in
            // 3) 실패 시 롤백
            if case .failure = result {
                Task { @MainActor in
                    guard let idx = self?.userPosts.firstIndex(where: { $0.id == post.id }) else { return }
                    let p = self!.userPosts[idx]
                    var reactions = p.reactions
                    let key = "❤️"
                    let wasLiked = (reactions[key] ?? 0) > 0
                    reactions[key] = wasLiked ? reactions[key]! - 1
                                               : (reactions[key] ?? 0) + 1
                    self?.userPosts[idx] = p.copy(withReactions: reactions)
                }
            }
        }
    }
}

// ------------------------------------------------------------------------
// UserProfile = User  (타입 별칭, 모델은 Domain/Models/User.swift 정의)
// ------------------------------------------------------------------------
public typealias UserProfile = User
