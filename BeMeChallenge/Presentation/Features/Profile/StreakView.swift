// Presentation/Features/Profile/StreakView.swift
import SwiftUI

struct StreakView: View {
    let totalParticipations: Int
    let streakDays: Int

    var body: some View {
        HStack {
            VStack {
                Text("총 참여")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(totalParticipations)회")
                    .font(.headline).bold()
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .padding(.horizontal)

            VStack {
                Text("연속 참여")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(streakDays)일")
                    .font(.headline).bold()
                    .foregroundColor(Color("PrimaryGradientStart"))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
