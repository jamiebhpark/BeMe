//HelpFAQView.swift
import SwiftUI

struct HelpFAQView: View {
    @State private var showContact = false
    let faqs: [FAQItem]
    
    init(faqs: [FAQItem] = FAQItem.sampleData) {
        self.faqs = faqs
    }
    
    var body: some View {
        List {
            // FAQ 섹션
            Section(header: Text("도움말 & FAQ")) {
                ForEach(faqs) { item in
                    DisclosureGroup(item.question) {
                        Text(item.answer)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 문의하기 섹션
            Section {
                Button(action: { showContact = true }) {
                    // 문의하기 액션 (ContactSupportView로 네비)
                    Text("문의하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("PrimaryGradientEnd"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .listRowBackground(Color.clear) // 버튼만 돋보이도록 배경 제거
            }
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(isPresented: $showContact) {
            ContactSupportView()
        }
    }
}
