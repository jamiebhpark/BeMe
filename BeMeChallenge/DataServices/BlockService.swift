// BlockService.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class BlockService {
    static let shared = BlockService()
    private let db = Firestore.firestore()

    /// userId 를 차단 목록에 추가
    func block(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let me = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "BlockService", code: -1)))
            return
        }
        let ref = db.collection("users/\(me)/blockedUsers").document(userId)
        ref.setData(["blockedAt": FieldValue.serverTimestamp()]) { err in
            if let e = err { completion(.failure(e)) }
            else         { completion(.success(())) }
        }
    }

    /// userId 를 차단 해제
    func unblock(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let me = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "BlockService", code: -1)))
            return
        }
        let ref = db.collection("users/\(me)/blockedUsers").document(userId)
        ref.delete { err in
            if let e = err { completion(.failure(e)) }
            else         { completion(.success(())) }
        }
    }
}
