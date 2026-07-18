//
//  ScanReviewView.swift
//  LastPlace
//
//  Reviews every capture in the current scan session. Each capture shows its
//  photo plus the object detections we surfaced from Vision; tapping a
//  detection routes to the save-item screen. Swipe-actions handle delete /
//  retake per capture.
//

import SwiftUI

struct ScanReviewView: View {
    @Bindable var coordinator: ScanCoordinator
    let homeCoordinator: HomeCoordinator

    @State private var isConfirmingDiscard = false

    var body: some View {
        Group {
            if coordinator.captures.isEmpty {
                EmptyStateView(
                    title: "Nothing to review",
                    message: "Capture at least one photo before reviewing.",
                    symbolName: "camera",
                    primaryAction: EmptyStateAction(title: "Back to camera") {
                        coordinator.goToCapture()
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(coordinator.captures) { capture in
                            captureCard(capture)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Review scan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Discard scan?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                coordinator.cancelSession()
                homeCoordinator.popLast()
            }
            Button("Keep scanning", role: .cancel) {}
        } message: {
            Text("All captured photos will be deleted.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                coordinator.goToCapture()
            } label: {
                Label("Back to camera", systemImage: "chevron.backward")
            }
            .accessibilityLabel("Back to camera")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Task {
                        if await coordinator.completeSession() {
                            homeCoordinator.popLast()
                            homeCoordinator.refreshRoomDetail()
                            homeCoordinator.refreshHome()
                        }
                    }
                } label: {
                    Label("Finish scan", systemImage: "checkmark")
                }
                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Label("Discard scan", systemImage: "trash")
                }
            } label: {
                if coordinator.isCompleting {
                    ProgressView()
                } else {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .accessibilityLabel("Scan actions")
        }
    }

    private func captureCard(_ capture: ScanCoordinator.ScanCapture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let uiImage = UIImage(data: capture.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            detectionsList(for: capture)

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    coordinator.deleteCapture(capture.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    coordinator.deleteCapture(capture.id)
                    coordinator.goToCapture()
                } label: {
                    Label("Retake", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func detectionsList(for capture: ScanCoordinator.ScanCapture) -> some View {
        if capture.isDetecting {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Detecting objects…").font(.footnote).foregroundStyle(.secondary)
            }
        } else if capture.detections.isEmpty {
            Text("No objects recognized. You can still save this photo as an item manually.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                coordinator.selectDetection(
                    DetectedObject(label: "", confidence: 0, boundingBox: .init(x: 0, y: 0, width: 1, height: 1)),
                    for: capture.id
                )
            } label: {
                Label("Save as item", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            SectionHeader("Detected objects")
                .padding(.top, 2)
            FlowLayout(spacing: 8) {
                ForEach(capture.detections) { detection in
                    DetectionChip(detection: detection) {
                        coordinator.selectDetection(detection, for: capture.id)
                    }
                }
            }
        }
    }
}

private struct DetectionChip: View {
    let detection: DetectedObject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(detection.label)
                    .font(.subheadline.weight(.medium))
                Text("\(Int(detection.confidence * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(detection.label), \(Int(detection.confidence * 100)) percent confidence, save as item")
    }
}

/// Very small flow layout — wraps a horizontal collection of chips onto new
/// lines when they exceed the container width.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width && currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalHeight += currentRowHeight
        return CGSize(width: width == .infinity ? currentRowWidth : width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
