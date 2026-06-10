//
//  PhotoNumberingLogicTests.swift
//  HSPhotosTests
//
//  多级编号、折叠可见性、后代判断、顺序校正（PhotoNumberingLogic）
//

import Testing
@testable import HSPhotos

@Suite("PhotoNumberingLogic")
struct PhotoNumberingLogicTests {

    // MARK: - 辅助（减少重复参数传递）

    private func visible(
        ordered: [String],
        levels: [String: Int],
        collapsed: [String: Bool],
        includeGaps: Bool
    ) -> [String] {
        PhotoNumberingLogic.visibleAssetIDs(
            orderedAssetIDs: ordered,
            levels: levels,
            collapsed: collapsed,
            includeGaps: includeGaps
        )
    }

    private func hasDescendants(
        assetID: String,
        ordered: [String],
        levels: [String: Int],
        spanMode: HierarchyCollapseSpanMode
    ) -> Bool {
        PhotoNumberingLogic.hasDescendants(
            assetID: assetID,
            orderedAssetIDs: ordered,
            levels: levels,
            spanMode: spanMode
        )
    }

    /// 折叠根 a、中间无编号 gap、深层子 b —— 多种断言共用同一拓扑
    private static let orderedGapDeepB = ["a", "gap", "b"]
    private static let levelsGapDeepB = ["a": 1, "gap": 0, "b": 2]
    private static let collapsedRootA = ["a": true]

    // MARK: - computeNumbers

