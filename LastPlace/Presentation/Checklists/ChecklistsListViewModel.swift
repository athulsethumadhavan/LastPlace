//
//  ChecklistsListViewModel.swift
//  LastPlace
//
//  Loads all checklists plus a completed/total count per checklist so the
//  list can show progress without the view reaching into the repository
//  itself.
//

import Foundation
import Observation

@Observable
@MainActor
final class ChecklistsListViewModel {
    struct Progress {
        let completed: Int
        let total: Int
    }

    private(set) var state: LoadableState<[Checklist]> = .idle
    private(set) var progressByChecklistID: [UUID: Progress] = [:]

    private let fetchChecklistsUseCase: FetchChecklistsUseCase
    private let deleteChecklistUseCase: DeleteChecklistUseCase
    private let checklistRepository: ChecklistRepository
    private let logger: AppLogger

    init(
        fetchChecklists: FetchChecklistsUseCase,
        deleteChecklist: DeleteChecklistUseCase,
        checklistRepository: ChecklistRepository,
        logger: AppLogger
    ) {
        self.fetchChecklistsUseCase = fetchChecklists
        self.deleteChecklistUseCase = deleteChecklist
        self.checklistRepository = checklistRepository
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let checklists = try await fetchChecklistsUseCase.execute()
            state = checklists.isEmpty ? .empty : .loaded(checklists)
            await loadProgress(for: checklists)
        } catch {
            logger.error("Checklists load failed", error: error, category: "checklists")
            state = .failed(UserFacingError.from(error))
        }
    }

    func refresh() async {
        await load()
    }

    func deleteChecklist(id: UUID) async {
        do {
            try await deleteChecklistUseCase.execute(id: id)
            await load()
        } catch {
            logger.error("Delete checklist failed", error: error, category: "checklists")
            state = .failed(UserFacingError.from(error))
        }
    }

    private func loadProgress(for checklists: [Checklist]) async {
        var result: [UUID: Progress] = [:]
        for checklist in checklists {
            if let entries = try? await checklistRepository.fetchEntries(checklistID: checklist.id) {
                result[checklist.id] = Progress(
                    completed: entries.filter(\.isCompleted).count,
                    total: entries.count
                )
            }
        }
        progressByChecklistID = result
    }
}
