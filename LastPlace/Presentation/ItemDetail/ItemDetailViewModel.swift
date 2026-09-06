//
//  ItemDetailViewModel.swift
//  LastPlace
//
//  Loads an `ItemDetail` (item + room + snapshot history) and exposes the
//  quick mutations reachable from the detail screen: toggle importance and
//  delete. Update-location lives in its own view model so this class isn't
//  responsible for the location form's state.
//

import Foundation
import Observation

@Observable
@MainActor
final class ItemDetailViewModel {
    let itemID: UUID
    private(set) var state: LoadableState<ItemDetail> = .idle
    private(set) var isDeleting: Bool = false
    private(set) var isTogglingImportance: Bool = false
    var mutationError: UserFacingError?

    private let fetchDetailUseCase: FetchItemDetailUseCase
    private let deleteItemUseCase: DeleteItemUseCase
    private let toggleImportanceUseCase: ToggleItemImportanceUseCase
    private let logger: AppLogger

    init(
        itemID: UUID,
        fetchDetail: FetchItemDetailUseCase,
        deleteItem: DeleteItemUseCase,
        toggleImportance: ToggleItemImportanceUseCase,
        logger: AppLogger
    ) {
        self.itemID = itemID
        self.fetchDetailUseCase = fetchDetail
        self.deleteItemUseCase = deleteItem
        self.toggleImportanceUseCase = toggleImportance
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let detail = try await fetchDetailUseCase.execute(itemID: itemID)
            state = .loaded(detail)
        } catch {
            logger.error("Item detail load failed", error: error, category: "item-detail")
            state = .failed(UserFacingError.from(error))
        }
    }

    func toggleImportance() async {
        guard !isTogglingImportance else { return }
        isTogglingImportance = true
        defer { isTogglingImportance = false }
        do {
            _ = try await toggleImportanceUseCase.execute(itemID: itemID)
            await load()
        } catch {
            logger.error("Toggle importance failed", error: error, category: "item-detail")
            mutationError = UserFacingError.from(error)
        }
    }

    /// Returns `true` on successful delete so the view can pop.
    func deleteItem() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await deleteItemUseCase.execute(itemID: itemID)
            return true
        } catch {
            logger.error("Item delete failed", error: error, category: "item-detail")
            mutationError = UserFacingError.from(error)
            return false
        }
    }
}
