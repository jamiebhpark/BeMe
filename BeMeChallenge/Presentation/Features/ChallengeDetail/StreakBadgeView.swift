// StreakBadgeView.swift  ➞ 기존 파일 전체 교체

import SwiftUI

struct StreakBadgeView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {                   // 🔸 간격 +2pt
            Image(systemName: "flame.fill")
                .font(.footnote)                // (約 13 pt)
                .foregroundColor(.white)       // 아이콘도 white → 배경과 대비

            Text("\(count)")
                .font(.footnote.bold())         // 숫자 크기 동일, 굵기 유지
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)              // 🔸 좌우 +4pt
        .padding(.vertical,   8)               // 🔸 상하 +2pt (전체 약 20 % 커짐)
        .background(
            LinearGradient(                    // 🟥 레드 ↔ 오렌지 톤
                colors: [
                    Color(red: 0.95, green: 0.26, blue: 0.21),   // #F24136
                    Color(red: 1.00, green: 0.55, blue: 0.00)    // #FF8C00
                ],
                startPoint: .leading,
                endPoint:   .trailing
            )
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.2) // 1.2pt outline
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
        .accessibilityLabel(Text("\(count)일 연속 참여 중"))
    }
}
