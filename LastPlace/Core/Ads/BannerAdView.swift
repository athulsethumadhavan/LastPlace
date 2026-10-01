//
//  BannerAdView.swift
//  LastPlace
//
//  A single reusable AdMob banner slot, sized to the device's full width
//  via Google's inline adaptive banner format, capped to a smaller height
//  than the anchored "large" adaptive banner (which can run up to 150pt,
//  an earlier version of this file used that and it read as oversized on
//  Home). `maxBannerHeight` below controls how tall it's allowed to get --
//  raise or lower it there if the fit still isn't right.
//
//  TEMPORARILY ALWAYS VISIBLE for debugging why test ads weren't showing:
//  this reserves its full height and shows the raw `BannerView` regardless
//  of load state, so an empty/gray box is now visible on Home even before
//  (or if) an ad ever loads -- that's the point, it makes the slot itself
//  easy to find and confirms this code path is actually running. A prior
//  version of this file hid the whole view until `isAdLoaded` flipped true
//  and hid it again on failure (see git history); once test ads are
//  confirmed working, restore that by making `body` below conditional on
//  `isAdLoaded` again, the same way `HomeView.showsBannerAd` conditionally
//  mounts this view in the first place.
//
//  Ad unit ID lives in `AdsConfiguration.swift`, not here -- this view
//  never needs to know whether it's showing a test or a real ad.
//
//  Sized once from the screen's width at creation rather than tracked
//  live through rotation -- acceptable for now since Home is used almost
//  entirely in portrait; revisit if landscape banners ever look wrong.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session, against the current Google Mobile Ads SDK for iOS (the
//  Swift-first naming introduced in SDK 11/13 -- `BannerView`, `AdSize`,
//  `Request`, `BannerViewDelegate`, all without the old `GAD` prefix). The
//  adaptive-sizing call (`inlineAdaptiveBanner(width:maxHeight:)`) carries
//  the same naming uncertainty noted in this file's prior revision -- see
//  git history / the previous VERIFY-BEFORE-TRUST comment here if that
//  hasn't been confirmed yet. The delegate methods below
//  (`bannerViewDidReceiveAd` / `bannerView(_:didFailToReceiveAdWithError:)`)
//  are inferred from the same Swift-first renaming pattern as everything
//  else in this file; if either doesn't match what Xcode offers when you
//  type `banner` after `func` inside `Coordinator`, send me what it
//  suggests instead.
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    /// Still tracked and updated by `Coordinator` below, but nothing reads
    /// it right now -- see the header comment. Restoring the hide/show
    /// behavior later just means wiring `body` back to this, not re-adding
    /// the plumbing.
    @State private var isAdLoaded = false

    var body: some View {
        BannerViewRepresentable(isAdLoaded: $isAdLoaded)
            .frame(maxWidth: .infinity)
            .frame(height: BannerViewRepresentable.adSize.size.height)
    }
}

private struct BannerViewRepresentable: UIViewRepresentable {
    @Binding var isAdLoaded: Bool

    /// Full device width, capped to this height so the ad reads as a
    /// slim bottom strip rather than a large block. 60pt is close to the
    /// classic ~50pt fixed banner most apps use; adjust here if it still
    /// looks too big or too cramped once you see it on device.
    private static let maxBannerHeight: CGFloat = 60

    static var adSize: AdSize {
        inlineAdaptiveBanner(width: UIScreen.main.bounds.width, maxHeight: maxBannerHeight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isAdLoaded: $isAdLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adSize)
        banner.adUnitID = AdsConfiguration.bannerAdUnitID
        banner.rootViewController = Self.topViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    /// `BannerView` needs a root view controller to present click-throughs
    /// (the in-app browser sheet a tapped ad opens). SwiftUI has no view
    /// controller of its own to hand it, so this reaches for the key
    /// window's instead.
    private static func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .rootViewController
    }

    /// Reflects AdMob's load result back into SwiftUI state so `BannerAdView`
    /// can show or collapse itself. A failed load only hides the banner --
    /// it doesn't stop retrying; `BannerView` keeps refreshing on its own
    /// default schedule, and a later success flips `isAdLoaded` back to
    /// true automatically.
    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding private var isAdLoaded: Bool

        init(isAdLoaded: Binding<Bool>) {
            _isAdLoaded = isAdLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            isAdLoaded = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            isAdLoaded = false
        }
    }
}
