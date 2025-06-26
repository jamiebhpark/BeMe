//
//  ChallengeIdeasListView.swift
//  BeMeChallenge
//
import SwiftUI

struct ChallengeIdeasListView: View {
    @StateObject private var vm = ChallengeIdeaViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    if !vm.popular.isEmpty {
                        SectionHeader(title: "🔥 인기 아이디어")
                        ForEach(vm.popular) { idea in IdeaRow(idea: idea, vm: vm) }
                    }
                    SectionHeader(title: "🆕 최신 아이디어")
                    ForEach(vm.latest) { idea in IdeaRow(idea: idea, vm: vm) }
                }
                .padding()
            }
            .navigationTitle("챌린지 제안")
            .onAppear { vm.start() }
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

private struct IdeaRow: View {
    let idea: ChallengeIdea
    @ObservedObject var vm: ChallengeIdeaViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.title)
                    .font(.headline)
                Text(idea.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { vm.toggleLike(idea) } label: {
                Label("\(idea.likeCount)", systemImage: "hand.thumbsup.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
}
