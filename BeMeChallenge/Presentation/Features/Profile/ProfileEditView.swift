//
//  Presentation/Features/Profile/ProfileEditView.swift
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ProfileViewModel          // ✨ DI 그대로

    // 입력값
    @State private var nickname = ""
    @State private var bio      = ""
    @State private var location = ""

    // 상태값
    @State private var isSaving = false
    @State private var alert: AlertItem?

    init(vm: ProfileViewModel) { _vm = StateObject(wrappedValue: vm) }

    // ───────────────────────────────────────────────────────── View
    var body: some View {
        VStack {
            switch vm.profileState {

            // 로딩
            case .idle, .loading:
                ProgressView().frame(maxHeight: .infinity)

            // 실패
            case .failed(let err):
                VStack(spacing: 16) {
                    Text("로딩 실패: \(err.localizedDescription)")
                        .multilineTextAlignment(.center)
                    Button("재시도") { vm.refresh() }
                }
                .padding()

            // 성공
            case .loaded(let profile):
                editForm(profile)
        } }
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)

        // 저장 버튼
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("저장", action: save)
                        .fontWeight(.bold)
                        .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }

        // 최초 진입 시 값 세팅
        .onAppear {
            if case .loaded(let p) = vm.profileState {
                nickname = p.nickname
                bio      = p.bio ?? ""
                location = p.location ?? ""
            }
        }

        // Alert
        .alert(item: $alert) { ai in
            Alert(title: Text(ai.title), message: Text(ai.message), dismissButton: .default(Text("확인")))
        }
    }

    // ─────────────────────────────────────────────── Form 영역
    @ViewBuilder
    private func editForm(_ prof: UserProfile) -> some View {
        Form {
            Section(header: Text("닉네임").foregroundColor(Color("TextPrimary"))) {
                TextField("닉네임", text: $nickname)
            }

            Section(header: Text("자기소개").foregroundColor(Color("TextPrimary"))) {
                TextField("자기소개", text: $bio)
            }

            Section(header: Text("위치").foregroundColor(Color("TextPrimary"))) {
                TextField("위치", text: $location)
            }

            Section {
                NavigationLink("프로필 사진 변경") {
                    ProfilePictureUpdateView(vm: vm)
                }
            }
        }
        .scrollContentBackground(.hidden)          // iOS 16+
        .background(Color("BackgroundPrimary"))
    }

    // ─────────────────────────────────────────────── 저장 로직
    private func save() {
        isSaving = true
        Task {
            let res = await vm.updateProfile(
                nickname: nickname,
                bio: bio.isEmpty ? nil : bio,
                location: location.isEmpty ? nil : location
            )
            await MainActor.run {
                isSaving = false
                switch res {
                case .success: dismiss()
                case .failure(let e):
                    alert = AlertItem(title: "오류", message: e.localizedDescription)
                }
            }
        }
    }
}

// Alert 식별용
struct AlertItem: Identifiable {
    let id = UUID(); let title: String; let message: String
}
