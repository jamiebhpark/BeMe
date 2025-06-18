//
//  CameraViewModel.swift
//  BeMeChallenge
//

import Foundation
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Combine
import UIKit

@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published
    @Published var capturedImage: UIImage?
    @Published private(set) var uploadState: LoadableProgress = .idle

    // MARK: - Camera Session
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    // MARK: - Private
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Session
    func configureSession() async throws {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(for: .video)
        else { throw simpleErr("카메라를 찾을 수 없습니다") }

        let input = try AVCaptureDeviceInput(device: device)

        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw simpleErr("세션 구성 실패")
        }

        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                cont.resume()
            }
        }
    }

    func stopSession() { session.stopRunning() }

    // MARK: - Capture
    func capturePhoto() {
        output.capturePhoto(with: .init(), delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard
            error == nil,
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else { return }

        Task { @MainActor in self.capturedImage = image }
    }
}

// MARK: - Upload
extension CameraViewModel {

    /// 사진‧캡션 업로드 시작
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

    // 실제 업로드 로직
    private func upload(
        image: UIImage,
        challengeId: String,
        caption: String?,
        participationId: String?
    ) async -> Result<Void, Error> {

        guard
            let uid = Auth.auth().currentUser?.uid,
            let data = image
                .resized(maxPixel: 1024)
                .jpegData(compressionQuality: 0.8)
        else { return .failure(simpleErr("인코딩 실패")) }

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
                challengeId: challengeId,
                imageURL: url,
                caption: caption,
                participationId: participationId
            )

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Cloud Function `createPost` 호출
    private func addPostViaFunction(
        challengeId: String,
        imageURL: URL,
        caption: String?,
        participationId: String?
    ) async throws {

        let payload: [String: Any?] = [
            "challengeId":      challengeId,
            "imageUrl":         imageURL.absoluteString,
            "caption":          caption ?? NSNull(),
            "participationId":  participationId ?? NSNull()
        ]

        try await Functions.functions(region: "asia-northeast3")
            .httpsCallable("createPost")
            .call(payload)
    }

    // MARK: - Helper
    private func simpleErr(_ msg: String) -> NSError {
        NSError(domain: "CameraUpload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
