//
//  ItemCategory.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

enum ItemCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case documents
    case electronics
    case keys
    case wallets
    case glasses
    case bags
    case clothing
    case chargers
    case tools
    case medication
    case jewelry
    case other

    var displayName: String {
        switch self {
        case .documents:   return "Documents"
        case .electronics: return "Electronics"
        case .keys:        return "Keys"
        case .wallets:     return "Wallets"
        case .glasses:     return "Glasses"
        case .bags:        return "Bags"
        case .clothing:    return "Clothing"
        case .chargers:    return "Chargers"
        case .tools:       return "Tools"
        case .medication:  return "Medication"
        case .jewelry:     return "Jewelry"
        case .other:       return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .documents:   return "doc.text"
        case .electronics: return "desktopcomputer"
        case .keys:        return "key"
        case .wallets:     return "creditcard"
        case .glasses:     return "eyeglasses"
        case .bags:        return "bag"
        case .clothing:    return "tshirt"
        case .chargers:    return "bolt.batteryblock"
        case .tools:       return "hammer"
        case .medication:  return "pills"
        case .jewelry:     return "sparkles"
        case .other:       return "shippingbox"
        }
    }
}
