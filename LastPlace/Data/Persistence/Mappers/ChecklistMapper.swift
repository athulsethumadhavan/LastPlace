//
//  ChecklistMapper.swift
//  LastPlace
//

import Foundation

enum ChecklistMapper {
    private enum TypeKind {
        static let work = "work"
        static let travel = "travel"
        static let gym = "gym"
        static let school = "school"
        static let custom = "custom"
    }

    static func toDomain(_ entity: ChecklistEntity) -> Checklist {
        Checklist(
            id: entity.id,
            name: entity.name,
            type: type(from: entity.typeKind, customLabel: entity.customLabel),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    static func toEntity(_ checklist: Checklist) -> ChecklistEntity {
        let (kind, label) = decompose(checklist.type)
        return ChecklistEntity(
            id: checklist.id,
            name: checklist.name,
            typeKind: kind,
            customLabel: label,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt
        )
    }

    static func apply(_ checklist: Checklist, to entity: ChecklistEntity) {
        let (kind, label) = decompose(checklist.type)
        entity.name = checklist.name
        entity.typeKind = kind
        entity.customLabel = label
        entity.updatedAt = checklist.updatedAt
    }

    private static func type(from kind: String, customLabel: String?) -> ChecklistType {
        switch kind {
        case TypeKind.work:   return .work
        case TypeKind.travel: return .travel
        case TypeKind.gym:    return .gym
        case TypeKind.school: return .school
        case TypeKind.custom: return .custom(customLabel ?? "Custom")
        default:              return .custom(customLabel ?? "Custom")
        }
    }

    private static func decompose(_ type: ChecklistType) -> (kind: String, label: String?) {
        switch type {
        case .work:              return (TypeKind.work, nil)
        case .travel:            return (TypeKind.travel, nil)
        case .gym:               return (TypeKind.gym, nil)
        case .school:            return (TypeKind.school, nil)
        case .custom(let label): return (TypeKind.custom, label)
        }
    }
}

enum ChecklistEntryMapper {
    static func toDomain(_ entity: ChecklistEntryEntity) -> ChecklistEntry {
        ChecklistEntry(
            id: entity.id,
            checklistID: entity.checklistID,
            title: entity.title,
            linkedItemID: entity.linkedItemID,
            locationDescription: entity.locationDescription,
            isCompleted: entity.isCompleted,
            sortOrder: entity.sortOrder
        )
    }

    static func toEntity(_ entry: ChecklistEntry) -> ChecklistEntryEntity {
        ChecklistEntryEntity(
            id: entry.id,
            checklistID: entry.checklistID,
            title: entry.title,
            linkedItemID: entry.linkedItemID,
            locationDescription: entry.locationDescription,
            isCompleted: entry.isCompleted,
            sortOrder: entry.sortOrder
        )
    }

    static func apply(_ entry: ChecklistEntry, to entity: ChecklistEntryEntity) {
        entity.checklistID = entry.checklistID
        entity.title = entry.title
        entity.linkedItemID = entry.linkedItemID
        entity.locationDescription = entry.locationDescription
        entity.isCompleted = entry.isCompleted
        entity.sortOrder = entry.sortOrder
    }
}
