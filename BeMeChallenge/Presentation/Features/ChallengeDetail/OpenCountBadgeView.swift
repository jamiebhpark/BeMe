//
//  OpenCountBadgeView.swift
//  BeMeChallenge
//
import SwiftUI

struct OpenCountBadgeView: View {
    let count: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "medal.fill")
                .font(.footnote)
                .foregroundColor(.white)

            Text("\(count)")
                .font(.footnote.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.80, blue: 0.00),  // 골드
                    Color(red: 1.00, green: 0.55, blue: 0.00)   // 오렌지
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.2)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
        .accessibilityLabel(Text("\(count)회 참여"))
    }
}
