//
//  UserRepository.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore

/// 유저 관련 Firestore 접근용 인터페이스
public protocol UserRepositoryProtocol {
    /// 단일 유저 조회 (콜백 기반)
    func fetchUser(withId id: String,
                   completion: @escaping (Result<User, Error>) -> Void)

    /// 복수 유저 조회 (콜백 기반)
    func fetchUsers(withIds ids: [String],
                    completion: @escaping (Result<[User], Error>) -> Void)

    /// 단일 유저 조회 (async/await)
    func getUser(id: String) async throws -> User

    /// 복수 유저 조회 (async/await)
    func getUsers(ids: [String]) async throws -> [User]
}

public final class UserRepository: UserRepositoryProtocol {

    // Firestore 인스턴스 (의존성 주입 용이하도록 let db 노출)
    private let db: Firestore

    public init(db: Firestore = .firestore()) { self.db = db }

    // =====================================================================
    // MARK: 콜백 기반
    // =====================================================================
    public func fetchUser(withId id: String,
                          completion: @escaping (Result<User, Error>) -> Void) {

        db.collection("users").document(id).getDocument { snap, err in
            if let err { completion(.failure(err)); return }

            guard let user = snap.flatMap(User.init(document:)) else {
                completion(.failure(self.simpleErr("사용자 정보를 불러올 수 없습니다.")))
                return
            }
            completion(.success(user))
        }
    }

    public func fetchUsers(withIds ids: [String],
                           completion: @escaping (Result<[User], Error>) -> Void) {

        guard !ids.isEmpty else { completion(.success([])); return }

        // Firestore where-in 은 10개 제한이므로 chunk 처리
        let chunks = ids.chunked(into: 10)
        var result: [User] = []
        var firstError: Error?

        let group = DispatchGroup()

        for chunk in chunks {
            group.enter()
            db.collection("users")
              .whereField(FieldPath.documentID(), in: chunk)
              .getDocuments { snap, err in
                  defer { group.leave() }
                  if let err {
                      firstError = err; return
                  }
                  let users = snap?.documents.compactMap(User.init(document:)) ?? []
                  result.append(contentsOf: users)
              }
        }

        group.notify(queue: .main) {
            if let err = firstError { completion(.failure(err)) }
            else { completion(.success(result)) }
        }
    }

    // =====================================================================
    // MARK: async/await 편의 메서드
    // =====================================================================
    public func getUser(id: String) async throws -> User {
        let snap = try await db.collection("users").document(id).getDocument()
        guard let user = User(document: snap) else {
            throw simpleErr("사용자 정보를 불러올 수 없습니다.")
        }
        return user
    }

    public func getUsers(ids: [String]) async throws -> [User] {
        guard !ids.isEmpty else { return [] }

        var aggregated: [User] = []
        for chunk in ids.chunked(into: 10) {    // where-in 10개 제한
            let snap = try await db.collection("users")
                                   .whereField(FieldPath.documentID(), in: chunk)
                                   .getDocuments()
            aggregated += snap.documents.compactMap(User.init(document:))
        }
        return aggregated
    }

    // =====================================================================
    // MARK: Helper
    // =====================================================================
    private func simpleErr(_ msg: String) -> NSError {
        .init(domain: "UserRepository", code: -1,
              userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - Array chunking helper
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
