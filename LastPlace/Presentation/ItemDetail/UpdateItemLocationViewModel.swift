//
//  UpdateItemLocationViewModel.swift
//  LastPlace
//
//  Backs the "update location" form. Two-phase lifecycle: load the current
//  item so we can pre-fill the description, then save via the domain
//  use case (which persists the new location and appends a snapshot).
//

import Foundation
import Observation

@Observable
@MainActor
final class UpdateItemLocationViewModel {
    let itemID: UUID
    var locationDescription: String = ""
    private(set) var loadState: LoadableState<StoredItem> = .idle
    private(set) var isSaving: Bool = false
    var error: UserFacingError?

    private let fetchDetail: FetchItemDetailUseCase
    private let updateLocation: UpdateItemLocationUseCase
    private let logger: AppLogger

    init(
        itemID: UUID,
        fetchDetail: FetchItemDetailUseCase,
        updateLocation: UpdateItemLocationUseCase,
        logger: AppLogger
    ) {
        self.itemID = itemID
        self.fetchDetail = fetchDetail
        self.updateLocation = updateLocation
        self.logger = logger
    }

    var canSave: Bool {
        let trimmed = locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSaving else { return false }
        if case .loaded(let item) = loadState, item.locationDescription == trimmed { return false }
        return true
    }

    func load() async {
        if case .loading = loadState { return }
        loadState = .loading
        do {
            let detail = try await fetchDetail.execute(itemID: itemID)
            locationDescription = detail.item.locationDescription
            loadState = .loaded(detail.item)
        } catch {
            logger.error("Update-location load failed", error: error, category: "update-location")
            loadState = .failed(UserFacingError.from(error))
        }
    }

    /// Returns `true` on success so the view can pop.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }

        let input = UpdateItemLocationInput(
            itemID: itemID,
            description: locationDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: nil,
            source: .manual,
            capturedAt: Date()
        )

        do {
            _ = try await updateLocation.execute(input)
            return true
        } catch {
            logger.error("Update-location save failed", error: error, category: "update-location")
            self.error = UserFacingError.from(error)
            return false
        }
    }
}
