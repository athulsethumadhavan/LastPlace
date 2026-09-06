//
//  DataManagementViewModel.swift
//  LastPlace
//

import Foundation
import Observation

@Observable
@MainActor
final class DataManagementViewModel {
    private(set) var state: LoadableState<DataSummary> = .idle
    private(set) var isDeleting: Bool = false
    var error: UserFacingError?

    private let fetchSummaryUseCase: FetchDataSummaryUseCase
    private let deleteAllDataUseCase: DeleteAllDataUseCase
    private let logger: AppLogger

    init(
        fetchSummary: FetchDataSummaryUseCase,
        deleteAllData: DeleteAllDataUseCase,
        logger: AppLogger
    ) {
        self.fetchSummaryUseCase = fetchSummary
        self.deleteAllDataUseCase = deleteAllData
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let summary = try await fetchSummaryUseCase.execute()
            state = .loaded(summary)
        } catch {
            logger.error("Data summary load failed", error: error, category: "data-management")
            state = .failed(UserFacingError.from(error))
        }
    }

    /// Returns `true` on success so the view can confirm and the coordinator
    /// can refresh the other tabs.
    func deleteAll() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        error = nil
        defer { isDeleting = false }

        do {
            try await deleteAllDataUseCase.execute()
            await load()
            return true
        } catch {
            logger.error("Delete all data failed", error: error, category: "data-management")
            self.error = UserFacingError.from(error)
            return false
        }
    }
}
