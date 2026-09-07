//
//  EntitlementStatusTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class EntitlementStatusTests: XCTestCase {
    func test_canAddItem_whenPremium_isAlwaysTrue() {
        let status = EntitlementStatus.premium
        XCTAssertNil(status.remainingItemSlots)
        XCTAssertTrue(status.canAddItem)
        XCTAssertNil(status.itemsUsed, "Premium has nothing meaningful to show for usage")
    }

    func test_canAddItem_whenFreeWithSlotsRemaining_isTrue() {
        let status = EntitlementStatus(isPremium: false, remainingItemSlots: 3)
        XCTAssertTrue(status.canAddItem)
        XCTAssertEqual(status.itemsUsed, EntitlementStatus.freeItemLimit - 3)
    }

    func test_canAddItem_whenFreeExhausted_isFalse() {
        let status = EntitlementStatus.freeExhausted
        XCTAssertFalse(status.canAddItem)
        XCTAssertEqual(status.itemsUsed, EntitlementStatus.freeItemLimit)
    }

    func test_defaultFreeStatus_hasFullAllowance() {
        let status = EntitlementStatus.free
        XCTAssertFalse(status.isPremium)
        XCTAssertEqual(status.remainingItemSlots, EntitlementStatus.freeItemLimit)
        XCTAssertEqual(status.itemsUsed, 0)
    }

    func test_mockEntitlementService_degradesToFreeOnLookupFailure() async {
        let service = MockEntitlementService(status: .premium)
        service.lookupError = EntitlementError.notAuthenticated

        let result = await service.statusOrFree()

        XCTAssertEqual(result, .free)
    }

    func test_mockEntitlementService_returnsSeededStatusWhenLookupSucceeds() async {
        let service = MockEntitlementService(status: .premium)
        let result = await service.statusOrFree()
        XCTAssertEqual(result, .premium)
    }

    func test_paywallReason_titlesAndMessagesAreNonEmptyForEveryCase() {
        let allReasons: [PaywallReason] = [.itemLimitReached, .aiIdentification, .sendGift, .acceptGiftAtLimit]
        for reason in allReasons {
            XCTAssertFalse(reason.title.isEmpty, "\(reason) should have a title")
            XCTAssertFalse(reason.message.isEmpty, "\(reason) should have a message")
            XCTAssertEqual(reason.id, reason.rawValue)
        }
    }

    func test_paywallReason_itemLimitReached_mentionsTheFreeLimit() {
        let reason = PaywallReason.itemLimitReached
        XCTAssertTrue(reason.title.contains("\(EntitlementStatus.freeItemLimit)"))
    }
}
