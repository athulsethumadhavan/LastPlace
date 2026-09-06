//
//  PaywallView.swift
//  LastPlace
//
//  Shown when someone runs into a premium gate. Presented as a sheet from
//  wherever the gate was hit, so dismissing returns them to what they were
//  doing rather than unwinding a navigation stack.
//
//  There is deliberately no purchase button yet. Products don't exist in App
//  Store Connect, RevenueCat isn't wired, and a button that can't complete a
//  purchase is worse than no button -- it's also an App Store rejection if
//  it looks buyable and isn't. This screen currently explains the limit and
//  gets out of the way.
//
//  When RevenueCat lands, the purchase controls slot into `purchaseSection`
//  below, alongside the Restore Purchases action and the Terms/Privacy links
//  Apple requires for auto-renewable subscriptions. Nothing else about this
//  screen should need to change.
//

import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    purchaseSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 62, height: 62)
                .background(AppColor.surface, in: Circle())
                .accessibilityHidden(true)

            // Leads with the specific thing they just hit, not a generic
            // "Go Premium". Someone who tried to save an 11th item and
            // someone who tried to send a gift arrived here for different
            // reasons and shouldn't read the same sentence.
            Text(reason.title)
                .font(AppFont.heading(24))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(reason.message)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("With premium")

            benefitRow(
                symbol: "infinity",
                title: "Unlimited items",
                detail: "Save as much of your home as you like."
            )
            benefitRow(
                symbol: "wand.and.stars",
                title: "Smart naming",
                detail: "Photos get named for you, instead of on-device guesses."
            )
            benefitRow(
                symbol: "gift",
                title: "Send items",
                detail: "Hand something over to another LastPlace account."
            )
        }
    }

    private func benefitRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 34, height: 34)
                .background(AppColor.surface, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(detail)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Placeholder until RevenueCat and App Store Connect products exist.
    ///
    /// Says plainly that it isn't purchasable yet rather than showing a
    /// disabled "Subscribe" button, which would read as a bug. Also names
    /// what still works for free, so the screen isn't purely a refusal --
    /// nothing they've already saved is affected by hitting this.
    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Not available yet")
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)

            Text("Subscriptions aren't open yet — this is here so you can see what's coming. Everything you've already saved stays put, and rooms, sharing and search are always free.")
                .font(AppFont.body(13))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }
}

#Preview("Item limit") {
    PaywallView(reason: .itemLimitReached)
}

#Preview("AI naming") {
    PaywallView(reason: .aiIdentification)
}

#Preview("Gift at limit") {
    PaywallView(reason: .acceptGiftAtLimit)
}
