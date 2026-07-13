//
//  ItemDetail.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//
//  Composite read-model returned by FetchItemDetailUseCase.
//

import Foundation

struct ItemDetail: Hashable, Sendable {
    let item: StoredItem
    let room: Room
    let snapshots: [ItemSnapshot]
}
