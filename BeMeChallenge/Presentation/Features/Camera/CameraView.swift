//
//  CameraView.swift
//
import SwiftUI
import AVFoundation

struct CameraView: View {
    let challengeId: String
    var  onFinish: () -> Void        // 찍고 업로드 끝나면 호출

    @StateObject private var cameraVM = CameraViewModel()
    @State private var showPhotoPreview = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CameraPreview(session: cameraVM.session)

            cancelButton
            shutterButton
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)

        // ✔️ 세션 구성 – MainActor 안에서 async 호출
        .task {
            do   { try await cameraVM.configureSession() }
            catch { print("Camera session error:", error) }
        }
        .onDisappear { cameraVM.stopSession() }

        .onChange(of: cameraVM.capturedImage) { _ in
            showPhotoPreview = cameraVM.capturedImage != nil
        }
        .fullScreenCover(isPresented: $showPhotoPreview) {
            PhotoPreviewView(
                cameraVM: cameraVM,
                challengeId: challengeId
            ) {
                dismiss()   // PhotoPreview 닫기
                onFinish()  // CameraCoordinator 닫기
            }
        }
    }

    // ───────── Sub UI
    private var cancelButton: some View {
        VStack {
            HStack {
                Button {
                    dismiss(); onFinish()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 50)
                Spacer()
            }
            Spacer()
        }
    }

    private var shutterButton: some View {
        VStack {
            Spacer()
            Button { cameraVM.capturePhoto() } label: {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
            }
            .padding(.bottom, 30)
        }
    }
}
