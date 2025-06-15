//
//  ChallengeService.swift
//  BeMeChallenge
//
import Foundation
import FirebaseFunctions
import os.log   // ⬅️ 간단 로그

final class ChallengeService: ObservableObject {
    static let shared = ChallengeService()
    private lazy var functions = Functions.functions(region: "asia-northeast3")

    /// Cloud Function – 챌린지 참여
    func participate(challengeId: String,
                     type: String,
                     completion: @escaping (Result<Void, Error>) -> Void) {

        let payload: [String: Any] = ["challengeId": challengeId,
                                      "type": type]   // "필수"/"오픈"

        functions.httpsCallable("participateChallenge").call(payload) { result, error in
            if let error = error {
                os_log("❌ participate error: %@", error.localizedDescription)
                completion(.failure(error))
                return
            }
            guard
                let dict = result?.data as? [String: Any],
                (dict["success"] as? Bool) == true
            else {
                completion(.failure(NSError(
                    domain: "App", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "알 수 없는 오류"]
                )))
                return
            }
            completion(.success(()))
        }
    }
}
