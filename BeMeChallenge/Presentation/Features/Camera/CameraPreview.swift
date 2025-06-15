//  CameraPreview.swift
import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession

    // 내부에서 사용할 UIView subclass (layer 클래스가 AVCaptureVideoPreviewLayer로 대체됨)
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    // UIView 생성: VideoPreviewView를 만들고, 세션을 연결합니다.
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    // 업데이트 로직(필요하다면 구현, 지금은 기본 상태 유지)
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 세션이 변경될 경우 업데이트할 코드를 추가할 수 있습니다.
    }
}
