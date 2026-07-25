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

    private let fetchDetailUseCase: FetchItemDetailUseCase
    private let itemGiftingService: ItemGiftingService
    private let logger: AppLogger

    init(
        itemID: UUID,
        fetchDetail: FetchItemDetailUseCase,
        itemGiftingService: ItemGiftingService,
        logger: AppLogger
    ) {
        self.itemID = itemID
        self.fetchDetailUseCase = fetchDetail
        self.itemGiftingService = itemGiftingService
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
            do {
                sentGift = try await itemGiftingService.giftItem(itemID: itemID, recipientEmail: email)
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
