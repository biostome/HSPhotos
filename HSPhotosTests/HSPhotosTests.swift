//
//  HSPhotosTests.swift
//  HSPhotosTests
//
//  Created by HQ on 2026/2/27.
//

import Testing
@testable import HSPhotos

struct HSPhotosTests {

    @Test func nextIndex_fillsGapFirst() async throws {
        let service = PhotoHierarchyService.shared
        let next = service.test_nextAvailableIndex(in: [1, 3])
        #expect(next == 2)
    }

    @Test func nextIndex_incrementsWhenNoGap() async throws {
        let service = PhotoHierarchyService.shared
        let next = service.test_nextAvailableIndex(in: [1, 2, 3])
        #expect(next == 4)
    }

    @Test func nextChildIndex_usesFirstAvailableSiblingSlot() async throws {
        let service = PhotoHierarchyService.shared
        let nodes: [String: PhotoHierarchyNode] = [
            "a": PhotoHierarchyNode(path: [1], isCollapsed: false),
            "b": PhotoHierarchyNode(path: [3], isCollapsed: false),
            "c": PhotoHierarchyNode(path: [1, 1], isCollapsed: false)
        ]
        let nextRoot = service.test_nextChildIndex(parentPath: [], nodes: nodes)
        let nextChildOfOne = service.test_nextChildIndex(parentPath: [1], nodes: nodes)

        #expect(nextRoot == 2)
        #expect(nextChildOfOne == 2)
    }

