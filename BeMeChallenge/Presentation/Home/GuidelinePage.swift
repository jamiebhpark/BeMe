//
//  Presentation/Home/GuidelinePage.swift
//

import SwiftUI

struct GuidelinePage: View {
    @Binding var agreed: Bool

    var body: some View {
        ZStack {
            Image("onboarding_guideline")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()                              // ⬅️ 상단 비우기

                Text("커뮤니티 가이드라인")
                    .font(.title2).bold()

                VStack(alignment: .leading, spacing: 12) {
                    Label("폭력·성적·혐오 이미지 금지", systemImage: "hand.raised")
                    Label("타인 개인정보 무단 노출 금지", systemImage: "person.fill.viewfinder")
                    Label("광고·스팸·AI 합성 금지", systemImage: "nosign")
                    Label("챌린지 주제에 맞는 즉흥 사진 업로드", systemImage: "camera")
                    Label("외부 카메라만 사용 가능", systemImage: "camera")
                    Label("60초 이내 찍은 사진만 업로드 가능", systemImage: "camera")
                    Label("신고 10회 ⇒ 자동 삭제", systemImage: "exclamationmark.triangle")
                    Label("반복 위반 ⇒ 계정 정지", systemImage: "lock.slash")
                }
                .font(.subheadline)
                .padding(.horizontal, 24)             // ⬅️ 좌·우 24pt 여백

                Toggle("위 가이드라인을 모두 읽고 동의합니다.", isOn: $agreed)
                    .toggleStyle(CheckboxToggleStyle())
                    .padding(.horizontal, 24)

                Spacer(minLength: 60)                 // ⬅️ 하단 여백 (홈바 위)
            }
        }
    }
}
