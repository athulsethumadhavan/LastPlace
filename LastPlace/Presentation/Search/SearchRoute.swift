//
//  SearchRoute.swift
//  LastPlace
//

import Foundation

enum SearchRoute: Hashable {
    case itemDetail(itemID: UUID)
    case updateItemLocation(itemID: UUID)
}
