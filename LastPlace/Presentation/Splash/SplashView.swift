//
//  SplashView.swift
//  LastPlace
//
//  Matches the design mock's "01 · Splash" screen: the app icon, wordmark,
//  tagline, and a 3-dot page indicator (the first dot lit in `accent`) sitting
//  near the bottom of the frame. The dots are decorative here -- this app has
//  no swipeable splash carousel -- kept purely because the mock shows them.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Image("AuthAppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .appCardShadow()

                VStack(spacing: 6) {
                    Text("LastPlace")
                        .font(AppFont.heading(30))
                        .foregroundStyle(AppColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Never lose track again")
                        .font(AppFont.body(14))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(AppColor.accent).frame(width: 7, height: 7)
                    Circle().fill(AppColor.divider).frame(width: 7, height: 7)
                    Circle().fill(AppColor.divider).frame(width: 7, height: 7)
                }
                .padding(.bottom, 64)
                .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    SplashView()
}
