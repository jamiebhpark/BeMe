// Presentation/Features/Settings/Pages/FeedbackView.swift
import SwiftUI

struct FeedbackView: View {
    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.dismiss)       private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator
    
    var body: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "피드백 보내기")
            
            TextEditor(text: $vm.message)
                .frame(height: 180)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            
            if let err = vm.errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
            }
            
            Spacer()
            
            Button("제출하기", action: submit)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("PrimaryGradientEnd"))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .hideKeyboardOnTap()
    }
    
    private func submit() {
        vm.submitFeedback { success in
            // show(_:) 대신 showToast(_:) 사용
            modalC.showToast(
                ToastItem(message: success
                          ? "제출이 완료되었습니다!"
                          : (vm.errorMessage ?? "제출 실패"))
            )
            if success { dismiss() }
        }
    }
}

// 편의: 탭 시 키보드 숨기기
fileprivate extension View {
    func hideKeyboardOnTap() -> some View {
        onTapGesture {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            #endif
        }
    }
}
