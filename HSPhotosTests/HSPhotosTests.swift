//
//  HSPhotosTests.swift
//  HSPhotosTests
//
//  Created by HQ on 2026/2/27.
//

import Testing
@testable import HSPhotos

@Suite("PhotoHierarchyService")
struct HSPhotosTests {

    private let sut = PhotoHierarchyService.shared

    @Test func nextIndex_fillsGapFirst() {
        #expect(sut.test_nextAvailableIndex(in: [1, 3]) == 2)
    }

    @Test func nextIndex_incrementsWhenNoGap() {
        #expect(sut.test_nextAvailableIndex(in: [1, 2, 3]) == 4)
    }

    @Test func nextChildIndex_usesFirstAvailableSiblingSlot() {
        let nodes: [String: PhotoHierarchyNode] = [
            "a": PhotoHierarchyNode(path: [1], isCollapsed: false),
            "b": PhotoHierarchyNode(path: [3], isCollapsed: false),
            "c": PhotoHierarchyNode(path: [1, 1], isCollapsed: false),
        ]
        #expect(sut.test_nextChildIndex(parentPath: [], nodes: nodes) == 2)
        #expect(sut.test_nextChildIndex(parentPath: [1], nodes: nodes) == 2)
    }

    @Test func setLevel_toRoot_fillsRootGap() throws {
        let ordered = ["a", "x", "b"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
            "b": .init(path: [3], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "x", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [2])
    }

    @Test func setLevel_sameRootLevel_doesNotBumpToNextIndex() throws {
        let ordered = ["x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "x": .init(path: [1], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "x", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [1])
    }

    @Test func setLevel_toChild_usesNearestValidParentLevel() throws {
        let ordered = ["a", "m", "x", "b"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
            "m": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [2], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "x", level: 2, orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [1, 2])
    }

    @Test func setLevel_missingParent_throwsError() {
        let ordered = ["a", "x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
        ]

        #expect(throws: PhotoHierarchyError.self) {
            _ = try sut.test_applySetLevel(assetID: "x", level: 3, orderedIDs: ordered, nodes: nodes)
        }
    }

    @Test func setLevel_invalidAsset_throwsError() {
        let ordered = ["a", "b"]
        let nodes: [String: PhotoHierarchyNode] = [:]

        #expect(throws: PhotoHierarchyError.self) {
            _ = try sut.test_applySetLevel(assetID: "x", level: 1, orderedIDs: ordered, nodes: nodes)
        }
    }

    @Test func relevel_toSibling_movesFollowingSiblingUnderNewNode() throws {
        let ordered = ["root", "a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: false),
            "c": .init(path: [1, 3], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "b", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.path == [2])
        #expect(result["c"]?.path == [2, 1])
    }

    @Test func relevel_preservesMovedSubtreeAndFollowingSubtree() throws {
        let ordered = ["root", "a", "b", "b1", "c", "c1"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: false),
            "b1": .init(path: [1, 2, 1], isCollapsed: false),
            "c": .init(path: [1, 3], isCollapsed: false),
            "c1": .init(path: [1, 3, 1], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "b", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.path == [2])
        #expect(result["b1"]?.path == [2, 1])
        #expect(result["c"]?.path == [2, 2])
        #expect(result["c1"]?.path == [2, 2, 1])
    }

    @Test func relevel_withSameParent_doesNotAbsorbFollowingSibling() throws {
        let ordered = ["root", "a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: false),
            "c": .init(path: [1, 3], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "b", level: 2, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.path.count == 2)
        #expect(result["c"]?.path.count == 2)
    }

    @Test func relevel_preservesCollapseFlags() throws {
        let ordered = ["root", "a", "b", "b1", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: true),
            "b1": .init(path: [1, 2, 1], isCollapsed: true),
            "c": .init(path: [1, 3], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevel(assetID: "b", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.isCollapsed == true)
        #expect(result["b1"]?.isCollapsed == true)
    }

    @Test func clearLevel_zero_removesWholeSubtree() throws {
        let ordered = ["a", "b", "c", "d"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
            "b": .init(path: [1, 1], isCollapsed: false),
            "c": .init(path: [1, 1, 1], isCollapsed: false),
            "d": .init(path: [2], isCollapsed: false),
        ]

        let result = try sut.test_applySetLevelOrClear(assetID: "b", level: 0, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"] == nil)
        #expect(result["c"] == nil)
        #expect(result["a"]?.path == [1])
        #expect(result["d"]?.path == [2])
    }

    @Test func batchSetLevel_reportsFailuresAndKeepsSuccesses() {
        let ordered = ["a", "x", "y"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
        ]

        let output = sut.test_applyBatchSetLevelOrClear(
            orderedIDs: ordered,
            selectedIDs: ["x", "y"],
            level: 3,
            nodes: nodes
        )

        #expect(output.failed.count == 2)
        #expect(output.nodes["x"] == nil)
        #expect(output.nodes["y"] == nil)
        #expect(output.nodes["a"]?.path == [1])
    }

    @Test func batchSetLevel_mixedSuccessAndFailure() {
        let ordered = ["x", "a", "y"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
        ]

        let output = sut.test_applyBatchSetLevelOrClear(
            orderedIDs: ordered,
            selectedIDs: ["x", "y"],
            level: 2,
            nodes: nodes
        )

        #expect(output.failed == ["x"])
        #expect(output.nodes["y"]?.path == [1, 1])
    }

    @Test func setLevel_invalidNegativeLevel_throwsError() {
        let ordered = ["a"]
        let nodes: [String: PhotoHierarchyNode] = ["a": .init(path: [1], isCollapsed: false)]

        #expect(throws: PhotoHierarchyError.self) {
            _ = try sut.test_applySetLevel(assetID: "a", level: -1, orderedIDs: ordered, nodes: nodes)
        }
    }

    @Test func setPath_decimalInput_setsExactPath() throws {
        let ordered = ["r", "x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "r": .init(path: [1], isCollapsed: false),
        ]

        let result = try sut.test_applySetPathOrClear(assetID: "x", path: [1, 2], orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [1, 2])
    }

    @Test func setPath_decimalInput_missingParent_throwsError() {
        let ordered = ["x"]
        let nodes: [String: PhotoHierarchyNode] = [:]

        #expect(throws: PhotoHierarchyError.self) {
            _ = try sut.test_applySetPathOrClear(assetID: "x", path: [1, 2], orderedIDs: ordered, nodes: nodes)
        }
    }

    @Test func setPath_decimalInput_occupiedPath_throwsError() {
        let ordered = ["r", "a", "x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "r": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 2], isCollapsed: false),
        ]

        #expect(throws: PhotoHierarchyError.self) {
            _ = try sut.test_applySetPathOrClear(assetID: "x", path: [1, 2], orderedIDs: ordered, nodes: nodes)
        }
    }

    @Test func setAsSiblingOfPrevious_doesNotAssignLevelToUnleveledMiddleItem() {
        let ordered = ["a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
        ]

        let result = sut.test_applySetAsSiblingOfPrevious(assetID: "c", orderedIDs: ordered, nodes: nodes)
        #expect(result["b"] == nil)
        #expect(result["c"]?.path == [2])
    }

    @Test func setAsChildOfPrevious_usesNearestLeveledParentWithoutPromotingMiddleItem() {
        let ordered = ["a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
        ]

        let result = sut.test_applySetAsChildOfPrevious(assetID: "c", orderedIDs: ordered, nodes: nodes)
        #expect(result["b"] == nil)
        #expect(result["c"]?.path == [1, 1])
    }
}
