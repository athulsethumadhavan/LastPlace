//
//  MockObjectDetectionService.swift
//  LastPlace
//
//  Deterministic detector used by previews and unit tests. Returns a small
//  fixed list of high-confidence detections instead of running Vision.
//

import Foundation
import CoreGraphics

struct MockObjectDetectionService: ObjectDetectionService {
    var stubbed: [DetectedObject]

    init(stubbed: [DetectedObject] = MockObjectDetectionService.defaultStub) {
        self.stubbed = stubbed
    }

    func detect(in imageData: Data, minimumConfidence: Double) async throws -> [DetectedObject] {
        stubbed
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
    }

    static let defaultStub: [DetectedObject] = [
        DetectedObject(
            label: "Laptop",
            confidence: 0.92,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
        ),
        DetectedObject(
            label: "Coffee Mug",
            confidence: 0.71,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
        ),
        DetectedObject(
            label: "Notebook",
            confidence: 0.55,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
    ]
}
