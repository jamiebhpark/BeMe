//
//  Presentation/Features/Settings/Pages/HelpFAQView.swift
//

import SwiftUI

struct HelpFAQView: View {

    @State private var showContact = false
    let faqs: [FAQItem]

    // 기본 목차 주입
    init(faqs: [FAQItem] = FAQItem.sampleData) { self.faqs = faqs }

    var body: some View {
        List {

            // ── FAQ ──────────────────────────────────────────
            Section(header: Text("도움말 & FAQ")
                        .foregroundColor(Color("TextPrimary"))) {

                ForEach(faqs) { item in
                    DisclosureGroup {
                        Text(item.answer)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } label: {
                        Text(item.question)
                            .font(.subheadline.bold())
                    }
                    .padding(.vertical, 4)
                }
            }

            // ── 문의하기 ─────────────────────────────────────
            Section {
                Button("문의하기") { showContact = true }
                    .buttonStyle(GradientCapsule())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showContact) { ContactSupportView() }
        .navigationTitle("도움말")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 공통 Capsule 버튼
private struct GradientCapsule: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
