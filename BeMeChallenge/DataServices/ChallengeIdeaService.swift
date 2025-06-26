//
//  ChallengeIdeaService.swift
//  BeMeChallenge
//

import FirebaseAuth
import FirebaseFirestore

final class ChallengeIdeaService {
    static let shared = ChallengeIdeaService()
    private init() { }

    private let db = Firestore.firestore()

    // MARK: – 리스너 (최근 N개)
    func listenRecent(limit: Int = 100,
                      handler: @escaping ([ChallengeIdea]) -> Void)
    -> ListenerRegistration {

        db.collection("challengeIdeas")
          .whereField("isArchived", isEqualTo: false)
          .order(by: "createdAt", descending: true)
          .limit(to: limit)
          .addSnapshotListener { snap, _ in
              let ideas = snap?.documents.compactMap {
                  try? $0.data(as: ChallengeIdea.self)
              } ?? []
              handler(ideas)
          }
    }

    // MARK: – 제안 업로드
    @discardableResult
    func submitIdea(title: String,
                    desc: String) async -> Result<Void, Error> {

        guard let uid = Auth.auth().currentUser?.uid else {
            return .failure(simpleErr("로그인이 필요합니다"))
        }

        let idea = ChallengeIdea(
            title:      title,
            description: desc,
            ownerId:    uid,
            createdAt:  Timestamp(date: .now)
        )

        do {
            _ = try db.collection("challengeIdeas").addDocument(from: idea)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // MARK: – 좋아요 토글
    func toggleLike(for idea: ChallengeIdea,
                    completion: ((ChallengeIdea) -> Void)? = nil)
    {
        guard
            let uid   = Auth.auth().currentUser?.uid,
            let docId = idea.id
        else { return }

        let ref = db.collection("challengeIdeas").document(docId)

        db.runTransaction({ txn, errPtr -> Any? in
            do {
                // 현재 스냅샷
                guard var snap = try txn.getDocument(ref).data() else { return nil }

                var users = snap["likeUsers"] as? [String] ?? []
                var count = snap["likeCount"] as? Int     ?? 0

                if users.contains(uid) {
                    users.removeAll { $0 == uid }
                    count = max(count - 1, 0)
                } else {
                    users.append(uid)
                    count += 1
                }

                // 원격 문서 업데이트
                txn.updateData([
                    "likeUsers": users,
                    "likeCount": count
                ], forDocument: ref)

                // 변동 값을 로컬 dict 에 반영 → 디코딩
                snap["likeUsers"] = users
                snap["likeCount"] = count
                return try? Firestore.Decoder().decode(ChallengeIdea.self, from: snap)

            } catch let e as NSError {           // 🔸 throw → NSError 로 변환
                errPtr?.pointee = e
                return nil
            }
        }) { obj, _ in
            if let idea = obj as? ChallengeIdea { completion?(idea) }
        }
    }

    // MARK: – 아카이브(작성자 삭제)
    func archiveIdea(_ idea: ChallengeIdea) {
        guard
            let id  = idea.id,
            let uid = Auth.auth().currentUser?.uid,
            uid == idea.ownerId
        else { return }

        db.collection("challengeIdeas")
          .document(id)
          .updateData(["isArchived": true])
    }

    // MARK: – 하루 1건 제안 체크
    func todaysIdeaExists() async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let start = Calendar.current.startOfDay(for: .now)
        let snap = try await db.collection("challengeIdeas")
            .whereField("ownerId", isEqualTo: uid)
            .whereField("createdAt", isGreaterThan: Timestamp(date: start))
            .getDocuments()
        return !snap.documents.isEmpty
    }

    // MARK: – Helper
    private func simpleErr(_ msg: String) -> NSError {
        .init(domain: "Idea",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
