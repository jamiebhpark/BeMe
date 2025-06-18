//
//  ModalCoordinator.swift
//  BeMeChallenge
//

import SwiftUI

/// 앱 전역 모달·알럿·토스트를 다루는 코디네이터
@MainActor
final class ModalCoordinator: ObservableObject {

    // MARK: – Published states
    @Published var modalAlert: ModalAlert? = nil      // 전역 알럿
    @Published var toast:      ToastItem?  = nil      // 전역 토스트

    // MARK: – Alert helpers
    func showAlert(_ alert: ModalAlert) {
        modalAlert = alert
    }
    func resetAlert() {
        modalAlert = nil
    }

    // MARK: – Toast helpers
    /// 감성적 미니멀 토스트 배너를 표시합니다.
    /// - Parameters:
    ///   - toast:  표시할 토스트 모델
    ///   - duration: 자동 사라짐까지 걸리는 시간 (초). 기본 2.5s
    func showToast(_ toast: ToastItem, duration: TimeInterval = 2.5) {
        withAnimation {
            self.toast = toast
        }
        // 일정 시간이 지나면 자동으로 사라짐
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation { self?.toast = nil }
        }
    }

    /// 수동으로 즉시 토스트를 닫습니다.
    func resetToast() {
        withAnimation { toast = nil }
    }
}

/// 앱에서 사용할 알럿 타입
enum ModalAlert: Identifiable {
    case manage(post: Post)          // “삭제/신고” 관리 메뉴
    case deleteConfirm(post: Post)   // 삭제 최종 확인
    case reportConfirm(post: Post)   // 신고 최종 확인

    var id: String {
        switch self {
        case .manage(let p):         return "manage-\(p.id)"
        case .deleteConfirm(let p):  return "delete-\(p.id)"
        case .reportConfirm(let p):  return "report-\(p.id)"
        }
    }
}

/// 간단한 상단 배너용 토스트 모델
struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
}
