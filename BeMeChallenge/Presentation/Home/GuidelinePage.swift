//
//  GuidelinePage.swift
//  BeMeChallenge
//
import SwiftUI

struct GuidelinePage: View {
    /// OnboardingView에서 바인딩
    @Binding var agreed: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("커뮤니티 가이드라인")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 12) {
                Label("폭력·성적·혐오 이미지 금지", systemImage: "hand.raised")
                Label("타인 개인정보 무단 노출 금지", systemImage: "person.fill.viewfinder")
                Label("광고·스팸·AI 합성 금지", systemImage: "megaphone.slash")
                Label("챌린지 주제에 맞는 즉흥 사진 업로드", systemImage: "camera")
                Label("신고 10회 ⇒ 자동 삭제", systemImage: "exclamationmark.triangle")
                Label("반복 위반 ⇒ 계정 정지", systemImage: "lock.slash")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("위 가이드라인을 모두 읽고 동의합니다.", isOn: $agreed)
                .toggleStyle(CheckboxToggleStyle())   // ✅ iOS 호환
                .padding(.top, 8)

            Button("동의하고 시작하기") {
                agreed = true          // 단순 상태 변경–실제 완료는 OnboardingView에서
            }
            .disabled(!agreed)
            .frame(maxWidth: .infinity)
            .padding()
            .background(agreed ? Color.blue : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}
