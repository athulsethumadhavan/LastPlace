//
//  DeleteRoomUseCase.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//
//  Cascades: deletes the room, all items in it, their snapshots, and any
//  cover/item/snapshot image files. Best-effort deletion on the file side —
//  storage errors are swallowed so a corrupt image can't wedge the delete.
//

import Foundation

protocol DeleteRoomUseCase: Sendable {
    func execute(roomID: UUID) async throws
}

struct DefaultDeleteRoomUseCase: DeleteRoomUseCase {
    let roomRepository: RoomRepository
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let imageStorage: ImageStorageService

    func execute(roomID: UUID) async throws {
        let room = try await roomRepository.fetchRoom(roomID: roomID)
        let items = try await itemRepository.fetchItems(roomID: roomID)

        for item in items {
            let snapshots = try await snapshotRepository.fetchSnapshots(itemID: item.id)
            for snapshot in snapshots {
                if let path = snapshot.imagePath {
                    try? await imageStorage.deleteImage(at: path)
                }
            }
            try await snapshotRepository.deleteSnapshots(forItemID: item.id)

            if let path = item.imagePath {
                try? await imageStorage.deleteImage(at: path)
            }
            try await itemRepository.delete(itemID: item.id)
        }

        if let coverPath = room.coverImagePath {
            try? await imageStorage.deleteImage(at: coverPath)
        }
        try await roomRepository.delete(roomID: roomID)
    }
}