    @Test func computeNumbers_skipsUnnumbered_andDeepJumpCorrected() {
        #expect(
            PhotoNumberingLogic.computeNumbers(orderedAssetIDs: ["a", "b", "c"], levels: ["a": 1, "c": 1])
                == ["a": "1", "c": "2"]
        )
        #expect(
            PhotoNumberingLogic.computeNumbers(orderedAssetIDs: ["x"], levels: ["x": 3])
                == ["x": "1"]
        )
    }

    @Test func computeNumbers_nestedAndSiblingResets() {
        let nested = PhotoNumberingLogic.computeNumbers(
            orderedAssetIDs: ["r", "c1", "c2", "r2"],
            levels: ["r": 1, "c1": 2, "c2": 2, "r2": 1]
        )
        #expect(nested == ["r": "1", "c1": "1.1", "c2": "1.2", "r2": "2"])

        let chain = PhotoNumberingLogic.computeNumbers(
            orderedAssetIDs: ["a", "b", "c", "d"],
            levels: ["a": 1, "b": 2, "c": 3, "d": 2]
        )
        #expect(chain == ["a": "1", "b": "1.1", "c": "1.1.1", "d": "1.2"])
    }

    // MARK: - visibleAssetIDs

    @Test func visible_collapsedHidesDeeperNumbered() {
        let v = visible(
            ordered: ["a", "b", "c"],
            levels: ["a": 1, "b": 2, "c": 1],
            collapsed: ["a": true],
            includeGaps: false
        )
        #expect(v == ["a", "c"])
    }

    @Test func visible_unnumberedBreaksCollapseWhenNotIncludeGaps() {
        let v = visible(
            ordered: Self.orderedGapDeepB,
            levels: Self.levelsGapDeepB,
            collapsed: Self.collapsedRootA,
            includeGaps: false
        )
        #expect(v == ["a", "gap", "b"])
    }

    @Test func visible_includeGaps_hidesGapAndFollowingDeeperWhileCollapsed() {
        let v = visible(
            ordered: Self.orderedGapDeepB,
            levels: Self.levelsGapDeepB,
            collapsed: Self.collapsedRootA,
            includeGaps: true
        )
        #expect(v == ["a"])
    }

    @Test func visible_includeGaps_showsGapWhenNextNumberedNotDeeper() {
        let v = visible(
            ordered: ["a", "gap", "sib"],
            levels: ["a": 1, "gap": 0, "sib": 1],
            collapsed: Self.collapsedRootA,
            includeGaps: true
        )
        #expect(v == ["a", "gap", "sib"])
    }

    // MARK: - hasDescendants

    @Test(arguments: [
        (HierarchyCollapseSpanMode.breakAtUnnumbered, false),
        (HierarchyCollapseSpanMode.includeGaps, true),
    ])
    func hasDescendants_gapBeforeLevel2Child_respectsSpanMode(
        spanMode: HierarchyCollapseSpanMode,
        expected: Bool
    ) {
        let has = hasDescendants(
            assetID: "a",
            ordered: Self.orderedGapDeepB,
            levels: Self.levelsGapDeepB,
            spanMode: spanMode
        )
        #expect(has == expected)
    }

    @Test func hasDescendants_breakAtUnnumbered_trueWhenDirectDeeper() {
        let has = hasDescendants(
            assetID: "a",
            ordered: ["a", "b"],
            levels: ["a": 1, "b": 2],
            spanMode: .breakAtUnnumbered
        )
        #expect(has == true)
    }

    @Test func hasDescendants_falseForUnnumberedRoot() {
        let has = hasDescendants(
            assetID: "x",
            ordered: ["x", "y"],
            levels: ["x": 0, "y": 1],
            spanMode: .includeGaps
        )
        #expect(has == false)
    }

    // MARK: - visibleHierarchyStep

    @Test func visibleHierarchyStep_expandsShallowestCollapsedLevel() {
        let ordered = ["r1", "c1", "r2"]
        let levels = ["r1": 1, "c1": 2, "r2": 1]
        let collapsed = ["r1": true, "r2": true]
        let visible: Set<String> = ["r1", "r2"]
        let next = PhotoNumberingLogic.applyVisibleHierarchyStep(
            expand: true,
            visibleIDs: visible,
            orderedAssetIDs: ordered,
            levels: levels,
            collapsed: collapsed,
            spanMode: .breakAtUnnumbered
        )
        #expect(next?["r1"] == nil)
        #expect(next?["r2"] == true)
    }

    // MARK: - hierarchy jump

    @Test func hierarchyJump_siblingAndLevelTargetsUseCurrentLevel() {
        let visible = ["one", "one_one", "one_two", "two"]
        let levels = ["one": 1, "one_one": 2, "one_two": 2, "two": 1]

        #expect(
            PhotoNumberingLogic.hierarchySiblingJumpTargets(
                visibleAssetIDs: visible,
                levels: levels,
                referenceIndex: 0
            ) == [0, 3]
        )
        #expect(
            PhotoNumberingLogic.hierarchyLevelJumpTarget(
                visibleAssetIDs: visible,
                levels: levels,
                referenceIndex: 0,
                direction: 1
            ) == 1
        )
        #expect(
            PhotoNumberingLogic.hierarchyLevelJumpTarget(
                visibleAssetIDs: visible,
                levels: levels,
                referenceIndex: 1,
                direction: -1
            ) == 0
        )
    }

    @Test func hierarchyJump_childDoesNotCrossSiblingBoundary() {
        let visible = ["one", "two", "two_one"]
        let levels = ["one": 1, "two": 1, "two_one": 2]

        #expect(
            PhotoNumberingLogic.hierarchyLevelJumpTarget(
                visibleAssetIDs: visible,
                levels: levels,
                referenceIndex: 0,
                direction: 1
            ) == nil
        )
    }

    // MARK: - reconcileLevelsWithOrder

    @Test func reconcile_correctsOvershoot_andPreservesValidChain() {
        let pulled = PhotoNumberingLogic.reconcileLevelsWithOrder(
            orderedAssetIDs: ["a", "b"],
            levels: ["a": 1, "b": 3]
        )
        #expect(pulled == ["a": 1, "b": 2])

        let chain = ["a": 1, "b": 2, "c": 3]
        let kept = PhotoNumberingLogic.reconcileLevelsWithOrder(orderedAssetIDs: ["a", "b", "c"], levels: chain)
        #expect(kept == chain)
    }
}
