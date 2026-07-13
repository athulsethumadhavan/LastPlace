//
//  DeleteItemUseCase.swift
//  LastPlace
//

import Foundation

protocol DeleteItemUseCase: Sendable {
    func execute(itemID: UUID) async throws
}

struct DefaultDeleteItemUseCase: DeleteItemUseCase {
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let imageStorage: ImageStorageService

    func execute(itemID: UUID) async throws {
        let item = try await itemRepository.fetchItem(itemID: itemID)
        let snapshots = try await snapshotRepository.fetchSnapshots(itemID: itemID)

        for snapshot in snapshots {
            if let path = snapshot.imagePath {
                try? await imageStorage.deleteImage(at: path)
            }
        }
        try await snapshotRepository.deleteSnapshots(forItemID: itemID)

        if let path = item.imagePath {
            try? await imageStorage.deleteImage(at: path)
        }
        try await itemRepository.delete(itemID: itemID)
    }
}
