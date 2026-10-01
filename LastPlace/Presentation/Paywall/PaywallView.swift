//
//  PaywallView.swift
//  LastPlace
//
//  Shown when someone runs into a premium gate, or opens "Go Premium" from
//  Settings on purpose. Presented as a sheet from wherever it was triggered,
//  so dismissing returns them to what they were doing rather than unwinding
//  a navigation stack.
//
//  `continueButton` and `restoreButton` call RevenueCat directly --
//  `Purchases.shared` is a process-wide singleton (configured once in
//  `AppDelegate`, same pattern as `GIDSignIn`), so this view needs no
//  dependency-injected service to reach it. This view never checks the
//  resulting entitlement itself: the real "is this account premium" answer
//  lives in the `entitlements` table, written by the RevenueCat webhook and
//  read via `EntitlementService` -- see that file's doc comment. Dismissing
//  on a successful purchase and letting whatever screen sent someone here
//  re-check status the normal way keeps this screen from needing to know
//  anything about that table.
//
//  VERIFY-BEFORE-TRUST: `loadOffering`/`purchaseSelectedPlan`/
//  `restorePurchases` below are written against the documented async
//  `Purchases` API (`offerings()`, `purchase(package:)`,
//  `restorePurchases()`) but haven't been built against the actual package
//  target in this session -- same caveat as `AppCoordinator.
//  syncRevenueCatUser`. Build this file first once the SDK is added; a
//  mismatch here (a renamed parameter, a different tuple label) is the kind
//  of thing Xcode's own errors catch faster than re-reading this comment.
//

import RevenueCat
import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PremiumPlan = .yearly
    @State private var offering: Offering?
    @State private var isPurchasing = false
    @State private var purchaseErrorMessage: String?

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
        // Loaded once per presentation rather than cached at app scope --
        // this sheet is the only place packages/prices are shown, and
        // fetching fresh each time means a price or availability change in
        // App Store Connect shows up without a reinstall.
        .task { await loadOffering() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { purchaseErrorMessage != nil },
                set: { if !$0 { purchaseErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { purchaseErrorMessage = nil }
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: reason.symbolName)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 62, height: 62)
                .background(AppColor.surface, in: Circle())
                .accessibilityHidden(true)

            // Leads with the specific thing they just hit, not a generic
            // "Go Premium" -- except when the reason *is* `.upgrade`, where
            // that generic framing is the point (see its doc comment).
            // Someone who tried to save an 11th item and someone who tried
            // to send a gift arrived here for different reasons and
            // shouldn't read the same sentence.
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
            benefitRow(
                symbol: "rectangle.slash",
                title: "No ads",
                detail: "Browse Home without the banner ad at the bottom."
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
            Spacer(minLength: 8)

            // Decorative confirmation, matching the checklist look people
            // expect from a pricing screen -- `benefitRow`'s left-hand icon
            // already names the feature, so this doesn't need a label of
            // its own.
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        }
    }

    /// The plan picker and buy button. See the header comment for why
    /// `Continue` and `Restore Purchases` currently just explain they're
    /// not live yet instead of doing anything -- everything visual here is
    /// meant to be the real screen, ready for that one swap.
    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PremiumPlan.allCases) { plan in
                planRow(plan)
            }

            continueButton
            restoreButton

            Text("Subscriptions auto-renew until canceled. Cancel anytime in Settings at least 24 hours before renewal to avoid being charged.")
                .font(AppFont.body(11))
                .foregroundStyle(AppColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    private func planRow(_ plan: PremiumPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AppColor.accent : AppColor.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        if plan.isBestValue {
                            Text("BEST VALUE")
                                .font(AppFont.body(10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColor.accent, in: Capsule())
                        }
                    }
                    Text(plan.billingText)
                        .font(AppFont.body(12))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
                Text(priceText(for: plan))
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(14)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                    .stroke(isSelected ? AppColor.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// The package for a plan, once `offering` has loaded -- `nil` while
    /// still loading or if the fetch failed. Looked up by identifier rather
    /// than by StoreKit's own `.monthly`/`.annual` package-type convenience,
    /// since both products live in one offering and `rawValue` was chosen to
    /// match the identifiers set on them in the RevenueCat dashboard.
    private func package(for plan: PremiumPlan) -> Package? {
        offering?.package(identifier: plan.rawValue)
    }

    /// Apple requires showing the actual StoreKit price, not a hardcoded
    /// one -- it varies by storefront/currency and can change without an app
    /// update. `plan.priceText` only covers the gap before `offering`
    /// finishes loading (or if it fails to), not the steady-state price.
    private func priceText(for plan: PremiumPlan) -> String {
        package(for: plan)?.storeProduct.localizedPriceString ?? plan.priceText
    }

    private func loadOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.current
        } catch {
            // Best-effort: `priceText`/`purchaseSelectedPlan` already
            // degrade sensibly (placeholder price, an explained failure on
            // tap) when `offering` stays nil, so there's nothing else to do
            // with this error here.
        }
    }

    private var continueButton: some View {
        Button {
            Task { await purchaseSelectedPlan() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .font(AppFont.body(16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.accent, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
        .padding(.top, 4)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await restorePurchases() }
        }
        .font(AppFont.body(14, weight: .medium))
        .foregroundStyle(AppColor.accent)
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(isPurchasing)
    }

    private func purchaseSelectedPlan() async {
        guard let package = package(for: selectedPlan) else {
            purchaseErrorMessage = "This plan isn't available right now. Please try again in a moment."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            // `userCancelled` isn't an error -- someone backing out of
            // Apple's purchase sheet should land right back on this screen,
            // not see an error alert for changing their mind.
            if !result.userCancelled {
                dismiss()
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    /// For someone who already bought this on another device, or is
    /// reinstalling -- StoreKit ties purchases to the Apple ID, not this
    /// app's account, so this is the only way those recover access here.
    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            _ = try await Purchases.shared.restorePurchases()
            dismiss()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }
}

/// Fallback pricing shown only before `offering` loads (or if it fails to)
/// -- see `priceText(for:)`. `rawValue` doubles as the product's RevenueCat
/// package identifier, matching what's configured in the dashboard, so
/// `package(for:)` is a lookup rather than a separate mapping to maintain.
private enum PremiumPlan: String, CaseIterable, Identifiable {
    case yearly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly:  return "Yearly"
        case .monthly: return "Monthly"
        }
    }

    var billingText: String {
        switch self {
        case .yearly:  return "Billed annually"
        case .monthly: return "Billed monthly"
        }
    }

    /// Fallback only -- `PaywallView.priceText(for:)` prefers the real
    /// StoreKit price via RevenueCat and only reaches this while `offering`
    /// is still loading or failed to load. Kept in sync with the actual App
    /// Store Connect prices by hand since there's no way to read them here
    /// without a loaded offering to fall back to.
    var priceText: String {
        switch self {
        case .yearly:  return "$39.99"
        case .monthly: return "$4.99"
        }
    }

    var isBestValue: Bool { self == .yearly }
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

#Preview("Go Premium") {
    PaywallView(reason: .upgrade)
}
