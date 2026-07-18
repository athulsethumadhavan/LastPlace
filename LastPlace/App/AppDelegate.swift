//
//  AppDelegate.swift
//  LastPlace
//
//  A minimal `UIApplicationDelegate`, only to receive the accept-share
//  callback for Family Find invitations — SwiftUI's `App` protocol has no
//  scene-based equivalent hook of its own. `@UIApplicationDelegateAdaptor`
//  in `LastPlaceApp` wires this in without otherwise touching the SwiftUI
//  app lifecycle.
//
//  Accepting a share is a self-contained CloudKit call (`CKAcceptSharesOperation`
//  against a fixed container identifier) that doesn't need `AppDependencyContainer`
//  at all, so this can run before the container finishes bootstrapping. The
//  "Shared With Me" screen fetches fresh from the shared database whenever it's
//  opened, so there's nothing else to hand off here beyond posting a
//  best-effort notification in case that screen happens to already be on screen.
//

import UIKit
import CloudKit

extension Notification.Name {
    static let homeShareAccepted = Notification.Name("LastPlace.homeShareAccepted")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        // Logged unconditionally, before anything else runs, so Console.app
        // can distinguish "the OS never called this at all" (nothing below
        // ever appears) from "it was called but accepting failed silently"
        // (this appears, but the success/failure line after it doesn't).
        let logger = OSAppLogger()
        logger.log(
            "userDidAcceptCloudKitShareWith fired for zone \(cloudKitShareMetadata.share.recordID.zoneID.zoneName), container \(cloudKitShareMetadata.containerIdentifier)",
            category: "family-find"
        )

        Task {
            let service = CloudKitHomeSharingService()
            do {
                try await service.acceptShare(metadata: cloudKitShareMetadata)
                logger.log("Successfully accepted CloudKit share", category: "family-find")
                await MainActor.run {
                    NotificationCenter.default.post(name: .homeShareAccepted, object: nil)
                }
            } catch {
                // Best-effort — if this fails the user can still discover
                // the invite again via the Messages/Mail link and retry;
                // there's no in-app surface to report a launch-time async
                // failure to at this point.
                logger.error("Failed to accept CloudKit share", error: error, category: "family-find")
            }
        }
    }
}
