//
//  ChallengeIdeaSection.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseAuth

struct ChallengeIdeaSection<Dest: View>: View {
    private let destination: () -> Dest
    @StateObject private var vm = ChallengeIdeaViewModel()

    // ❌  init(destination: …)  →  ✅  init(_ destination: …)
    init(@ViewBuilder _ destination: @escaping () -> Dest) {
        self.destination = destination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // 헤더 + ‘＋’ 버튼
            HStack {
                Text("📣 챌린지 제안")
                    .font(.headline)
                Spacer()
                Button { vm.showSubmit = true } label: {
                    Image(systemName: "plus")
                }
            }

            // 🔥 인기
            if !vm.popular.isEmpty {
                Text("🔥 인기 아이디어").font(.subheadline.bold())
                ideaList(vm.popular)
            }

            // 🆕 최신
            Text("🆕 최신 아이디어").font(.subheadline.bold())
                .padding(.top, vm.popular.isEmpty ? 0 : 8)
            ideaList(vm.latest)

            // 전체 보기
            NavigationLink("전체 보기", destination: destination)
                .font(.footnote.bold())
                .padding(.top, 4)
        }
        .padding()
        .cardStyle()
        .onAppear { vm.start() }
        .sheet(isPresented: $vm.showSubmit) {
            ChallengeIdeaSubmitView(vm: vm)
        }
    }

    @ViewBuilder
    private func ideaList(_ data: [ChallengeIdea]) -> some View {
        ForEach(data) { idea in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.title).font(.footnote.bold())
                    Text(idea.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 8)
                Button { vm.toggleLike(idea) } label: {
                    Image(systemName: "hand.thumbsup")
                    Text("\(idea.likeCount)")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 6)
            .swipeActions {
                if idea.ownerId == Auth.auth().currentUser?.uid {
                    Button(role: .destructive) { vm.archive(idea) } label: {
                        Label("내리기", systemImage: "trash")
                    }
                }
            }
        }
    }
}
