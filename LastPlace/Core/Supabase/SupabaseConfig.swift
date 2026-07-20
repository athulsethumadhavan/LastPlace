//
//  SupabaseConfig.swift
//  LastPlace
//
//  The project URL and publishable ("anon") key for the LastPlace Supabase
//  project. The publishable key is designed to be embedded in client apps —
//  it's the public counterpart to a secret service-role key, which must
//  NEVER appear in this codebase. Row Level Security policies on the
//  database (see the `create_profiles_table` / `harden_profile_trigger_functions`
//  migrations) are what actually keep one user's data safe from another,
//  not secrecy of this key.
//

import Foundation

enum SupabaseConfig {
    static let projectURL = URL(string: "https://bsdhgkodylnwapuctahr.supabase.co")!
    static let publishableKey = "sb_publishable_Gv3AT5rS9LvS6-J4H_XfpQ_CqF0frTX"
}
