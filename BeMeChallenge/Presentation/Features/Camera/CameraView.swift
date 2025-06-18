//
//  CameraView.swift
//  BeMeChallenge
//

import SwiftUI
import AVFoundation

struct CameraView: View {

    // ────────────────────────────── 1) 외부 입력
    let challengeId:     String
    let participationId: String
    var  onFinish:       () -> Void          // 상위 뷰 콜백

    // ────────────────────────────── 2) 내부 상태
    @StateObject private var cameraVM = CameraViewModel()
    @State       private var didTimeout = false          // ✅ 추가

    // ⏱ 60-second timer
    private let timerDuration: TimeInterval = 60
    @State private var timeLeft : TimeInterval = 60
    @State private var timer    : Timer?      = nil

    // UI 제어
    @State private var showPhotoPreview = false
    @Environment(\.dismiss)      private var dismiss
    @EnvironmentObject           private var modalC: ModalCoordinator

    // ────────────────────────────── 3) UI
    var body: some View {
        ZStack {
            CameraPreview(session: cameraVM.session)

            // 남은 시간 링
            ProgressRingView(progress: timeLeft / timerDuration)
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)

            cancelButton
            shutterButton
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)

        // 세션 구성 & 타이머 시작
        .task {
            do {
                try await cameraVM.configureSession()
                startTimer()
            } catch {
                print("Camera session error:", error)
            }
        }

        // 뷰가 사라질 때 – 사진 미촬영 상태라면 취소
        .onDisappear {
            cameraVM.stopSession()
            if cameraVM.capturedImage == nil && !didTimeout {
                timeout()                     // ✅ 중복 방지
            }
            stopTimer()
        }

        // 사진 촬영 → 미리보기
        .onChange(of: cameraVM.capturedImage) { _, _ in        // oldValue, newValue 무시
            showPhotoPreview = cameraVM.capturedImage != nil
        }
        .fullScreenCover(isPresented: $showPhotoPreview) {
            PhotoPreviewView(
                cameraVM:       cameraVM,
                challengeId:    challengeId,
                participationId: participationId
            ) {
                dismiss()
                onFinish()
            }
        }
    }

    // ────────────────────────────── 4) 서브 컴포넌트
    private var cancelButton: some View {
        VStack {
            HStack {
                Button { timeout() } label: {
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
            Button {
                stopTimer()
                cameraVM.capturePhoto()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
            }
            .padding(.bottom, 30)
            .disabled(timeLeft == 0)
        }
    }

    // ────────────────────────────── 5) 타이머 헬퍼
    private func startTimer() {
        timeLeft = timerDuration
        stopTimer()                                   // 중복 방지
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeLeft -= 1
            if timeLeft <= 0 { timeout() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // ────────────────────────────── 6) 공통 종료 처리
    private func timeout() {
        guard !didTimeout else { return }
        didTimeout = true
        stopTimer()

        // ① 로컬 롤백 & 서버 취소
        NotificationCenter.default.post(
            name: .challengeTimeout, object: nil, userInfo: ["cid": challengeId]
        )
        ChallengeService.shared.cancelParticipation(
            challengeId: challengeId, participationId: participationId
        )

        // ② 먼저 닫는다
        dismiss()
        onFinish()

        // ③ 0.15s 뒤 토스트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            modalC.showToast(ToastItem(message: "⏱ 시간이 초과되었습니다! 다시 시도해 주세요."))
        }
    }
}
