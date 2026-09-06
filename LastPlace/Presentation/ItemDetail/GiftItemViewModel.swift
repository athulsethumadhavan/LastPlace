//
//  GiftItemViewModel.swift
//  LastPlace
//
//  Owner side of Phase 5 gifting: send a one-time copy of this item to
//  another registered LastPlace account by email. The item stays in the
//  sender's own inventory until the recipient accepts it into one of their
//  rooms — this screen only ever creates the pending `item_gifts` row.
//

import Foundation
import Observation

@Observable
@MainActor
final class GiftItemViewModel {
    let itemID: UUID
    private(set) var state: LoadableState<StoredItem> = .idle
    var recipientEmail: String = ""
    private(set) var isSending: Bool = false
    var sendError: UserFacingError?
    private(set) var sentGift: ItemGift?
    /// Set instead of `sendError` when sending is refused for lack of a
    /// subscription — an offer, not a failure, so the view shows the paywall
    /// rather than an alert.
    var paywallReason: PaywallReason?

    private let fetchDetailUseCase: FetchItemDetailUseCase
    private let itemGiftingService: ItemGiftingService
    /// Gates sending. Receiving stays free, so this is only consulted on
    /// the send path.
    private let entitlementService: EntitlementService
    /// See `send()` -- the `gift_item` RPC validates item ownership
    /// server-side, so an item that exists only in local SwiftData has to
    /// be pushed first.
    private let syncEngine: PendingChangesSyncing
    private let authService: AuthService
    private let imageStorage: ImageStorageService
    private let analytics: AnalyticsService
    private let logger: AppLogger

    init(
        itemID: UUID,
        fetchDetail: FetchItemDetailUseCase,
        itemGiftingService: ItemGiftingService,
        entitlementService: EntitlementService,
        syncEngine: PendingChangesSyncing,
        authService: AuthService,
        imageStorage: ImageStorageService,
        analytics: AnalyticsService,
        logger: AppLogger
    ) {
        self.itemID = itemID
        self.fetchDetailUseCase = fetchDetail
        self.itemGiftingService = itemGiftingService
        self.entitlementService = entitlementService
        self.syncEngine = syncEngine
        self.authService = authService
        self.imageStorage = imageStorage
        self.analytics = analytics
        self.logger = logger
    }

    var canSend: Bool {
        !isSending && sentGift == nil && isPlausibleEmail(recipientEmail)
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let detail = try await fetchDetailUseCase.execute(itemID: itemID)
            state = .loaded(detail.item)
        } catch {
            logger.error("Gift item load failed", error: error, category: "gifting")
            state = .failed(UserFacingError.from(error))
        }
    }

    func send() {
        guard canSend else { return }
        let email = recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        sendError = nil
        Task {
            defer { isSending = false }

            // Sending is premium; receiving is always free. Checked before
            // the sync below rather than after, so a free account doesn't
            // pay the cost of a full push just to be refused.
            //
            // Note this gate is currently client-side only. `gift_item` has
            // no entitlement check of its own, unlike the item cap and AI
            // naming — both of those protect something concrete (the
            // database's integrity, your Anthropic bill), whereas bypassing
            // this one costs nothing and requires hand-crafting an RPC call.
            // Worth adding to `gift_item` before launch, but it isn't the
            // hole the other two would have been.
            guard await entitlementService.statusOrFree().isPremium else {
                logger.log("Gift send blocked: no active entitlement", category: "gifting")
                paywallReason = .sendGift
                return
            }

            do {
                // Same reason as `GiftsViewModel.accept` -- an item saved
                // moments ago exists only locally until a sync runs, and
                // `gift_item` looks it up in Postgres. Also pushes the
                // photo, so the recipient can actually download it on
                // accept rather than getting a name-only gift.
                if let userID = await authService.currentUser?.id {
                    try? await syncEngine.sync(userID: userID, imageStorage: imageStorage)
                }
                sentGift = try await itemGiftingService.giftItem(itemID: itemID, recipientEmail: email)
                // No parameters -- deliberately not the recipient's email
                // address, which is another person's personal data.
                analytics.log(.giftSent)
            } catch {
                logger.error("Sending gift failed", error: error, category: "gifting")
                sendError = UserFacingError.from(error)
            }
        }
    }

    private func isPlausibleEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let atIndex = trimmed.firstIndex(of: "@") else { return false }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        return domain.contains(".")
    }
}
