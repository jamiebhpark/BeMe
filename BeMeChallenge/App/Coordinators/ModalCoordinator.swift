//
//  ModalCoordinator.swift
//  BeMeChallenge
//
//  Updated: 2025-07-10 – `static shared` 추가
//

import SwiftUI
import SafariServices

@MainActor
final class ModalCoordinator: ObservableObject {

    /// 전역에서 간편하게 접근하기 위한 싱글턴(옵셔널)
    static var shared: ModalCoordinator?          // ← ★ 추가

    // ───────── Published ─────────
    @Published var modalAlert:  ModalAlert? = nil
    @Published var toast:       ToastItem?  = nil
    @Published var webURL:      URL?        = nil
    @Published var markdownText: String?    = nil

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
    func presentWeb(_ url: URL)        { webURL = url }
    func dismissWeb()                  { webURL = nil }
    func presentMarkdown(_ md: String) { markdownText = md }
    func dismissMarkdown()             { markdownText = nil }
}

/* ------------ ModalAlert & ToastItem 그대로 ------------ */

enum ModalAlert: Identifiable {
    case manage(post: Post)
    case deleteConfirm(post: Post)
    case reportConfirm(post: Post)
    case blockConfirm(userId: String, userName: String)

    var id: String {
        switch self {
        case .manage(let p):            return "manage-\(p.id)"
        case .deleteConfirm(let p):     return "delete-\(p.id)"
        case .reportConfirm(let p):     return "report-\(p.id)"
        case .blockConfirm(let uid, _): return "block-\(uid)"
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
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) { }
}
