//
//  ChallengeCardView.swift
//  BeMeChallenge
//

import SwiftUI
import Combine
import FirebaseFunctions

struct ChallengeCardView: View {
    
    // MARK: - Props
    let challenge: Challenge
    @ObservedObject var viewModel: ChallengeViewModel
    
    @EnvironmentObject private var camC:   CameraCoordinator
    @EnvironmentObject private var modalC: ModalCoordinator
    
    // MARK: - Local state
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isSending   = false
    @State private var showSpinner = false
    
    // MARK: - Derived
    private var alreadyToday: Bool {
        challenge.type == .mandatory &&
        viewModel.todayParticipations.contains(challenge.id)
    }
    private var isDisabled: Bool   { alreadyToday || isSending || !challenge.isActive }
    
    // ─── Progress & Countdown ─────────────────────────────
    private var progress: Double {
        guard challenge.totalDuration > 0 else { return 1 }
        return 1 - min(1, challenge.remaining / challenge.totalDuration)
    }
    private var timeLeftLabel: String {
        if !challenge.isActive { return "종료" }
        let fmt = DateComponentsFormatter()
        fmt.allowedUnits = challenge.remaining < 86_400 ? [.hour, .minute]
                                                          : [.day,  .hour]
        fmt.unitsStyle   = .abbreviated
        return fmt.string(from: challenge.remaining) ?? ""
    }
    private var progressColor: Color {
        challenge.remaining < 86_400 ? .red : Color("Lavender")
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 0) 카운트다운 + 게이지
            ProgressView(value: progress)
                .tint(progressColor)
            HStack {
                Text("남은 시간 \(timeLeftLabel)")
                    .font(.caption2).bold()
                    .foregroundColor(progressColor)
                Spacer()
            }
            
            // 1) 타입 뱃지
            Text(challenge.type.rawValue)
                .font(.caption2).bold()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(typeBadgeBackground)
                .overlay(typeBadgeStroke)
                .foregroundColor(typeBadgeForeground)
                .clipShape(Capsule())
            
            // 2) 상세 (탭 → 디테일)
            NavigationLink {
                ChallengeDetailView(challengeId: challenge.id)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title).font(.headline)
                    Text(challenge.description).font(.subheadline)
                        .lineLimit(2)
                    HStack {
                        Text("참여자 \(challenge.participantsCount)")
                        Spacer()
                        Text(challenge.endDate, formatter: DateFormatter.shortDate)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // 3) 참여 버튼
            Button(action: joinChallenge) {
                ZStack {
                    Text(buttonTitle)
                        .fontWeight(.bold)
                        .opacity(showSpinner ? 0 : 1)
                    if showSpinner {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonBackground)
                .foregroundColor(buttonForeground)
                .cornerRadius(10)
            }
            .disabled(isDisabled)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 4)
    }
    
    // MARK: - Button helpers
    private var buttonTitle: String {
        if !challenge.isActive { return "종료됨" }
        if alreadyToday       { return "오늘 이미 참여함" }
        return challenge.type == .mandatory ? "오늘 참여하기" : "참여하기"
    }
    private var buttonBackground: some View {
        Group {
            if isDisabled {
                Color.gray.opacity(0.3)
            } else {
                LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
    }
    private var buttonForeground: Color { isDisabled ? .gray : .white }
    
    // MARK: - Badge style helpers
    private var typeBadgeBackground: some View {
        challenge.type == .mandatory ?
            AnyView(LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                                   startPoint: .leading, endPoint: .trailing))
            : AnyView(Color.clear)
    }
    private var typeBadgeStroke: some View {
        Capsule()
            .stroke(Color("Lavender"), lineWidth: challenge.type == .open ? 1 : 0)
    }
    private var typeBadgeForeground: Color {
        challenge.type == .mandatory ? .white : Color("Lavender")
    }
    
    // MARK: - Participate action
    private func joinChallenge() {
        guard !isDisabled else { return }
        isSending = true; showSpinner = true
        
        viewModel.participate(in: challenge)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isSending = false; showSpinner = false
                if case .failure(let err) = completion {
                    modalC.showToast(.init(message: err.localizedDescription))
                }
            } receiveValue: { _ in
                camC.presentCamera(for: challenge.id)
            }
            .store(in: &cancellables)
    }
}

// 날짜 포맷터
extension DateFormatter {
    static var shortDate: DateFormatter {
        let f = DateFormatter(); f.dateStyle = .short; return f
    }
}
