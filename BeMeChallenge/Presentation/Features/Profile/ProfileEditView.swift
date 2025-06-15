// Presentation/Features/Profile/ProfileEditView.swift
import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ProfileViewModel

    @State private var nickname: String = ""
    @State private var bio:      String = ""
    @State private var location: String = ""

    @State private var isSaving = false
    @State private var alert: AlertItem?

    init(vm: ProfileViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack {
            switch vm.profileState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxHeight: .infinity)

            case .failed(let err):
                VStack(spacing: 16) {
                    Text("로딩 실패: \(err.localizedDescription)")
                        .multilineTextAlignment(.center)
                    Button("재시도") {
                        vm.refresh()
                    }
                }
                .padding()

            case .loaded(let prof):
                form(prof)
            }
        }
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("저장", action: save)
                        .disabled(nickname.isEmpty)
                }
            }
        }
        .onAppear {
            if case .loaded(let prof) = vm.profileState {
                nickname = prof.nickname
                bio      = prof.bio ?? ""
                location = prof.location ?? ""
            }
        }
        .alert(item: $alert) { ai in
            Alert(
                title: Text(ai.title),
                message: Text(ai.message),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    @ViewBuilder
    private func form(_ prof: UserProfile) -> some View {
        Form {
            Section(header: Text("닉네임")) {
                TextField("닉네임", text: $nickname)
            }
            Section(header: Text("자기소개")) {
                TextField("자기소개", text: $bio)
            }
            Section(header: Text("위치")) {
                TextField("위치", text: $location)
            }
            Section {
                NavigationLink("프로필 사진 변경") {
                    // 파라미터 라벨을 vm: 으로 변경
                    ProfilePictureUpdateView(vm: vm)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let res = await vm.updateProfile(
                nickname: nickname,
                bio: bio.isEmpty ? nil : bio,
                location: location.isEmpty ? nil : location
            )
            DispatchQueue.main.async {
                isSaving = false
                switch res {
                case .success:
                    dismiss()
                case .failure(let e):
                    alert = AlertItem(title: "오류", message: e.localizedDescription)
                }
            }
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
