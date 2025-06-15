// Presentation/Features/Profile/ProfilePictureUpdateView.swift

import SwiftUI

struct ProfilePictureUpdateView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var isPickerPresented = false
    @State private var isUploading      = false
    @State private var uploadError: String?

    // Loadable<UserProfile>에서 꺼내기
    /// 프로필 아바타 URL (캐시‐버스터 포함)
    private var avatarURL: URL? {
        guard case .loaded(let prof) = vm.profileState else { return nil }
        return prof.effectiveProfileImageURL        // ← 한 줄로 끝
    }


    var body: some View {
        VStack(spacing: 24) {
            // ── 썸네일
            Group {
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else if let url = avatarURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .failure:
                            Image("defaultAvatar")
                                .resizable()
                        case .success(let img):
                            img.resizable().scaledToFill()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image("defaultAvatar")
                        .resizable()
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .shadow(radius: 4)

            // ── 버튼
            VStack(spacing: 16) {
                Button("프로필 사진 선택") {
                    isPickerPresented = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                Button("기본 아바타로 되돌리기") {
                    vm.resetProfilePicture()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                Button("사진 업데이트") {
                    guard let img = selectedImage else { return }
                    upload(img)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }

            if isUploading {
                ProgressView("업로드 중…")
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("프로필 사진 변경")
        .sheet(isPresented: $isPickerPresented) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("업로드 오류",
               isPresented: Binding(get: { uploadError != nil },
                                    set: { _ in uploadError = nil })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(uploadError ?? "")
        }
    }

    private func upload(_ image: UIImage) {
        isUploading = true
        vm.updateProfilePicture(image) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let err):
                    uploadError = err.localizedDescription
                }
            }
        }
    }
}
