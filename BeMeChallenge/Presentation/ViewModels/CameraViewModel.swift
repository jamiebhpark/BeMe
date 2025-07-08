//
//  CameraViewModel.swift
//  BeMeChallenge
//

import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import FirebaseFunctions

// MARK: - ViewModel
final class CameraViewModel: NSObject, ObservableObject {

    // Published outputs
    @Published var capturedImage: UIImage?
    @Published private(set) var uploadState: LoadableProgress = .idle
    @Published var lastUploadedPostId: String?    // 🆕 SafeSearch 리스너용 postId

    // Camera
    let session = AVCaptureSession()
    private let output       = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")

    // MARK: Session
    func configureSession() async throws {
        guard !session.isRunning else { return }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    cont.resume(throwing: NSError(domain: "CameraUpload",
                                                  code: -1,
                                                  userInfo: [NSLocalizedDescriptionKey: "deinit"]))
                    return
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
                    self.session.startRunning()
                    cont.resume(returning: ())
                } catch { cont.resume(throwing: error) }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
    }

    func capturePhoto() { output.capturePhoto(with: .init(), delegate: self) }
}

// MARK: - AVCapturePhotoCaptureDelegate
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

// MARK: - Upload
extension CameraViewModel {

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

    private func upload(
        image: UIImage,
        challengeId: String,
        caption: String?,
        participationId: String?
    ) async -> Result<Void, Error> {

        guard
            let uid  = Auth.auth().currentUser?.uid,
            let data = image.resized(maxPixel: 1024).jpegData(compressionQuality: 0.8)
        else { return .failure(simpleErr("이미지 인코딩 실패")) }

        // 🎯 고유 ID (Firestore 문서와 파일 이름을 맞추기 위함)
        let fileId = UUID().uuidString

        let ref = Storage.storage()
            .reference()
            .child("user_uploads/\(uid)/\(challengeId)/\(fileId).jpg")

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(data, metadata: meta)
            await MainActor.run { self.uploadState = .running(1) }

            let url = try await ref.downloadURL()
            try await addPostViaFunction(
                postId:          fileId,
                challengeId:     challengeId,
                imageURL:        url,
                caption:         caption,
                participationId: participationId
            )
            // 🆕 Firestore 리스너용 postId 저장
            await MainActor.run { self.lastUploadedPostId = fileId }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // Cloud Function 호출
    private func addPostViaFunction(
        postId: String,
        challengeId: String,
        imageURL: URL,
        caption: String?,
        participationId: String?
    ) async throws {
        let payload: [String: Any?] = [
            "postId":          postId,
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

    // Helper
    fileprivate func simpleErr(_ msg: String) -> NSError {
        NSError(domain: "CameraUpload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: Concurrency
extension CameraViewModel: @unchecked Sendable {}
