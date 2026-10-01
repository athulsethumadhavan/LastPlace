//
//  AdsConfiguration.swift
//  LastPlace
//

import Foundation

enum AdsConfiguration {
    /// Google's own published test banner unit. Always safe to ship --
    /// Google explicitly documents this ID for use during development.
    private static let strBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    /// Real LastPlace banner ad unit, from AdMob. Not used yet -- see the
    /// header comment above for how to switch this on.
//    private static let strBannerAdUnitID = "ca-app-pub-2018956823856869/1626362226"

    static var bannerAdUnitID: String {
        strBannerAdUnitID
    }
}
