//
//  OnboardingIntroPage.swift
//  BeMeChallenge
//
import SwiftUI

// MARK: - 인트로 단일 페이지 뷰
struct OnboardingIntroPage: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            // ── 배경
            Image(page.imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // ── 텍스트(하단 정렬)
            VStack(spacing: 24) {
                Spacer()                       // 상단을 비워 전체 배경 노출

                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundColor(Color("TextPrimary"))

                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("TextPrimary"))
            }
            .padding(.horizontal, 24)          // 좌 · 우 여백
            .padding(.bottom, 100)             // 홈바 위 여백 (원하면 값 조정)
            
        }
    }
}
