//
//  FeedScope.swift
//  BeMeChallenge
//
/// ChallengeDetailView ― 세그먼트 타입
///
import Foundation

public enum FeedScope: String, CaseIterable, Identifiable, Codable {
    case all  = "전체"
    case mine = "내 게시물"
    // ☑️ 후속 탭(스폰서/친구) 추가 가능
    public var id: Self { self }
}
