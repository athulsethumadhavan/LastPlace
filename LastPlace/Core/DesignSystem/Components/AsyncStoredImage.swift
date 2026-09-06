//
//  AsyncStoredImage.swift
//  LastPlace
//
//  Loads image data from the injected `ImageStorageService` and renders it.
//  Reloads automatically when the `path` changes.
//

import SwiftUI
import UIKit

struct AsyncStoredImage: View {
    let path: String?
    let contentMode: ContentMode
    let placeholderSymbol: String

    @Environment(\.imageStorage) private var imageStorage
    @State private var image: UIImage?
    @State private var didFail: Bool = false

    init(
        path: String?,
        contentMode: ContentMode = .fill,
        placeholderSymbol: String = "photo"
    ) {
        self.path = path
        self.contentMode = contentMode
        self.placeholderSymbol = placeholderSymbol
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
        .task(id: path) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            AppColor.surface
            Image(systemName: didFail ? "exclamationmark.triangle" : placeholderSymbol)
                .font(.title2)
                .foregroundStyle(didFail ? AppColor.textTertiary : AppColor.accent)
        }
    }

    private func load() async {
        guard let path, !path.isEmpty, let storage = imageStorage else {
            image = nil
            didFail = false
            return
        }
        do {
            let data = try await storage.loadImageData(from: path)
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
