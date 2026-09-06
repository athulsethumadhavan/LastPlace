//
//  SearchResults.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct SearchResults: Hashable, Sendable {
    /// Items that match the query (name, category, room name, location, notes).
    let matches: [StoredItem]
    /// Recents + important items — surfaced when `matches` is empty so the view
    /// model never has to decide the fallback itself.
    let suggested: [StoredItem]

    var hasMatches: Bool { !matches.isEmpty }
    var isEmpty: Bool { matches.isEmpty && suggested.isEmpty }
}
