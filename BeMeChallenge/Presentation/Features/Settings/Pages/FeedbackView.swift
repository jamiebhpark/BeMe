//
//  Presentation/Features/Settings/Pages/FeedbackView.swift
//

import SwiftUI

struct FeedbackView: View {
    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.dismiss)         private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                SectionHeader(title: "피드백 보내기")

                // ───────── 입력창 ─────────
                TextEditor(text: $vm.message)
                    .frame(height: 200)
                    .padding(12)                              // 내부 패딩
                    .background(Color(.secondarySystemBackground))  // ✅ 주변 카드색
                    // ↳ 라이트: 연회색 · 다크: 짙은 회색 → 배경과 자연스러운 대비
                    .overlay(                                 // ✅ 섬세한 구분선
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("Lavender").opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(12)

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // 제출 버튼
                Button("제출하기", action: submit)
                    .buttonStyle(GradientCapsule())
                    .padding(.top, 8)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .hideKeyboardOnTap()
    }

    // 제출 핸들러
    private func submit() {
        vm.submitFeedback { success in
            modalC.showToast(
                ToastItem(message: success
                          ? "제출이 완료되었습니다!"
                          : (vm.errorMessage ?? "제출 실패"))
            )
            if success { dismiss() }
        }
    }
}

// 그라디언트 Capsule 버튼
private struct GradientCapsule: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// 키보드 숨기기 헬퍼
fileprivate extension View {
    func hideKeyboardOnTap() -> some View {
        onTapGesture {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
            #endif
        }
    }
}
