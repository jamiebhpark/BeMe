// ContactSupportView.swift
import SwiftUI
import MessageUI

struct ContactSupportView: View {
    @State private var showMail = false
    @State private var mailError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("지원이 필요하신가요? 이메일로 언제든지 문의해주세요.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if MFMailComposeViewController.canSendMail() {
                        showMail = true
                    } else {
                        mailError = true
                    }
                }) {
                    Label("이메일 보내기", systemImage: "envelope.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("PrimaryGradientEnd"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
        .sheet(isPresented: $showMail) {
            MailView(result: .constant(nil))
        }
        .alert("메일 전송 실패", isPresented: $mailError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 기기에서 이메일을 보낼 수 없습니다.")
        }
    }
}

// MARK: - MFMailComposeController Wrapper

struct MailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var result: Result<MFMailComposeResult, Error>?

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentationMode: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentationMode: Binding<PresentationMode>,
             result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentationMode = presentationMode
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer { presentationMode.dismiss() }
            if let error = error {
                self.result = .failure(error)
            } else {
                self.result = .success(result)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(presentationMode: presentationMode, result: $result)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(["support@bemechallenge.com"])
        vc.setSubject("[BeMe Challenge] 지원 요청")
        vc.setMessageBody("안녕하세요,\n\n문의 내용을 작성해주세요.", isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
