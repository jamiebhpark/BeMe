//  ActivityView.swift
//  BeMeChallenge
import SwiftUI
import UIKit

/// SwiftUI에서 UIKit의 UIActivityViewController를 래핑해서 띄우는 뷰
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
