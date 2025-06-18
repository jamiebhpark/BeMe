//
//  ChallengeService.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFunctions
import os.log

/// Cloud Function 래퍼
final class ChallengeService {
    static let shared = ChallengeService()
    private let fn = Functions.functions(region: "asia-northeast3")

    // MARK: – 참여 요청  ▶︎  participationId 반환
    func participate(
        challengeId: String,
        type: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let body: [String: Any] = ["challengeId": challengeId, "type": type]

        fn.httpsCallable("participateChallenge").call(body) { res, err in
            // ────────────────────────────────────────────────────── ▼ add
            if let e = err as NSError? {
                print("❌ participate error ▶︎ code:", e.code,
                      "domain:", e.domain,
                      "msg:", e.localizedDescription)
                // 필요하다면 e.userInfo 도 출력해 두세요.
                completion(.failure(e))
                return
            }
            // ────────────────────────────────────────────────────── ▲

            guard
                let dict = res?.data as? [String: Any],
                (dict["success"] as? Bool) == true,
                let pid  = dict["participationId"] as? String
            else {
                completion(.failure(NSError(
                    domain: "App", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "서버 응답 오류"]
                )))
                return
            }
            completion(.success(pid))
        }
    }


    // MARK: – 참여 취소 (타임아웃·수동)
    func cancelParticipation(
        challengeId: String,
        participationId: String
    ) {
        let body: [String: Any] = [
            "challengeId":     challengeId,
            "participationId": participationId
        ]
        fn.httpsCallable("cancelParticipation").call(body) { _, err in
            if let err {
                os_log("⚠️ cancelParticipation: %@", err.localizedDescription)
            }
        }
    }
}
