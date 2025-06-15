// App/Coordinators/ModalCoordinator.swift
import SwiftUI

/// 앱 전역 모달·알럿·토스트를 다루는 코디네이터
final class ModalCoordinator: ObservableObject {
    
    /// 현재 표시해야 할 알럿
    @Published var modalAlert: ModalAlert? = nil
    
    /// 현재 표시해야 할 토스트
    @Published var toast: ToastItem? = nil
    
    // MARK: - Public helpers
    
    /// 알럿 표시
    func showAlert(_ alert: ModalAlert) {
        modalAlert = alert
    }
    
    /// 토스트 표시
    func showToast(_ toast: ToastItem) {
        self.toast = toast
    }
    
    /// 알럿 초기화
    func resetAlert() {
        modalAlert = nil
    }
    
    /// 토스트 초기화
    func resetToast() {
        toast = nil
    }
}

/// 앱에서 사용할 알럿 타입
enum ModalAlert: Identifiable {
    case manage(post: Post)          // “삭제/신고” 관리 메뉴
    case deleteConfirm(post: Post)   // 삭제 최종 확인
    case reportConfirm(post: Post)   // 신고 최종 확인

    var id: String {
        switch self {
        case .manage(let p):         return "manage-\(p.id)"        // 🔸 ! 삭제
        case .deleteConfirm(let p):  return "delete-\(p.id)"        // 🔸
        case .reportConfirm(let p):  return "report-\(p.id)"        // 🔸
        }
    }
}


/// 간단한 상단 배너
struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
}
