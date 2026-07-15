//
//  MockCameraCaptureService.swift
//  LastPlace
//
//  Deterministic capture service for previews and unit tests. Returns a solid
//  colored 1×1 JPEG on shutter and renders a placeholder swatch in place of the
//  live preview so previews still lay out correctly.
//

import SwiftUI
import UIKit

@MainActor
final class MockCameraCaptureService: CameraCaptureService {
    private let capturedImage: UIImage

    init(capturedImage: UIImage? = nil) {
        self.capturedImage = capturedImage ?? MockCameraCaptureService.defaultPlaceholder
    }

    func prepare() async throws {}
    func start() async {}
    func stop() async {}
    func setTorch(on: Bool) async {}

    func capturePhoto() async throws -> Data {
        guard let data = capturedImage.jpegData(compressionQuality: 0.8) else {
            throw CameraError.captureFailed(underlying: "Placeholder image had no JPEG data")
        }
        return data
    }

    func makePreviewView() -> AnyView {
        AnyView(
            ZStack {
                LinearGradient(
                    colors: [Color(.systemGray4), Color(.systemGray2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        )
    }

    static var defaultPlaceholder: UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128))
        return renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        }
    }
}
