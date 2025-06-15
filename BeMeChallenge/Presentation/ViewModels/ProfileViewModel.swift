//
//  ProfileViewModel.swift
//  BeMeChallenge
//
//  개선 사항
//  1. 로그아웃 시 Firestore 리스너 해제, 재로그인 시 재구독
//  2. profileListener · postsListener 분리
//  3. 공개/비공개 필드 제거 + 단순 디코딩
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
            .sink { [weak self] _ in self?.stopListeners() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didSignIn)
            .sink { [weak self] _ in self?.startListeners() }
            .store(in: &cancellables)
    }

    // MARK: Listener 관리 ---------------------------------------------------
    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // ── 프로필 -------------------------------------
        profileState = .loading
        profileListener = db.document("users/\(uid)")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                
                // ① 파이어스토어 에러
                if let err = err {
                    self.profileState = .failed(err)
                    return
                }
                
                // (A) 문서 없음
                guard var data = snap?.data() else {
                    self.db.document("users/\(uid)")
                        .setData(["nickname": "익명"], merge: true)
                    return
                }
                
                // (B) nickname 없음
                if data["nickname"] == nil {
                    self.db.document("users/\(uid)")
                        .setData(["nickname": "익명"], merge: true)
                    return
                }
                
                // (C) 디코딩
                if let user = User(document: snap!) {
                    self.profileState = .loaded(user)
                } else {
                    self.profileState = .failed(
                        self.simpleErr("프로필 디코딩 실패")
                    )
                }
            }
        
        // ── 내 포스트 ----------------------------------
        postsListener = db.collection("challengePosts")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, _ in
                self?.userPosts = snap?.documents
                    .compactMap(Post.init(document:))
                ?? []
            }
    }


    private func stopListeners() {
        profileListener?.remove(); profileListener = nil
        postsListener?.remove();   postsListener   = nil
        profileState = .idle
        userPosts.removeAll()
    }
    func refresh() { stopListeners(); startListeners() }

    // MARK: 프로필 정보 업데이트 --------------------------------------------
    func updateProfile(nickname: String,
                       bio: String?,
                       location: String?) async -> Result<Void, Error> {

        guard let uid = Auth.auth().currentUser?.uid else {
            return .failure(simpleErr("로그인이 필요합니다"))
        }
        do {
            try await db.collection("users").document(uid).updateData([
                "nickname": nickname,
                "bio": bio as Any,
                "location": location as Any
            ])
            return .success(())
        } catch { return .failure(error) }
    }

    // MARK: 프로필 사진 -------------------------------
    func updateProfilePicture(_ image: UIImage,
                              completion: @escaping (Result<Void, Error>) -> Void) {

        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(simpleErr("로그인이 필요합니다"))); return }

        guard let data = image.resized(maxPixel: 1024)
                              .jpegData(compressionQuality: 0.8) else {
            completion(.failure(simpleErr("이미지 인코딩 실패"))); return }

        let ref = storage.reference().child("profile_images/\(uid).jpg")
        ref.putData(data, metadata: nil) { [weak self] _, err in
            if let err = err {                       // ✅ 명시적 바인딩
                completion(.failure(err)); return
            }
            ref.downloadURL { url, err in
                if let err = err {
                    completion(.failure(err)); return
                }
                guard let url else { return }
                self?.db.collection("users").document(uid).updateData([
                    "profileImageURL": url.absoluteString,
                    "profileImageUpdatedAt": FieldValue.serverTimestamp()
                ]) { err in
                    if let err = err { completion(.failure(err)) }
                    else            { completion(.success(()))   }
                }
            }
        }
    }

    func resetProfilePicture() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData([
            "profileImageURL": FieldValue.delete(),
            "profileImageUpdatedAt": FieldValue.delete()
        ])
    }

    // MARK: 게시물 관리 -----------------------------------------------------
    func deletePost(_ post: Post) {
        db.collection("challengePosts")
          .document(post.id)                      // ← 바로 사용
          .delete()
    }

    func reportPost(_ post: Post) {
        ReportService.shared
            .reportPost(postId: post.id) { _ in } // ← 바로 사용
    }

    // MARK: Helper
    private func simpleErr(_ msg: String) -> NSError {
        .init(domain: "Profile", code: -1,
              userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// ------------------------------------------------------------------------
// UserProfile = User  (타입 별칭, 모델은 Domain/Models/User.swift 정의)
// ------------------------------------------------------------------------
public typealias UserProfile = User
