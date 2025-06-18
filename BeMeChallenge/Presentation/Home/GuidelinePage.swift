//
//  Presentation/Home/GuidelinePage.swift
//

import SwiftUI

struct GuidelinePage: View {
    /// OnboardingView와 바인딩
    @Binding var agreed: Bool

    var body: some View {
        VStack(spacing: 24) {
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
            .frame(maxWidth: .infinity, alignment: .leading)

            // ✔️ 토글만 남기고 별도 버튼 제거
            Toggle("위 가이드라인을 모두 읽고 동의합니다.", isOn: $agreed)
                .toggleStyle(CheckboxToggleStyle())
                .padding(.top, 8)

            Spacer(minLength: 0)          // 페이지 하단 여백
        }
        .padding()
    }
}
// MARK: - 미리보기 ----------------------------------------------------------
struct GuidelinePage_Previews: PreviewProvider {
    @State static var agreed = false     // 프리뷰용 상태

    static var previews: some View {
        Group {
            GuidelinePage(agreed: $agreed)
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)

            GuidelinePage(agreed: $agreed)
                .previewDisplayName("Dark")
                .environment(\.colorScheme, .dark)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
