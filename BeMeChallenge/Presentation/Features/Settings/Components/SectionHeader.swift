// Presentation/Features/Settings/Components/SectionHeader.swift
import SwiftUI

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}
