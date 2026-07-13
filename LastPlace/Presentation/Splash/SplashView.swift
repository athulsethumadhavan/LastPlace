//
//  SplashView.swift
//  LastPlace
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "house.and.flag")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("LastPlace")
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }
}

#Preview {
    SplashView()
}
