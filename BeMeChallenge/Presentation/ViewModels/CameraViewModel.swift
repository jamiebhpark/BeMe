//
//  CameraViewModel.swift
//
import Foundation
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions   // ⬅️ 추가
import Combine
import UIKit

@MainActor                 // VM 전체를 Main-Actor 로 선언
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: – Published
    @Published var capturedImage: UIImage?
    @Published private(set) var uploadState: LoadableProgress = .idle

    // MARK: – Camera Session
    let session = AVCaptureSession()
    private let output  = AVCapturePhotoOutput()

    // MARK: – Private
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Session ▸ async 로 전환
    func configureSession() async throws {
        // 이미 구성되어 있으면 스킵
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw simpleErr("카메라를 찾을 수 없습니다")
        }
        let input = try AVCaptureDeviceInput(device: device)

        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw simpleErr("세션 구성 실패")
        }

        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        // startRunning 은 블로킹 → 백그라운드에서 실행
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                cont.resume()
            }
        }
    }

    func stopSession() { session.stopRunning() }

    // MARK: – Capture
    func capturePhoto() { output.capturePhoto(with: .init(), delegate: self) }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard   error == nil,
                let data  = photo.fileDataRepresentation(),
                let image = UIImage(data: data) else { return }
        Task { @MainActor in self.capturedImage = image }
    }
}

// MARK: - Upload
extension CameraViewModel {
    
    /// 캡션(선택)을 포함해 업로드를 시작
    func startUpload(
        forChallenge cid: String,
        caption: String?,                     // 🆕
        onDone: @escaping (Bool) -> Void
    ) {
        guard let img = capturedImage else { return }
        uploadState = .running(0)
        
        Task.detached { [weak self] in
            guard let self else { return }
            let result = await self.upload(
                image: img,
                challengeId: cid,
                caption: caption              // 🆕
            )
            await MainActor.run {
                switch result {
                case .success:
                    self.uploadState = .succeeded ; onDone(true)
                case .failure(let e):
                    self.uploadState = .failed(e) ; onDone(false)
                }
            }
        }
    }
    
    // MARK: async-await 업로드 핵심
    private func upload(
        image: UIImage,
        challengeId: String,
        caption: String?                     // 🆕
    ) async -> Result<Void,Error> {
        guard
            let uid  = Auth.auth().currentUser?.uid,
            let data = image.resized(maxPixel: 1024).jpegData(compressionQuality: 0.8)
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
                caption: caption
            )
            return .success(())
        } catch { return .failure(error) }
    }
    
    // 🟢 새로 추가
    /// Cloud Function(createPost) 호출로 포스트 저장
    private func addPostViaFunction(
        challengeId: String,
        imageURL: URL,
        caption: String?
    ) async throws {
        let data: [String: Any?] = [
            "challengeId": challengeId,
            "imageUrl":    imageURL.absoluteString,
            "caption":     (caption ?? NSNull())
        ]
        try await Functions.functions(region: "asia-northeast3")
            .httpsCallable("createPost")
            .call(data)
    }


    private func simpleErr(_ msg: String) -> NSError {
        NSError(domain: "CameraUpload", code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
