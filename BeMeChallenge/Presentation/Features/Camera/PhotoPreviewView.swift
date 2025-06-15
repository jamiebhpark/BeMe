//
//  PhotoPreviewView.swift
//

import SwiftUI

struct PhotoPreviewView: View {
    @ObservedObject var cameraVM: CameraViewModel
    let challengeId: String
    let onUploadSuccess: () -> Void
    
    @Environment(\.dismiss)         private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator
    
    @State private var previewImage: UIImage?
    @State private var caption: String = ""          // 🆕 입력값
    
    // ▶️ 업로드 중인지 여부 계산
    private var isUploading: Bool {
        if case .running = cameraVM.uploadState { return true }
        return false
    }
    
    // ───────────────────────────────────────────── UI
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                // ── 미리보기 이미지 ───────────────────
                if let img = previewImage {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 440)
                        .cornerRadius(16).shadow(radius: 6)
                        .padding(.horizontal, 20)
                } else {
                    Text("사진이 없습니다.")
                        .font(.title3).foregroundColor(.secondary)
                }
                
                // ── 캡션 입력 ───────────────────────
                TextField("사진 설명(선택, 80자 이내)", text: $caption, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                    .disabled(isUploading)
                    .onChange(of: caption) { new in
                        caption = String(new.prefix(80))          // 길이 제한
                    }
                
                // 문자 수 표시
                HStack {
                    Spacer()
                    Text("\(caption.count)/80")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 28)
                }
                
                // ── 업로드 진행률 ───────────────────
                if case .running(let pct) = cameraVM.uploadState {
                    ProgressView(value: pct)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // ── 버튼 영역 ──────────────────────
                HStack(spacing: 16) {
                    retryButton
                    uploadButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("사진 업로드")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear { previewImage = cameraVM.capturedImage }
        }
    }
    
    // MARK: – Buttons
    private var retryButton: some View {
        Button {
            cameraVM.capturedImage = nil
            dismiss()
        } label: {
            Text("다시 찍기")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
    
    private var uploadButton: some View {
        Button { startUpload() } label: {
            Group {
                switch cameraVM.uploadState {
                case .running:
                    EmptyView()          // 상단 ProgressView로 충분
                case .succeeded:
                    Image(systemName: "checkmark")
                        .font(.title3).bold()
                default:
                    Text("지금 올리기").bold()
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(
            LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(Capsule())
        .disabled(isUploading)
    }
    
    // MARK: – Upload Handler
    private func startUpload() {
        guard previewImage != nil, caption.count <= 80 else { return }
        cameraVM.startUpload(forChallenge: challengeId,
                             caption: caption.isEmpty ? nil : caption) { success in
            DispatchQueue.main.async {
                if success {
                    modalC.showToast(ToastItem(message: "업로드 완료"))
                    onUploadSuccess()
                } else {
                    let msg: String
                    if case .failed(let err) = cameraVM.uploadState {
                        msg = err.localizedDescription
                    } else {
                        msg = "업로드 실패"
                    }
                    modalC.showToast(ToastItem(message: msg))
                }
            }
        }
    }
}
