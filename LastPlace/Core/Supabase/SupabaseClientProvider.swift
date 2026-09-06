//
//  SupabaseClientProvider.swift
//  LastPlace
//
//  One shared SupabaseClient for the whole app (Auth, and later Postgres/
//  Storage/Realtime once Phases 2-3 land), so every service talks to the
//  same session/token state instead of each holding its own client.
//
//  NOTE: requires the `supabase-swift` package. Add it via Xcode's
//  File -> Add Package Dependencies... using:
//    https://github.com/supabase/supabase-swift
//  and select the "Supabase" product (the umbrella library that includes
//  Auth, PostgREST, Storage, and Realtime). This file will not compile
//  until that's added.
//

import Foundation
import Supabase

enum SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.publishableKey
    )
}
