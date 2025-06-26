//
//  Presentation/Features/ChallengeIdea/ChallengeIdeaSubmitView.swift
//  BeMeChallenge
//

import SwiftUI

struct ChallengeIdeaSubmitView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: ChallengeIdeaViewModel

    @State private var title = ""
    @State private var desc  = ""
    @State private var isSubmitting = false
    @State private var alertMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                /* ─ 제목 ─────────────────────────────── */
                Section(header: Text("제목 (20자 이내)")) {
                    TextField("예) 1만원 점심 인증", text: $title)
                        .onChange(of: title) { _, newValue in
                            title = String(newValue.prefix(20))
                        }
                }

                /* ─ 설명 ─────────────────────────────── */
                Section(header: Text("설명 (140자)")) {
                    TextEditor(text: $desc)
                        .frame(height: 120)
                        .onChange(of: desc) { _, newValue in
                            desc = String(newValue.prefix(140))
                        }
                }
            }
            .navigationTitle("아이디어 제안")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("보내기") { submit() }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert("오류",
                   isPresented: Binding(
                       get: { alertMsg != nil },
                       set: { _ in alertMsg = nil })
            ) {
                Button("확인", role: .cancel) { }
            } message: { Text(alertMsg ?? "") }
        }
    }

    // MARK: – 제출
    private func submit() {
        isSubmitting = true
        Task {
            let result = await vm.submitIdea(title: title, desc: desc)
            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    alertMsg = error.localizedDescription
                }
            }
        }
    }
}
