//
//  Presentation/Features/Profile/StreakView.swift
//

import SwiftUI

struct StreakView: View {
    let totalParticipations: Int
    let streakDays: Int

    var body: some View {
        HStack {

            // 총 참여
            VStack(spacing: 4) {
                Text("총 참여")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(totalParticipations)회")
                    .font(.headline.bold())
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 42)
                .padding(.horizontal)

            // 연속 참여
            VStack(spacing: 4) {
                Text("연속 참여")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(streakDays)일")
                    .font(.headline.bold())
                    .foregroundColor(Color("PrimaryGradientStart"))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
