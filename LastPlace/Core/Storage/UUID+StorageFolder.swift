//
//  UUID+StorageFolder.swift
//  LastPlace
//
//  Every object in the `item-images` bucket lives under a per-user folder,
//  and the Storage RLS policies gate access by comparing that folder name
//  against `auth.uid()::text` in Postgres.
//
//  The catch: Postgres renders a uuid as **lowercase**, while Swift's
//  `UUID.uuidString` is **uppercase**. So building a key with plain string
//  interpolation ("\(userID)/\(path)") produces
//  `0B7431D8-.../photo.jpg`, which no policy can ever match -- the owner
//  policy's `(storage.foldername(name))[1] = auth.uid()::text` compares
//  case-sensitively and fails, and Storage rejects the request. That's a
//  silent, total failure of photo sync: uploads 400, and because
//  `RootView.syncIfSignedIn` swallows sync errors with `try?`, nothing
//  surfaces in the UI at all. It only became visible as "the gifted image
//  isn't showing," several layers downstream.
//
//  So: never interpolate a raw `UUID` into a Storage key. Use this.
//

import Foundation

extension UUID {
    /// This user's folder name inside the `item-images` bucket, lowercased
    /// to match how Postgres renders `auth.uid()::text` in the Storage RLS
    /// policies.
    var storageFolderName: String {
        uuidString.lowercased()
    }

    /// Full Storage object key for one of this user's images. Prefer this
    /// over hand-building the `"folder/file"` string.
    func storageKey(for path: String) -> String {
        "\(storageFolderName)/\(path)"
    }
}
