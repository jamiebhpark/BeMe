//
//  PhotoPreviewView.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseFirestore

struct PhotoPreviewView: View {
    // MARK: – Inputs
    @ObservedObject var cameraVM: CameraViewModel
    let challengeId:     String
    let participationId: String
    let onUploadSuccess: () -> Void

    // MARK: – Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modalC: ModalCoordinator

    // MARK: – Local state
    @State private var previewImage: UIImage?
    @State private var caption: String = ""
    @State private var listener: ListenerRegistration?

    /// 업로드 진행 중?
    private var isUploading: Bool {
        if case .running = cameraVM.uploadState { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TitleText(text: "사진 업로드")
                    .padding(.top, 8)

                if let img = previewImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 440)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                        .padding(.horizontal, 20)
                } else {
                    Text("사진이 없습니다.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                TextField("사진 설명(선택, 80자 이내)",
                          text: $caption,
                          axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                    .disabled(isUploading)
                    .onChange(of: caption) { _, newValue in
                        caption = String(newValue.prefix(80))
                    }

                HStack {
                    Spacer()
                    Text("\(caption.count)/80")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 28)
                }

                if case .running(let pct) = cameraVM.uploadState {
                    ProgressView(value: pct)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 40)
                }

                Spacer()

                HStack(spacing: 16) {
                    retryButton
                    uploadButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { cancelAndRollback() }
                }
            }
            .onAppear {
                previewImage = cameraVM.capturedImage
            }
            // 업로드 성공 시 리스너 시작
            .onReceive(cameraVM.$uploadState) { state in
                if case .succeeded = state,
                   let postId = cameraVM.lastUploadedPostId {
                    startListeningRejection(postId: postId)
                }
            }
            .onDisappear {
                listener?.remove()
            }
        }
    }

    // MARK: – Buttons
    private var retryButton: some View {
        Button { cancelAndRollback() } label: {
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
                    EmptyView()
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
            LinearGradient(
                colors: [
                    Color("PrimaryGradientStart"),
                    Color("PrimaryGradientEnd")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .disabled(isUploading)
    }

    // MARK: – Upload Handler
    private func startUpload() {
        guard previewImage != nil, caption.count <= 80 else { return }

        cameraVM.startUpload(
            forChallenge: challengeId,
            caption: caption.isEmpty ? nil : caption,
            participationId: participationId
        ) { success in
            DispatchQueue.main.async {
                if !success {
                    let msg: String
                    if case .failed(let err) = cameraVM.uploadState {
                        msg = err.localizedDescription
                    } else {
                        msg = "업로드 실패"
                    }
                    modalC.showToast(ToastItem(message: msg))
                    dismiss()
                }
                // 성공 시에는 최종 피드백만 리스너가 처리합니다.
            }
        }
    }

    // MARK: – Firestore 리스너
    private func startListeningRejection(postId: String) {
        listener = Firestore.firestore()
            .collection("challengePosts")
            .document(postId)
            .addSnapshotListener { snap, err in
                guard let data = snap?.data(), err == nil,
                      let rejected = data["rejected"] as? Bool
                else { return }

                let msg = rejected
                    ? "⛔️ 부적절한 이미지가 차단되었습니다"
                    : "✅ 업로드가 성공적으로 처리되었습니다"

                modalC.showToast(ToastItem(message: msg))
                listener?.remove()
                dismiss()
                onUploadSuccess()
            }
    }

    // MARK: – 공통 취소 처리
    private func cancelAndRollback() {
        NotificationCenter.default.post(
            name: .challengeTimeout,
            object: nil,
            userInfo: ["cid": challengeId]
        )
        ChallengeService.shared.cancelParticipation(
            challengeId:     challengeId,
            participationId: participationId
        )
        cameraVM.capturedImage = nil
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            modalC.showToast(ToastItem(message: "촬영을 취소했어요"))
        }
    }
}
