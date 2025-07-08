//
//  ModalCoordinator.swift
//  BeMeChallenge
//

import SwiftUI
import SafariServices

/// 앱 전역 모달·알럿·토스트·문서 뷰를 관리
@MainActor
final class ModalCoordinator: ObservableObject {

    // ── Published ─────────────────────────────────
    @Published var modalAlert:  ModalAlert? = nil
    @Published var toast:       ToastItem?  = nil
    @Published var webURL:      URL?        = nil      // 외부 링크 (SafariSheet)
    @Published var markdownText: String?    = nil      // 로컬 MD 문서

    // ── Alert helpers ────────────────────────────
    func showAlert(_ alert: ModalAlert) { modalAlert = alert }
    func resetAlert() { modalAlert = nil }

    // ── Toast helpers ────────────────────────────
    func showToast(_ toast: ToastItem, duration: TimeInterval = 2.5) {
        withAnimation { self.toast = toast }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation { self?.toast = nil }
        }
    }
    func resetToast() { withAnimation { toast = nil } }

    // ── Web / Markdown ───────────────────────────
    func presentWeb(_ url: URL)          { webURL = url }
    func dismissWeb()                    { webURL = nil }

    func presentMarkdown(_ md: String)   { markdownText = md }
    func dismissMarkdown()               { markdownText = nil }
}

/* ---------- ModalAlert & ToastItem ---------- */
enum ModalAlert: Identifiable {
    case manage(post: Post)
    case deleteConfirm(post: Post)
    case reportConfirm(post: Post)

    var id: String {
        switch self {
        case .manage(let p):        return "manage-\(p.id)"
        case .deleteConfirm(let p): return "delete-\(p.id)"
        case .reportConfirm(let p): return "report-\(p.id)"
        }
    }
}

struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
}

/* ---------- SafariView (http/https 전용) ---------- */
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
