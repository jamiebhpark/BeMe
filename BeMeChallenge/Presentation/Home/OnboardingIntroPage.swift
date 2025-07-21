//
//  OnboardingIntroPage.swift
//  BeMeChallenge
//

import SwiftUI

struct OnboardingIntroPage: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 32)
                .padding(.bottom, 40)  // 홈 인디케이터 여유
        }
        // 이 뷰 자체는 safe-area 내에서만 동작하게 두겠습니다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
