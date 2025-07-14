// Domain/Models/Challenge.swift
import Foundation
import FirebaseFirestore

public enum ChallengeType: String, Codable {
    case mandatory   // Firestore 값: "mandatory"
    case open        // Firestore 값: "open"

    /// 화면에 표시할 한글 / 로컬라이즈드 문자열
    var displayName: String {
        switch self {
        case .mandatory: return "필수"
        case .open:      return "오픈"
        }
    }
}

public struct Challenge: Identifiable, Codable {
    public var id: String
    public var title: String
    public var description: String
    public var participantsCount: Int
    public var createdAt: Date          // ✅
    public var endDate:   Date
    public var type: ChallengeType
    
    // 편의 계산 ------------------------------
    public var totalDuration: TimeInterval { endDate.timeIntervalSince(createdAt) }
    public var remaining:     TimeInterval { max(0, endDate.timeIntervalSinceNow) }
    public var isActive:      Bool { remaining > 0 }
    public var within7days:   Bool { !isActive && Date().timeIntervalSince(endDate) < 604_800 }
    
    // Firestore 초기화 -----------------------
    public init?(document: QueryDocumentSnapshot) {
        let d = document.data()
        guard
            let title   = d["title"]            as? String,
            let desc    = d["description"]      as? String,
            let count   = d["participantsCount"]as? Int,
            let create  = d["createdAt"]        as? Timestamp,
            let endTs   = d["endDate"]          as? Timestamp,
            let rawType = d["type"]             as? String,
            let type    = ChallengeType(rawValue: rawType)
        else { return nil }
        
        self.id = document.documentID
        self.title = title
        self.description = desc
        self.participantsCount = count
        self.createdAt = create.dateValue()
        self.endDate   = endTs.dateValue()
        self.type      = type
    }
}
