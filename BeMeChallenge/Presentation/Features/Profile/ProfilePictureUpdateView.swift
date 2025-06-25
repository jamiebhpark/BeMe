//
//  Presentation/Features/Profile/ProfilePictureUpdateView.swift
//

import SwiftUI

struct ProfilePictureUpdateView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var isPickerPresented = false
    @State private var isUploading      = false
    @State private var uploadError:     String?
    
    /// 현재 아바타 URL (캐시-버스터 포함)
    private var avatarURL: URL? {
        guard case .loaded(let prof) = vm.profileState else { return nil }
        return prof.effectiveProfileImageURL
    }
    
    // ────────────────────────────────────────────────── View
    var body: some View {
        VStack(spacing: 28) {
            
            // ① 썸네일
            avatarView
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .shadow(radius: 6)
            
            // ② 버튼 스택
            VStack(spacing: 16) {
                // 사진 선택
                Button {
                    isPickerPresented = true
                } label: {
                    Label("프로필 사진 선택", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientCapsule())
                
                // 기본 아바타
                Button(role: .destructive) {
                    isUploading = true
                    Task {
                        let res = await vm.resetProfilePicture()
                        await MainActor.run {
                            isUploading = false
                            switch res {
                            case .success: dismiss()
                            case .failure(let e): uploadError = e.localizedDescription
                            }
                        }
                    }
                } label: {
                    Label("기본 아바타로 되돌리기",
                          systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isUploading)
                
                // 업로드
                Button {
                    guard let img = selectedImage else { return }
                    upload(img)
                } label: {
                    if isUploading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("사진 업데이트", systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(GradientCapsule())
                .disabled(isUploading || selectedImage == nil)
            }
            .padding(.horizontal)
            
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
            Button("확인", role: .cancel) { }
        } message: {
            Text(uploadError ?? "")
        }
    }
    
    // 썸네일 뷰
    @ViewBuilder
    private var avatarView: some View {
        if let img = selectedImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else if let url = avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:   ProgressView()
                case .failure: Image("defaultAvatar").resizable()
                case .success(let img): img.resizable().scaledToFill()
                @unknown default: EmptyView()
                }
            }
        } else {
            Image("defaultAvatar").resizable()
        }
    }
    
    // 업로드 로직
    private func upload(_ image: UIImage) {
        isUploading = true
        vm.updateProfilePicture(image) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success: dismiss()
                case .failure(let err):
                    uploadError = err.localizedDescription
                }
            }
        }
    }
    
    // 공통 그라디언트 Capsule 버튼
    private struct GradientCapsule: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline.bold())
                .padding()
                .background(
                    LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
                .opacity(configuration.isPressed ? 0.85 : 1)
        }
    }
}
