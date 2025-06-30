//  ChallengeIdeasListView.swift
//

import SwiftUI
import FirebaseAuth

struct ChallengeIdeasListView: View {
    @StateObject private var vm = ChallengeIdeaViewModel()

    var body: some View {
        NavigationStack {
            List {
                // 🔥 인기
                if !vm.popular.isEmpty {
                    Section {
                        ForEach(vm.popular) { idea in
                            IdeaRow(idea: idea, vm: vm)
                        }
                    } header: {
                        SectionHeader(title: "🔥 인기 아이디어")
                    }
                }

                // 🆕 최신
                Section {
                    ForEach(vm.latest) { idea in
                        IdeaRow(idea: idea, vm: vm)
                    }
                } header: {
                    SectionHeader(title: "🆕 최신 아이디어")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("챌린지 제안")
            .onAppear { vm.start() }
            // 우측 상단 ‘＋’ 만 남김
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.showSubmit = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $vm.showSubmit) {
                ChallengeIdeaSubmitView(vm: vm)
            }
        }
    }
}

/* ——— 개별 행 ——————————————————————————— */
private struct IdeaRow: View {
    let idea: ChallengeIdea
    @ObservedObject var vm: ChallengeIdeaViewModel

    private var isOwner: Bool {
        idea.ownerId == Auth.auth().currentUser?.uid
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 제목 + 설명
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.title).font(.headline)
                Text(idea.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            // 좋아요
            Button { vm.toggleLike(idea) } label: {
                Label("\(idea.likeCount)",
                      systemImage: "hand.thumbsup.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())            // 셀 전체가 터치영역
        // — 스와이프 삭제 (내 제안일 때만) —
        .swipeActions(edge: .trailing) {
            if isOwner {
                Button(role: .destructive) {
                    vm.archive(idea)
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
    }
}
