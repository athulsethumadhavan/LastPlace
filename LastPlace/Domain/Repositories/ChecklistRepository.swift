//
//  ChecklistRepository.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol ChecklistRepository: Sendable {
    func fetchChecklists() async throws -> [Checklist]
    func fetchChecklist(id: UUID) async throws -> Checklist
    func fetchEntries(checklistID: UUID) async throws -> [ChecklistEntry]

    func create(_ checklist: Checklist) async throws -> Checklist
    func addEntry(_ entry: ChecklistEntry) async throws -> ChecklistEntry
    func updateEntry(_ entry: ChecklistEntry) async throws -> ChecklistEntry
    func toggle(entryID: UUID) async throws -> ChecklistEntry
    func resetChecklist(id: UUID) async throws
    func delete(checklistID: UUID) async throws
    func delete(entryID: UUID) async throws
}
