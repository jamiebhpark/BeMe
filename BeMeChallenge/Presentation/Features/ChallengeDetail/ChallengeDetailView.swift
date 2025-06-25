//
//  Presentation/Features/ChallengeDetail/ChallengeDetailView.swift
//  BeMeChallenge
//

import SwiftUI

struct ChallengeDetailView: View {
    let challengeId: String

    @StateObject private var vm = ChallengeDetailViewModel()

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // ① 세그먼트 ─────────────────────────
            Picker("", selection: $vm.scope) {            // <-- vm.scope 로 바인딩
                ForEach(FeedScope.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color("Lavender"))
            .padding(.horizontal)
            // 🔻 onChange 블록 통째로 제거 (바인딩으로 자동 반응)
            // .onChange(of: scope) { … }

            // ② 본문 ────────────────────────────
            switch vm.postsState {
            case .idle, .loading:
                ProgressView().frame(maxHeight: .infinity)

            case .failed(let err):
                VStack(spacing: 12) {
                    Text("로드 실패: \(err.localizedDescription)")
                    Button("재시도") {
                        Task { await vm.loadInitial(challengeId: challengeId) } // scope 인자 삭제
                    }
                }
                .frame(maxHeight: .infinity)

            case .loaded:
                FeedView(vm: vm)        // <-- scope 파라미터 삭제
            }
        }
        // ── NavBar ------------------------------
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Label("뒤로", systemImage: "chevron.left")
                }
                .tint(Color("Lavender"))
            }
        }
        // ── 최초 진입 ----------------------------
        .task { await vm.loadInitial(challengeId: challengeId) }  // scope 인자 삭제
        .alert(item: $modalC.modalAlert, content: makeAlert)
    }
    
    // MARK: - Alert Builder -----------------------------------------------
    private func makeAlert(for alert: ModalAlert) -> Alert {
        switch alert {
            
        case .manage(let post):
            return Alert(
                title: Text("게시물 관리"),
                message: Text("이 게시물에 대해 어떤 작업을 하시겠습니까?"),
                primaryButton: .destructive(Text("삭제")) {
                    DispatchQueue.main.async {               // ✅ 추가
                        modalC.showAlert(.deleteConfirm(post: post))
                    }
                },
                secondaryButton: .default(Text("신고")) {
                    DispatchQueue.main.async {               // ✅ 추가
                        modalC.showAlert(.reportConfirm(post: post))
                    }
                }
            )
            
            // ── 2단계: 삭제 확인 ─────────────────────────────────────
        case .deleteConfirm(let post):
            return Alert(
                title: Text("삭제 확인"),
                message: Text("정말 이 게시물을 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("삭제")) {
                    DispatchQueue.main.async {           // 🚿 경고 방지
                        vm.deletePost(post)
                        modalC.resetAlert()
                        modalC.showToast(.init(message: "삭제 완료"))
                    }
                },
                secondaryButton: .cancel {
                    modalC.resetAlert()
                }
            )
            
            // ── 2단계: 신고 확인 ─────────────────────────────────────
        case .reportConfirm(let post):
            return Alert(
                title: Text("신고 확인"),
                message: Text("이 게시물을 신고하시겠습니까?"),
                primaryButton: .destructive(Text("신고")) {
                    DispatchQueue.main.async {           // 🚿 경고 방지
                        vm.report(post)
                        modalC.resetAlert()
                        modalC.showToast(.init(message: "신고 접수"))
                    }
                },
                secondaryButton: .cancel {
                    modalC.resetAlert()
                }
            )
        }
    }
}
