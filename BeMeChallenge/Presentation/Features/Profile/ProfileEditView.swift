//
//  Presentation/Features/Profile/ProfileEditView.swift
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: ProfileViewModel          // DI 받은 ViewModel

    // 입력값
    @State private var nickname = ""
    @State private var bio      = ""
    @State private var location = ""

    // 상태값
    @State private var isSaving = false
    @State private var alert: AlertItem?

    init(vm: ProfileViewModel) { self.vm = vm }

    // ───────────────────────────────────────── View
    var body: some View {
        Group {
            switch vm.profileState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let err):
                VStack(spacing: 16) {
                    Text("로딩 실패: \(err.localizedDescription)")
                        .multilineTextAlignment(.center)
                    Button("재시도") { vm.refresh() }
                }
                .padding()

            case .loaded:
                formBody                                   // ✅ iOS 기본 Form
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
                        .fontWeight(.bold)
                        .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if case .loaded(let p) = vm.profileState {
                nickname = p.nickname
                bio      = p.bio ?? ""
                location = p.location ?? ""
            }
        }
        .alert(item: $alert) { ai in
            Alert(title: Text(ai.title),
                  message: Text(ai.message),
                  dismissButton: .default(Text("확인")))
        }
    }

    // MARK: - Form
    @ViewBuilder
    private var formBody: some View {
        Form {
            // ── 닉네임 ─────────────────────────────
            Section(header: Text("닉네임")) {
                TextField("닉네임을 입력하세요", text: $nickname)
                    .textContentType(.nickname)
            }

            // ── 자기소개 ───────────────────────────
            Section(header: Text("자기소개")) {
                TextField("한 줄 자기소개", text: $bio)
                    .textContentType(.name)
            }

            // ── 위치 ───────────────────────────────
            Section(header: Text("위치")) {
                TextField("예: 서울, 강남", text: $location)
                    .textContentType(.addressCity)
            }

            // ── 사진 변경 ───────────────────────────
            Section {
                NavigationLink("프로필 사진 변경") {
                    ProfilePictureUpdateView(vm: vm)
                }
            }
        }
        .formStyle(.grouped)                // inset-grouped 스타일 유지
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 저장
    private func save() {
        isSaving = true
        Task {
            let res = await vm.updateProfile(
                nickname: nickname,
                bio:      bio.isEmpty      ? nil : bio,
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

struct AlertItem: Identifiable {
    let id = UUID(); let title: String; let message: String
}
