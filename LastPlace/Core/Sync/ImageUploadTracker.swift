//
//  ImageUploadTracker.swift
//  LastPlace
//
//  Tracks which local image paths have already been uploaded to Supabase
//  Storage, so `SyncEngine` doesn't re-upload the same (often large) JPEG on
//  every foreground sync. Deliberately just a flat `UserDefaults`-backed
//  set rather than a stored property on `SyncEngine` -- `SyncEngine` is a
//  `@ModelActor`, and adding extra stored properties there means hand-
//  writing the actor's init instead of relying on the macro's generated
//  one, which isn't worth the risk for something this small.
//
//  Not needing to survive a reinstall is fine: a reinstalled app has no
//  local image files left either, so there's nothing pending upload for it
//  to falsely think is already done -- it'll be in `pullMissingImages`
//  territory instead, which doesn't consult this at all.
//

import Foundation

enum ImageUploadTracker {
    private static let key = "com.lastplace.sync.uploadedImagePaths"
    private static let defaults = UserDefaults.standard

    static func isUploaded(_ path: String) -> Bool {
        Set(defaults.stringArray(forKey: key) ?? []).contains(path)
    }

    static func markUploaded(_ path: String) {
        var uploaded = Set(defaults.stringArray(forKey: key) ?? [])
        uploaded.insert(path)
        defaults.set(Array(uploaded), forKey: key)
    }
}
