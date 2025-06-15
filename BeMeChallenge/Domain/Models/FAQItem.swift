// FAQItem.swift
import Foundation
import SwiftUI

struct FAQItem: Identifiable {
  let id = UUID()
  let question: String
  let answer: String

  static let sampleData: [FAQItem] = [
    .init(question: "앱 사용에 문제가 발생하면 어떻게 해야 하나요?",
          answer: "문제가 발생하면 문의하기 버튼을 눌러 이메일로 문의해주세요."),
    .init(question: "내 정보는 안전하게 보호되나요?",
          answer: "네, 사용자의 모든 정보는 안전하게 보호되며, Firebase를 통해 관리됩니다."),
    .init(question: "챌린지 참여 방법은 무엇인가요?",
          answer: "소셜 로그인 후 챌린지 목록에서 원하는 챌린지를 선택하여 참여하세요.")
  ]
}