    @Test func setLevel_toRoot_fillsRootGap() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "x", "b"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
            "b": .init(path: [3], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "x", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [2])
    }

    @Test func setLevel_sameRootLevel_doesNotBumpToNextIndex() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "x": .init(path: [1], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "x", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [1])
    }

    @Test func setLevel_toChild_usesNearestValidParentLevel() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "m", "x", "b"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
            "m": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [2], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "x", level: 2, orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [1, 2])
    }

    @Test func setLevel_missingParent_throwsError() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false)
        ]

        do {
            _ = try service.test_applySetLevel(assetID: "x", level: 3, orderedIDs: ordered, nodes: nodes)
            Issue.record("Expected missing parent error")
        } catch {
            #expect(error is PhotoHierarchyError)
        }
    }

    @Test func setLevel_invalidAsset_throwsError() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "b"]
        let nodes: [String: PhotoHierarchyNode] = [:]

        do {
            _ = try service.test_applySetLevel(assetID: "x", level: 1, orderedIDs: ordered, nodes: nodes)
            Issue.record("Expected asset not found error")
        } catch {
            #expect(error is PhotoHierarchyError)
        }
    }

    @Test func relevel_toSibling_movesFollowingSiblingUnderNewNode() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["root", "a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: false),
            "c": .init(path: [1, 3], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "b", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.path == [2])
        #expect(result["c"]?.path == [2, 1])
    }

    @Test func relevel_preservesMovedSubtreeAndFollowingSubtree() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["root", "a", "b", "b1", "c", "c1"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: false),
            "b1": .init(path: [1, 2, 1], isCollapsed: false),
            "c": .init(path: [1, 3], isCollapsed: false),
            "c1": .init(path: [1, 3, 1], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "b", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.path == [2])
        #expect(result["b1"]?.path == [2, 1])
        #expect(result["c"]?.path == [2, 2])
        #expect(result["c1"]?.path == [2, 2, 1])
    }

    @Test func relevel_withSameParent_doesNotAbsorbFollowingSibling() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["root", "a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: false),
            "c": .init(path: [1, 3], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "b", level: 2, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.path.count == 2)
        #expect(result["c"]?.path.count == 2)
    }

    @Test func relevel_preservesCollapseFlags() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["root", "a", "b", "b1", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "root": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 1], isCollapsed: false),
            "b": .init(path: [1, 2], isCollapsed: true),
            "b1": .init(path: [1, 2, 1], isCollapsed: true),
            "c": .init(path: [1, 3], isCollapsed: false)
        ]

        let result = try service.test_applySetLevel(assetID: "b", level: 1, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"]?.isCollapsed == true)
        #expect(result["b1"]?.isCollapsed == true)
    }

    @Test func clearLevel_zero_removesWholeSubtree() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "b", "c", "d"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false),
            "b": .init(path: [1, 1], isCollapsed: false),
            "c": .init(path: [1, 1, 1], isCollapsed: false),
            "d": .init(path: [2], isCollapsed: false)
        ]

        let result = try service.test_applySetLevelOrClear(assetID: "b", level: 0, orderedIDs: ordered, nodes: nodes)
        #expect(result["b"] == nil)
        #expect(result["c"] == nil)
        #expect(result["a"]?.path == [1])
        #expect(result["d"]?.path == [2])
    }

    @Test func batchSetLevel_reportsFailuresAndKeepsSuccesses() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "x", "y"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false)
        ]

        let output = service.test_applyBatchSetLevelOrClear(
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

    @Test func batchSetLevel_mixedSuccessAndFailure() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["x", "a", "y"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false)
        ]

        let output = service.test_applyBatchSetLevelOrClear(
            orderedIDs: ordered,
            selectedIDs: ["x", "y"],
            level: 2,
            nodes: nodes
        )

        #expect(output.failed == ["x"])
        #expect(output.nodes["y"]?.path == [1, 1])
    }

    @Test func setLevel_invalidNegativeLevel_throwsError() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a"]
        let nodes: [String: PhotoHierarchyNode] = ["a": .init(path: [1], isCollapsed: false)]

        do {
            _ = try service.test_applySetLevel(assetID: "a", level: -1, orderedIDs: ordered, nodes: nodes)
            Issue.record("Expected invalid level error")
        } catch {
            #expect(error is PhotoHierarchyError)
        }
    }

    @Test func setPath_decimalInput_setsExactPath() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["r", "x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "r": .init(path: [1], isCollapsed: false)
        ]

        let result = try service.test_applySetPathOrClear(assetID: "x", path: [1, 2], orderedIDs: ordered, nodes: nodes)
        #expect(result["x"]?.path == [1, 2])
    }

    @Test func setPath_decimalInput_missingParent_throwsError() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["x"]
        let nodes: [String: PhotoHierarchyNode] = [:]

        do {
            _ = try service.test_applySetPathOrClear(assetID: "x", path: [1, 2], orderedIDs: ordered, nodes: nodes)
            Issue.record("Expected missing parent path error")
        } catch {
            #expect(error is PhotoHierarchyError)
        }
    }

    @Test func setPath_decimalInput_occupiedPath_throwsError() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["r", "a", "x"]
        let nodes: [String: PhotoHierarchyNode] = [
            "r": .init(path: [1], isCollapsed: false),
            "a": .init(path: [1, 2], isCollapsed: false)
        ]

        do {
            _ = try service.test_applySetPathOrClear(assetID: "x", path: [1, 2], orderedIDs: ordered, nodes: nodes)
            Issue.record("Expected occupied path error")
        } catch {
            #expect(error is PhotoHierarchyError)
        }
    }

    @Test func setAsSiblingOfPrevious_doesNotAssignLevelToUnleveledMiddleItem() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false)
        ]

        let result = service.test_applySetAsSiblingOfPrevious(assetID: "c", orderedIDs: ordered, nodes: nodes)
        #expect(result["b"] == nil)
        #expect(result["c"]?.path == [2])
    }

    @Test func setAsChildOfPrevious_usesNearestLeveledParentWithoutPromotingMiddleItem() async throws {
        let service = PhotoHierarchyService.shared
        let ordered = ["a", "b", "c"]
        let nodes: [String: PhotoHierarchyNode] = [
            "a": .init(path: [1], isCollapsed: false)
        ]

        let result = service.test_applySetAsChildOfPrevious(assetID: "c", orderedIDs: ordered, nodes: nodes)
        #expect(result["b"] == nil)
        #expect(result["c"]?.path == [1, 1])
    }

}
