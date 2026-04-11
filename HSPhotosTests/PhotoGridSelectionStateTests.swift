//
//  PhotoGridSelectionStateTests.swift
//  HSPhotosTests
//

import Testing
@testable import HSPhotos

@Suite("PhotoGridSelectionState")
struct PhotoGridSelectionStateTests {

    @Test func toggle_addsFirstRankOne() {
        var s = PhotoGridSelectionState()
        #expect(s.toggle(id: "a") == [])
        #expect(s.rank(for: "a") == 1)
        #expect(s.count == 1)
        #expect(s.orderedIDs == ["a"])
    }

    @Test func toggle_addSecondGetsRankTwo() {
        var s = PhotoGridSelectionState()
        _ = s.toggle(id: "a")
        _ = s.toggle(id: "b")
        #expect(s.rank(for: "a") == 1)
        #expect(s.rank(for: "b") == 2)
        #expect(s.orderedIDs == ["a", "b"])
    }

    @Test func toggle_removeLast_doesNotReturnUpdatedOthers() {
        var s = PhotoGridSelectionState()
        _ = s.toggle(id: "a")
        _ = s.toggle(id: "b")
        let updated = s.toggle(id: "b")
        #expect(updated == [])
        #expect(s.contains("b") == false)
        #expect(s.rank(for: "a") == 1)
    }

    @Test func toggle_removeFirst_renumbersOthers_andReturnsUpdated() {
        var s = PhotoGridSelectionState()
        _ = s.toggle(id: "a")
        _ = s.toggle(id: "b")
        _ = s.toggle(id: "c")
        let updated = s.toggle(id: "a")
        #expect(Set(updated) == Set(["b", "c"]))
        #expect(s.rank(for: "b") == 1)
        #expect(s.rank(for: "c") == 2)
        #expect(s.orderedIDs == ["b", "c"])
    }

    @Test func toggle_removeMiddle_renumbersOnlyAfter() {
        var s = PhotoGridSelectionState()
        _ = s.toggle(id: "a")
        _ = s.toggle(id: "b")
        _ = s.toggle(id: "c")
        let updated = s.toggle(id: "b")
        #expect(Set(updated) == Set(["c"]))
        #expect(s.rank(for: "a") == 1)
        #expect(s.rank(for: "c") == 2)
    }

    @Test func selectAll_thenDeselectFirst_noCrash_40k() {
        let n = 40_000
        let ids = (0..<n).map { "p\($0)" }
        var s = PhotoGridSelectionState()
        s.replaceAll(orderedIDs: ids)
        #expect(s.count == n)
        #expect(s.rank(for: "p0") == 1)
        let updated = s.toggle(id: "p0")
        #expect(updated.count == n - 1)
        #expect(s.rank(for: "p1") == 1)
        #expect(s.rank(for: "p\(n - 1)") == n - 1)
        #expect(s.count == n - 1)
    }

    @Test func replaceAll_matchesGridSelectAllSemantics() {
        var s = PhotoGridSelectionState()
        s.replaceAll(orderedIDs: ["x", "y", "z"])
        #expect(s.orderedIDs == ["x", "y", "z"])
        #expect(s.rank(for: "y") == 2)
        #expect(s.selectedIdentifierSet == Set(["x", "y", "z"]))
    }

    @Test func clear_removesEverything() {
        var s = PhotoGridSelectionState()
        s.replaceAll(orderedIDs: ["a", "b"])
        s.clear()
        #expect(s.count == 0)
        #expect(s.orderedIDs.isEmpty)
    }

    @Test func insertIfAbsent_skipsWhenAlreadySelected() {
        var s = PhotoGridSelectionState()
        let first = s.insertIfAbsent(id: "a")
        let second = s.insertIfAbsent(id: "a")
        #expect(first == true)
        #expect(second == false)
        #expect(s.count == 1)
    }

    @Test func insertIfAbsent_appendsIncreasingRanks() {
        var s = PhotoGridSelectionState()
        let addedA = s.insertIfAbsent(id: "a")
        let addedB = s.insertIfAbsent(id: "b")
        #expect(addedA == true)
        #expect(addedB == true)
        #expect(s.rank(for: "a") == 1)
        #expect(s.rank(for: "b") == 2)
    }

    @Test func removeIdentifierWithoutRankShift_leavesGaps() {
        var s = PhotoGridSelectionState()
        s.replaceAll(orderedIDs: ["a", "b", "c"])
        s.removeIdentifierWithoutRankShift(id: "b")
        #expect(s.contains("a"))
        #expect(s.contains("b") == false)
        #expect(s.contains("c"))
        #expect(s.rank(for: "a") == 1)
        #expect(s.rank(for: "c") == 3)
    }

    @Test func ranksAlwaysFormSubsetOfOneToCount_whenOnlyToggleAndReplaceAll() {
        var s = PhotoGridSelectionState()
        s.replaceAll(orderedIDs: (0..<20).map { "i\($0)" })
        _ = s.toggle(id: "i5")
        _ = s.toggle(id: "i3")
        _ = s.toggle(id: "i10")
        let ranks = s.orderedIDs.compactMap { s.rank(for: $0) }
        #expect(ranks.sorted() == Array(1...s.count))
    }

    @Test func toggle_twiceOnSameId_selectThenDeselect() {
        var s = PhotoGridSelectionState()
        _ = s.toggle(id: "a")
        _ = s.toggle(id: "a")
        #expect(s.count == 0)
    }
}
