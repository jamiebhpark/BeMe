//
//  Presentation/Home/OnboardingView.swift
//

import SwiftUI

// MARK: - 데이터 모델
struct OnboardingPage: Identifiable {
    var id = UUID()
    var imageName: String
    var title: String
    var description: String
}

// MARK: - 온보딩 메인
struct OnboardingView: View {

    // ───────── 상태 ─────────
    @State private var currentPage = 0
    @State private var agreed      = false     // 가이드라인 동의

    // ───────── 인트로 페이지 정의 ─────────
    private let introPages: [OnboardingPage] = [
        .init(imageName: "onboarding1",
              title: "진정성 있는 순간",
              description: "광고 없는 순수한 일상을 공유합니다."),
        .init(imageName: "onboarding2",
              title: "즉석 촬영",
              description: "필터 없이, 있는 그대로의 당신을 기록하세요."),
        .init(imageName: "onboarding3",
              title: "특별한 챌린지",
              description: "참여해야만 볼 수 있는 특별한 챌린지에 도전하세요.")
    ]

    /// 총 페이지 = 인트로 + 가이드라인 1장
    private var pageCount: Int { introPages.count + 1 }

    // 🔑 버튼 공용 그라데이션
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color("PrimaryGradientStart"), Color("PrimaryGradientEnd")],
            startPoint: .leading, endPoint: .trailing)
    }

    // ───────── 본문 ─────────
    var body: some View {
        VStack {
            // ----- 페이지뷰 -----
            TabView(selection: $currentPage) {

                // ① 인트로 3장
                ForEach(0..<introPages.count, id: \.self) { idx in
                    OnboardingIntroPage(page: introPages[idx])
                        .tag(idx)
                }

                // ② 가이드라인 페이지
                GuidelinePage(agreed: $agreed)
                    .tag(pageCount - 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // ----- 하단 버튼 -----
            Button(action: advance) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    // ✅ ViewBuilder closure로 분기
                    .background {
                        if buttonEnabled {
                            gradient
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(!buttonEnabled)
            .padding(.vertical)
        }
        .background(Color("BackgroundPrimary").ignoresSafeArea())
        .onAppear(perform: redirectIfNeeded)
    }
}

// MARK: - 헬퍼 로직
private extension OnboardingView {

    var buttonEnabled: Bool {
        currentPage < pageCount - 1 ? true : agreed
    }

    var buttonTitle: String {
        currentPage < pageCount - 1 ? "다음" : "시작하기"
    }

    func advance() {
        if currentPage < pageCount - 1 {
            withAnimation { currentPage += 1 }
        } else {
            // 동의 플래그 저장 ➜ 메인 화면 전환
            UserDefaults.standard.set(true,  forKey: "hasSeenOnboarding")
            UserDefaults.standard.set(true,  forKey: "agreedGuideline")
            // 필요하다면 코디네이터 / 환경객체를 통해 홈으로 전환
        }
    }

    /// 이미 온보딩·동의 완료 시 바로 홈으로
    func redirectIfNeeded() {
        if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") &&
           UserDefaults.standard.bool(forKey: "agreedGuideline") {
            // 코디네이터를 통해 홈으로 전환
        }
    }
}

// MARK: - 인트로 단일 페이지 뷰
private struct OnboardingIntroPage: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 300)

            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundColor(Color("TextPrimary"))

            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(Color("TextPrimary"))
        }
    }
}
