//
//  UploadQueue.swift
//  BeMeChallenge
//

import Foundation
import BackgroundTasks
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions
import UIKit

// MARK: - 완료 브로드캐스트용 Notification
extension Notification.Name {
    static let uploadQueueDidFlush = Notification.Name("uploadQueueDidFlush")
    static let commentAdded = Notification.Name("commentAdded")
}

/// 실패한 업로드 정보를 담는 구조체
struct PendingUpload: Codable, Identifiable {
    let id: String
    let uid: String
    let cid: String
    let imgPath: String          // 앱 sandbox 내 이미지 파일
    let caption: String?
    var retry: Int = 0

    init(uid: String, cid: String, imgPath: String, caption: String?) {
        self.id      = UUID().uuidString
        self.uid     = uid
        self.cid     = cid
        self.imgPath = imgPath
        self.caption = caption
    }
}

// MARK: - 싱글톤 큐
@MainActor
final class UploadQueue: ObservableObject {
    static let shared = UploadQueue()

    @Published private(set) var items: [PendingUpload] = []
    private let storeKey = "PendingUploads"
    private let maxRetry = 5

    private init() {
        load()
        registerBGTask()
    }

    // MARK: - Public
    func enqueue(uid: String, cid: String, image: UIImage, caption: String?) {
        guard let data = image.pngData() else { return }
        let tmpURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(UUID().uuidString).png")
        try? data.write(to: tmpURL)

        items.append(PendingUpload(uid: uid, cid: cid, imgPath: tmpURL.path, caption: caption))
        save()
        scheduleBGTask()
    }
    func retryNow() { Task.detached { await self.processQueue() } }

    // MARK: - BG Task
    private func registerBGTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BGIdentifiers.uploadRetry, using: nil) { [weak self] task in
            Task.detached {
                await self?.processQueue()
                task.setTaskCompleted(success: true)
                await MainActor.run { self?.scheduleBGTask() }
            }
        }
    }
    private func scheduleBGTask() {
        guard !items.isEmpty else { return }
        let req = BGAppRefreshTaskRequest(identifier: BGIdentifiers.uploadRetry)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    // MARK: - Core
    private func processQueue() async {
        guard !items.isEmpty else { return }
        print("🔄 UploadQueue retry started, count:", items.count)

        var done: [String] = []

        for var item in items {
            guard let img = UIImage(contentsOfFile: item.imgPath) else { continue }
            do {
                try await upload(item: item, image: img)
                done.append(item.id)
                try? FileManager.default.removeItem(atPath: item.imgPath)
            } catch {
                print("upload retry err:", error.localizedDescription)
                item.retry += 1
                if item.retry >= maxRetry { done.append(item.id) }
            }
        }
        items.removeAll { done.contains($0.id) }
        save()

        if items.isEmpty {
            NotificationCenter.default.post(name: .uploadQueueDidFlush, object: nil)
        }
    }

    // MARK: - 실제 업로드
    private func upload(item: PendingUpload, image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw NSError() }

        let fileId = UUID().uuidString
        let ref = Storage.storage()
            .reference()
            .child("user_uploads/\(item.uid)/\(item.cid)/\(fileId).jpg")

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        // ① Storage 업로드 (경고 → _ 로 무시)
        _ = try await ref.putDataAsync(data, metadata: meta)

        // ② URL
        let url = try await ref.downloadURL()

        // ③ Cloud Function 호출 (경고 → _ 로 무시)
        let payload: [String: Any?] = [
            "postId":        fileId,
            "challengeId":   item.cid,
            "imageUrl":      url.absoluteString,
            "caption":       item.caption ?? NSNull()
        ]
        _ = try await Functions.functions(region: "asia-northeast3")
                .httpsCallable("createPost")
                .call(payload)
    }

    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let list = try? JSONDecoder().decode([PendingUpload].self, from: data)
        else { return }
        items = list
    }
}
