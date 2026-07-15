//
//  ScanCaptureView.swift
//  LastPlace
//
//  Immersive camera view. Full-bleed preview plus a shutter, torch toggle,
//  cancel, and a "Review" button that switches the coordinator to the review
//  screen once at least one photo has been captured.
//

import SwiftUI

struct ScanCaptureView: View {
    @Bindable var coordinator: ScanCoordinator
    let homeCoordinator: HomeCoordinator

    var body: some View {
        ZStack {
            if coordinator.isStartingSession {
                Color.black.ignoresSafeArea()
                LoadingView(message: "Preparing camera…")
                    .foregroundStyle(.white)
            } else {
                coordinator.camera.makePreviewView()
                    .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button {
                coordinator.cancelSession()
                homeCoordinator.popLast()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Cancel scan")

            Spacer()

            Button {
                coordinator.toggleTorch()
            } label: {
                Image(systemName: coordinator.torchOn ? "bolt.fill" : "bolt.slash.fill")
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel(coordinator.torchOn ? "Turn torch off" : "Turn torch on")
        }
        .font(.title3)
        .foregroundStyle(.white)
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            capturesThumbnail
            Spacer()
            shutterButton
            Spacer()
            reviewButton
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var capturesThumbnail: some View {
        if let last = coordinator.captures.last, let uiImage = UIImage(data: last.imageData) {
            Button {
                if !coordinator.captures.isEmpty { coordinator.goToReview() }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    if coordinator.captures.count > 1 {
                        Text("\(coordinator.captures.count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .accessibilityLabel("Review \(coordinator.captures.count) capture\(coordinator.captures.count == 1 ? "" : "s")")
        } else {
            Color.clear.frame(width: 52, height: 52)
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await coordinator.capturePhoto() }
        } label: {
            ZStack {
                Circle().stroke(Color.white, lineWidth: 4).frame(width: 74, height: 74)
                Circle().fill(coordinator.isCapturing ? Color.white.opacity(0.6) : Color.white)
                    .frame(width: 60, height: 60)
                if coordinator.isCapturing {
                    ProgressView().tint(.black)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(coordinator.isCapturing || coordinator.isStartingSession || coordinator.session == nil)
        .sensoryFeedback(.impact, trigger: coordinator.captures.count)
        .accessibilityLabel("Capture photo")
    }

    @ViewBuilder
    private var reviewButton: some View {
        if coordinator.captures.isEmpty {
            Color.clear.frame(width: 52, height: 52)
        } else {
            Button {
                coordinator.goToReview()
            } label: {
                Text("Review")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
            }
            .accessibilityLabel("Review captures")
        }
    }
}
