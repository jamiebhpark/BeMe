//
//  PhotoPreviewView.swift
//  BeMeChallenge
//

import SwiftUI

struct PhotoPreviewView: View {
    // MARK: – Inputs
    @ObservedObject var cameraVM: CameraViewModel
    let challengeId:     String
    let participationId: String      // 🆕
    let onUploadSuccess: () -> Void

    // MARK: – Environment
    @Environment(\.dismiss)         private var dismiss
    @EnvironmentObject              private var modalC: ModalCoordinator

    // MARK: – Local state
    @State private var previewImage: UIImage?
    @State private var caption: String = ""

    /// 업로드 진행 중?
    private var isUploading: Bool {
        if case .running = cameraVM.uploadState { return true }
        return false
    }

    // ───────────────────────────────────────────── UI
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // 0) 타이틀
                TitleText(text: "사진 업로드")
                    .padding(.top, 8)

                // 1) 이미지 미리보기
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

                // 2) 캡션 입력
                TextField("사진 설명(선택, 80자 이내)",
                          text: $caption,
                          axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                    .disabled(isUploading)
                    .onChange(of: caption) { new in
                        caption = String(new.prefix(80))          // 길이 제한
                    }

                // 2-a) 문자 수
                HStack {
                    Spacer()
                    Text("\(caption.count)/80")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 28)
                }

                // 3) 업로드 진행률
                if case .running(let pct) = cameraVM.uploadState {
                    ProgressView(value: pct)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // 4) 버튼 영역
                HStack(spacing: 16) {
                    retryButton
                    uploadButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            // 네비게이션 바 ‘취소’ → 동일 취소 로직 재사용
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { cancelAndRollback() }
                }
            }
            .onAppear { previewImage = cameraVM.capturedImage }
        }
    }

    // MARK: – Buttons
    /// “다시 찍기” → participation 취소 & 뷰 닫기
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

    /// “지금 올리기”
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

    // MARK: – 공통 취소 처리
    /// 타임아웃·취소 버튼·다시 찍기 모두 이 로직 사용
    private func cancelAndRollback() {
        // 1) 버튼 잠금 해제
        NotificationCenter.default.post(
            name: .challengeTimeout,
            object: nil,
            userInfo: ["cid": challengeId]
        )

        // 2) 서버 participation 취소
        ChallengeService.shared.cancelParticipation(
            challengeId:     challengeId,
            participationId: participationId
        )

        // 3) 상태 초기화 & dismiss
        cameraVM.capturedImage = nil
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            modalC.showToast(ToastItem(message: "촬영을 취소했어요"))
        }
    }
}
