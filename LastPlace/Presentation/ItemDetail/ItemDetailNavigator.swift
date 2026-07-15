//
//  ItemDetailNavigator.swift
//  LastPlace
//
//  Small navigation surface shared by every host that presents the Item Detail
//  flow (`HomeCoordinator`, `SearchCoordinator`, …). Keeps the item-detail /
//  update-location views agnostic of which tab launched them.
//

import Foundation

@MainActor
protocol ItemDetailNavigator: AnyObject {
    /// Pushes the Update Location screen for the given item.
    func pushUpdateItemLocation(itemID: UUID)

    /// Pops the topmost screen of the host's NavigationPath.
    func popTop()

    /// Reload chain to run after any item mutation (toggle important, update
    /// location, delete). Each host decides which surfaces to refresh; the
    /// caller doesn't need to know.
    func refreshAfterItemMutation()
}
