// Core/Utils/Storage+Async.swift
import Foundation
import FirebaseStorage

extension StorageReference {
    /// 진행률(0 … 1)을 AsyncStream 으로 방출
    func putDataAsync(_ data: Data)
        -> AsyncThrowingStream<Double,Error> {
        .init { continuation in
            let task = putData(data, metadata: nil) { _, err in
                if let err { continuation.finish(throwing: err) }
                else      { continuation.finish() }
            }
            let obs = task.observe(.progress) { snapshot in
                let pct = Double(snapshot.progress?.fractionCompleted ?? 0)
                continuation.yield(pct)
            }
            continuation.onTermination = { _ in task.removeObserver(withHandle: obs) }
        }
    }
}
