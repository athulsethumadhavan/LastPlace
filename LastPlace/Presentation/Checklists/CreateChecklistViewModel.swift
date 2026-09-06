//
//  CreateChecklistViewModel.swift
//  LastPlace
//

import Foundation
import Observation

@Observable
@MainActor
final class CreateChecklistViewModel {
    static let presetTypes: [ChecklistType] = [.work, .travel, .gym, .school]

    var name: String = ""
    var selectedPreset: ChecklistType = .work
    var isCustomType: Bool = false
    var customTypeName: String = ""
    var isSaving: Bool = false
    var error: UserFacingError?

    private let createChecklistUseCase: CreateChecklistUseCase
    private let logger: AppLogger

    init(createChecklist: CreateChecklistUseCase, logger: AppLogger) {
        self.createChecklistUseCase = createChecklist
        self.logger = logger
    }

    var resolvedType: ChecklistType {
        isCustomType
            ? .custom(customTypeName.trimmingCharacters(in: .whitespacesAndNewlines))
            : selectedPreset
    }

    var canSave: Bool {
        guard !isSaving else { return false }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if isCustomType {
            return !customTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    /// Returns the newly-created `Checklist` so the caller can pop.
    func save() async -> Checklist? {
        guard canSave else { return nil }
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            return try await createChecklistUseCase.execute(name: name, type: resolvedType)
        } catch {
            logger.error("Create checklist failed", error: error, category: "create-checklist")
            self.error = UserFacingError.from(error)
            return nil
        }
    }
}
