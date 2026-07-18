//
//  CloudSharingViewRepresentable.swift
//  LastPlace
//
//  Wraps `UICloudSharingController` for SwiftUI, following the pattern in
//  Apple's own CloudKit sharing sample. `availablePermissions` excludes
//  `.allowReadWrite` (no write option, ever — see `CloudKitHomeSharingService`'s
//  file-level doc comment) and `.allowPublic` (public links route to
//  icloud.com's web viewer instead of handing off to this app — confirmed
//  by testing, see the doc comment on `CloudKitHomeSharingService.configure`).
//  That means inviting someone has to go through this controller's own
//  Mail/Messages option addressed to them specifically, not "Copy Link" —
//  a link copied and sent through some other channel won't grant access.
//

import SwiftUI
import UIKit
import CloudKit

struct CloudSharingViewRepresentable: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let itemTitle: String

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadOnly, .allowPrivate]
        controller.delegate = context.coordinator
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(itemTitle: itemTitle)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let itemTitle: String

        init(itemTitle: String) {
            self.itemTitle = itemTitle
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { itemTitle }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            OSAppLogger().error("CloudSharingController failed to save share", error: error, category: "family-find")
        }
    }
}
