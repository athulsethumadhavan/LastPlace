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
        VStack(spacing: 0) {
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
                            slotWarning
                            ForEach(coordinator.captures) { capture in
                                captureCard(capture)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            if coordinator.selectedDetection != nil {
                proceedBar
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.selectedDetection?.detection.id)
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

        // Finishing and discarding both moved up here when the bottom bar
        // became the single Proceed action. Done ends the session keeping
        // whatever was already saved; Discard throws the whole scan away.
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
                    Label("Done", systemImage: "checkmark")
                }

                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Label("Discard scan", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .disabled(coordinator.isCompleting)
        }
    }

    /// Replaces the previous always-visible Discard/Save pair.
    ///
    /// Tapping a detection used to navigate straight to the save form, which
    /// made a single tap commit to a name with no way to reconsider. Now a
    /// tap only highlights, and this appears to confirm — so the choice and
    /// the commitment are two separate, reversible steps.
    ///
    /// Only rendered when something is selected, so the bar isn't sitting
    /// there disabled while the person is still deciding. Discarding the
    /// scan lives in the toolbar now; it's a rare, destructive action and
    /// doesn't need permanent real estate next to the primary one.
    private var proceedBar: some View {
        Button {
            guard let selection = coordinator.selectedDetection else { return }
            coordinator.selectDetection(selection.detection, for: selection.captureID)
        } label: {
            Label("Proceed", systemImage: "arrow.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Warns before the fact when there are more photos here than free
    /// slots left to save them into.
    ///
    /// Shown only when it actually bites — captures exceeding the remaining
    /// allowance — rather than on every scan. A permanent counter here would
    /// put a meter in front of the app's main action, and someone with eight
    /// slots and two photos has nothing to plan around.
    ///
    /// Nothing is lost either way: saves are gated one at a time, and a
    /// refused save leaves its photo sitting in this list. This just means
    /// the person finds out before working through them, not during.
    @ViewBuilder
    private var slotWarning: some View {
        if let remaining = coordinator.remainingItemSlots,
           coordinator.captures.count > remaining {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: remaining == 0 ? "exclamationmark.circle" : "info.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColor.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(remaining == 0
                         ? "No free item slots left"
                         : "Room for \(remaining) more \(remaining == 1 ? "item" : "items")")
                        .font(AppFont.body(13.5, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)

                    Text(remaining == 0
                         ? "You've used all \(EntitlementStatus.freeItemLimit) free items. Your photos stay here until you upgrade or free up space."
                         : "You have \(coordinator.captures.count) photos. Save the ones you want most first — the rest stay here.")
                        .font(AppFont.body(11.5))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
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

                // Escape hatch for when recognition is confidently wrong,
                // which happens most with several objects in frame -- the
                // model picks one and there's no way to say "none of these".
                // Goes to the same save form with an empty name, so the
                // photo is kept and only the naming is manual.
                //
                // Always available, not just when nothing was detected:
                // a wrong answer is exactly when you need this, and that's
                // precisely the case where the empty-state button doesn't
                // appear.
                Button {
                    coordinator.selectDetection(
                        DetectedObject(
                            label: "",
                            confidence: 0,
                            boundingBox: .init(x: 0, y: 0, width: 1, height: 1)
                        ),
                        for: capture.id
                    )
                } label: {
                    Label("Add Manually", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(capture.isDetecting)

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
            // No button here any more -- "Add Manually" below does exactly
            // this and is always present, so a second one would just be two
            // controls doing the same thing a few points apart.
            Text("No objects recognized. Use Add Manually to save this photo as an item.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            SectionHeader(capture.detections.count == 1 ? "Detected object" : "Detected objects")
                .padding(.top, 2)
            // Only worth saying when there's an actual choice to make. With a
            // single auto-selected result the instruction would be telling
            // the person to do something that's already done.
            if capture.detections.count > 1 {
                Text("Tap the best match, then Proceed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                ForEach(capture.detections) { detection in
                    DetectionChip(
                        detection: detection,
                        isSelected: capture.selectedDetectionID == detection.id
                    ) {
                        coordinator.toggleSelection(detection.id, for: capture.id)
                    }
                }
            }
        }
    }
}

private struct DetectionChip: View {
    let detection: DetectedObject
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                }
                Text(detection.label)
                    .font(.subheadline.weight(.medium))
                Text("\(Int(detection.confidence * 100))%")
                    .font(.caption.monospacedDigit())
                    .opacity(0.7)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? AnyShapeStyle(AppColor.accent) : AnyShapeStyle(Color(.tertiarySystemGroupedBackground)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        // `isSelected` rather than a static description: a chip that toggles
        // needs to announce its current state, not just what tapping does.
        .accessibilityLabel("\(detection.label), \(Int(detection.confidence * 100)) percent confidence")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
