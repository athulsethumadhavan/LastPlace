//
//  GoogleAuthConfig.swift
//  LastPlace
//
//  Fill these in after creating OAuth client IDs in Google Cloud Console
//  (console.cloud.google.com -> APIs & Services -> Credentials):
//
//  1. Create a "Web application" OAuth client -> this is `webClientID`.
//     Register it (and the iOS one below) in Supabase Dashboard ->
//     Authentication -> Providers -> Google -> Client IDs, web ID first,
//     comma-separated. Enable "Skip nonce check" there too -- the
//     GoogleSignIn-iOS flow used by SupabaseAuthService doesn't send one.
//  2. Create an "iOS" OAuth client using this app's bundle ID -> this is
//     `iosClientID`. Its REVERSED_CLIENT_ID (swap the dot-separated parts,
//     e.g. "com.googleusercontent.apps.XXXX") goes into Info.plist's
//     CFBundleURLTypes entry, which already has a placeholder waiting for it.
//
//  Both values are safe to hardcode -- like the Supabase publishable key,
//  OAuth client IDs are meant to be embedded in a client and aren't secret
//  by themselves.
//

import Foundation

enum GoogleAuthConfig {
    static let webClientID = "535511492713-gfs3agaiu2q5kg9igf9aa5g8th2krl4u.apps.googleusercontent.com"
    static let iosClientID = "535511492713-o1h6gtq871qscau248famr3i9vujtudr.apps.googleusercontent.com"
}
