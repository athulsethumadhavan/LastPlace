//
//  AnalyticsService.swift
//  LastPlace
//
//  Protocol-wrapped product analytics, mirroring `BiometricAuthenticator` /
//  `ObjectDetectionService` -- feature code never imports FirebaseAnalytics
//  directly, and previews/tests get a no-op (or recording) mock instead of
//  firing real events.
//
//  PRIVACY RULE, non-negotiable: no user content ever becomes an event
//  parameter. No item names, notes, location descriptions, room names,
//  email addresses, or search queries. Only counts, enum-backed
//  categories, booleans, and durations. This isn't a style preference --
//  the app's privacy policy and its App Store privacy label both declare
//  analytics as "Product Interaction" and "Diagnostics" only, and logging
//  a single item name here would quietly make both of those false.
//
//  That's also why `AnalyticsEvent` is a closed enum rather than a
//  `log(name:parameters:)` free-for-all: every event and every parameter
//  is declared in this one file, so the rule above can be verified by
//  reading it, instead of auditing every call site in the app.
//

import Foundation

/// Every analytics event the app can emit. Associated values are
/// deliberately limited to non-identifying types.
enum AnalyticsEvent: Sendable {
    /// How an item came to exist.
    enum ItemSource: String, Sendable {
        case scan
        case manual
        case giftAccepted = "gift_accepted"
    }

    /// Which naming path produced the label the user ended up with.
    enum NamingOutcome: String, Sendable {
        /// Cloud AI returned a usable name.
        case ai
        /// AI failed or returned nothing; on-device Vision was used.
        case visionFallback = "vision_fallback"
        /// Neither produced anything; the user typed the name themselves.
        case none
    }

    enum SignInMethod: String, Sendable {
        case email
        case apple
        case google
    }

    case itemSaved(source: ItemSource, category: ItemCategory, hasPhoto: Bool)
    /// The core value loop -- someone updated where a thing actually is.
    case itemLocated(hasPhoto: Bool)
    case scanCompleted(captureCount: Int, itemsSaved: Int)
    case itemNamed(outcome: NamingOutcome)
    /// `resultCount` only; never the query text.
    case searchPerformed(resultCount: Int)
    case roomCreated
    case checklistCompleted(entryCount: Int)
    case giftSent
    case giftAccepted
    case roomShared
    case signedIn(method: SignInMethod)

    /// snake_case, matching Firebase's own convention for custom events.
    var name: String {
        switch self {
        case .itemSaved:         return "item_saved"
        case .itemLocated:       return "item_located"
        case .scanCompleted:     return "scan_completed"
        case .itemNamed:         return "item_named"
        case .searchPerformed:   return "search_performed"
        case .roomCreated:       return "room_created"
        case .checklistCompleted: return "checklist_completed"
        case .giftSent:          return "gift_sent"
        case .giftAccepted:      return "gift_accepted"
        case .roomShared:        return "room_shared"
        case .signedIn:          return "signed_in"
        }
    }

    /// Firebase accepts `String` and `NSNumber` parameter values; bools are
    /// sent as 0/1 integers rather than strings so they aggregate as
    /// numbers in the console.
    var parameters: [String: Any] {
        switch self {
        case let .itemSaved(source, category, hasPhoto):
            return [
                "source": source.rawValue,
                "category": category.rawValue,
                "has_photo": hasPhoto ? 1 : 0
            ]
        case let .itemLocated(hasPhoto):
            return ["has_photo": hasPhoto ? 1 : 0]
        case let .scanCompleted(captureCount, itemsSaved):
            return ["capture_count": captureCount, "items_saved": itemsSaved]
        case let .itemNamed(outcome):
            return ["outcome": outcome.rawValue]
        case let .searchPerformed(resultCount):
            return ["result_count": resultCount]
        case .roomCreated, .giftSent, .giftAccepted, .roomShared:
            return [:]
        case let .checklistCompleted(entryCount):
            return ["entry_count": entryCount]
        case let .signedIn(method):
            return ["method": method.rawValue]
        }
    }
}

protocol AnalyticsService: Sendable {
    func log(_ event: AnalyticsEvent)
}
