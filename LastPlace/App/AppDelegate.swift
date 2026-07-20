//
//  AppDelegate.swift
//  LastPlace
//
//  A minimal `UIApplicationDelegate`. SwiftUI's `App` protocol has no
//  scene-based equivalent hook for the URL callbacks below, so
//  `@UIApplicationDelegateAdaptor` in `LastPlaceApp` wires this in without
//  otherwise touching the SwiftUI app lifecycle.
//

import UIKit
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Google's consent flow completes by reopening the app via the custom
    /// URL scheme registered in Info.plist (the reversed iOS OAuth client
    /// ID); GIDSignIn needs this callback routed to it to finish the flow.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
