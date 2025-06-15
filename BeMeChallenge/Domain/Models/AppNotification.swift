// Domain/Models/AppNotification.swift
import Foundation
import FirebaseFirestore

struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var title: String
    var message: String
    var createdAt: Date
    var read: Bool
}
