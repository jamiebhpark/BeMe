//
//  MarkdownSheet.swift
//  BeMeChallenge
//

import SwiftUI

/// 로컬 Markdown 텍스트를 표시하는 간단한 시트
struct MarkdownSheet: View {
    let text: String

    // 앱 전역 코디네이터 주입
    @EnvironmentObject private var modalC: ModalCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                // SwiftUI 4+ Markdown 자동 렌더링
                Text(LocalizedStringKey(text))
                    .padding()
            }
            .navigationTitle("문서")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { modalC.dismissMarkdown() }
                }
            }
        }
    }
}
