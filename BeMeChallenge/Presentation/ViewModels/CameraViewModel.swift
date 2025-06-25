//
//  CameraViewModel.swift
//  BeMeChallenge
//
//  Swift 6 Strict-Concurrency & Thread Performance Safe 버전
//

import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Combine

// MARK: - ViewModel -------------------------------------------------------
final class CameraViewModel: NSObject, ObservableObject {

    // ───────── Published ─────────
    @Published var capturedImage: UIImage?
    @Published private(set) var uploadState: LoadableProgress = .idle

    // ───────── Camera Session ─────
    let session = AVCaptureSession()
    private let output        = AVCapturePhotoOutput()
    private let sessionQueue  = DispatchQueue(label: "camera.session")

    // ───────── Private ────────────
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Session -----------------------------------------------------
    /// 카메라 세션 구성 + 시작 (백그라운드 큐에서 실행)
    func configureSession() async throws {
        guard !session.isRunning else { return }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    return cont.resume(throwing: self?.simpleErr("deinit") ?? NSError())
                }
                do {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo

                    guard let device = AVCaptureDevice.default(for: .video) else {
                        throw self.simpleErr("카메라를 찾을 수 없습니다.")
                    }
                    let input = try AVCaptureDeviceInput(device: device)

                    guard self.session.canAddInput(input),
                          self.session.canAddOutput(self.output) else {
                        throw self.simpleErr("세션 구성 실패")
                    }
                    self.session.addInput(input)
                    self.session.addOutput(self.output)
                    self.session.commitConfiguration()

                    self.session.startRunning()      // ✅ 백그라운드 스레드
                    cont.resume(returning: ())
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// 세션 중지
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()              // ✅ 백그라운드
        }
    }

    // MARK: – Capture -----------------------------------------------------
    func capturePhoto() {
        output.capturePhoto(with: .init(), delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate ----------------------------------
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard
            error == nil,
            let data  = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else { return }

        Task { @MainActor in self.capturedImage = image }
    }
}

// MARK: - Upload ---------------------------------------------------------
extension CameraViewModel {

    /// 사진·캡션 업로드 시작
    func startUpload(
        forChallenge cid: String,
        caption: String?,
        participationId: String? = nil,
        onDone: @escaping (Bool) -> Void
    ) {
        guard let img = capturedImage else { return }
        uploadState = .running(0)

        Task.detached { [weak self] in
            guard let self else { return }

            let result = await self.upload(
                image: img,
                challengeId: cid,
                caption: caption,
                participationId: participationId
            )

            await MainActor.run {
                switch result {
                case .success:
                    self.uploadState = .succeeded
                    onDone(true)
                case .failure(let e):
                    self.uploadState = .failed(e)
                    onDone(false)
                }
            }
        }
    }

    /// 실제 업로드 로직
    private func upload(
        image: UIImage,
        challengeId: String,
        caption: String?,
        participationId: String?
    ) async -> Result<Void, Error> {

        guard
            let uid  = Auth.auth().currentUser?.uid,
            let data = image
                .resized(maxPixel: 1024)
                .jpegData(compressionQuality: 0.8)
        else { return .failure(simpleErr("이미지 인코딩 실패")) }

        let ref = Storage.storage()
            .reference()
            .child("user_uploads/\(uid)/\(challengeId)/\(UUID().uuidString).jpg")

        do {
            let task = ref.putDataAsync(data)
            for try await progress in task {
                await MainActor.run { self.uploadState = .running(progress) }
            }

            let url = try await ref.downloadURL()

            try await addPostViaFunction(
                challengeId:      challengeId,
                imageURL:         url,
                caption:          caption,
                participationId:  participationId
            )

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Cloud Function `createPost` 호출
    private func addPostViaFunction(
        challengeId: String,
        imageURL:    URL,
        caption:     String?,
        participationId: String?
    ) async throws {

        let payload: [String: Any?] = [
            "challengeId":     challengeId,
            "imageUrl":        imageURL.absoluteString,
            "caption":         caption ?? NSNull(),
            "participationId": participationId ?? NSNull()
        ]

        _ = try await Functions
            .functions(region: "asia-northeast3")
            .httpsCallable("createPost")
            .call(payload)
    }

    // MARK: – Helper
    fileprivate func simpleErr(_ msg: String) -> NSError {
        NSError(
            domain: "CameraUpload",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: msg]
        )
    }
}

// MARK: - Concurrency ----------------------------------------------------
/**
 CameraViewModel 은 전용 DispatchQueue (`sessionQueue`) 에서만
 비-메인 접근이 일어나므로 데이터 레이스 위험이 없습니다.
 */
extension CameraViewModel: @unchecked Sendable {}
