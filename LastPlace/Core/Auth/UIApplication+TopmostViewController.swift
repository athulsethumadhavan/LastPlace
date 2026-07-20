//
//  UIApplication+TopmostViewController.swift
//  LastPlace
//
//  GIDSignIn's consent screen (unlike SwiftUI's SignInWithAppleButton) needs
//  a concrete UIViewController to present from, even when triggered from a
//  SwiftUI screen. This walks the key window's presented-view-controller
//  chain to find the right one to hand it.
//

import UIKit

extension UIApplication {
    @MainActor
    var topmostViewController: UIViewController? {
        let keyWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
