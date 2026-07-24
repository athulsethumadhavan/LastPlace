//
//  AsyncRemoteImage.swift
//  LastPlace
//
//  Sibling to `AsyncStoredImage`, for content that isn't the current
//  device's own local cache — specifically Phase 4 shared-room images.
//  `AsyncStoredImage` reads through `ImageStorageService`, which is
//  local-file-only and can never hold another account's photos. This
//  component instead takes a plain `(String) async throws -> Data` loader,
//  so callers can plug in `RoomSharingService.loadSharedImageData(path:)`
//  (an on-demand Storage download) without teaching the storage layer
//  anything about cross-account access.
//

import SwiftUI
import UIKit

struct AsyncRemoteImage: View {
    let path: String?
    let contentMode: ContentMode
    let placeholderSymbol: String
    let load: (String) async throws -> Data

    @State private var image: UIImage?
    @State private var didFail: Bool = false

    init(
        path: String?,
        contentMode: ContentMode = .fill,
        placeholderSymbol: String = "photo",
        load: @escaping (String) async throws -> Data
    ) {
        self.path = path
        self.contentMode = contentMode
        self.placeholderSymbol = placeholderSymbol
        self.load = load
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .accessibilityHidden(true)
            } else {
                placeholder
            }
        }
        .task(id: path) { await fetch() }
    }

    private var placeholder: some View {
        ZStack {
            AppColor.surface
            Image(systemName: didFail ? "exclamationmark.triangle" : placeholderSymbol)
                .font(.title2)
                .foregroundStyle(didFail ? AppColor.textTertiary : AppColor.accent)
        }
    }

    private func fetch() async {
        guard let path, !path.isEmpty else {
            image = nil
            didFail = false
            return
        }
        do {
            let data = try await load(path)
            if let loaded = UIImage(data: data) {
                image = loaded
                didFail = false
            } else {
                didFail = true
            }
        } catch {
            didFail = true
        }
    }
}
