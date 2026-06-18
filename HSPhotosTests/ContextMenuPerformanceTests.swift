//
//  ContextMenuPerformanceTests.swift
//  HSPhotosTests
//
//  测量长按上下文菜单各环节在 50K 大相簿下的实际耗时
//

import Testing
import UIKit
import Photos
@testable import HSPhotos

// MARK: - Helpers

private func makeLargeIDs(_ count: Int) -> [String] {
    (0..<count).map { "asset-\($0)-\(UUID().uuidString)" }
}

private func makeLevels(for ids: [String], ratio: Double = 0.3) -> [String: Int] {
    var dict: [String: Int] = [:]
    dict.reserveCapacity(ids.count)
    for id in ids {
        let hasLevel = Double.random(in: 0...1) < ratio
        if hasLevel {
            dict[id] = Int.random(in: 1...4)
        }
    }
    return dict
}

@Suite("ContextMenu Performance")
struct ContextMenuPerformanceTests {

    // MARK: - hasDescendants(index variant) benchmark

    @Test func hasDescendants_at_50k_middleItem() {
        let n = 50_000
        let ids = makeLargeIDs(n)
        let levels = makeLevels(for: ids)

        // 取中间项，给它 level 1
        let midIdx = n / 2
        let midID = ids[midIdx]
        var modLevels = levels
        modLevels[midID] = 1

        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = PhotoNumberingLogic.hasDescendants(
                at: midIdx, level: 1,
                orderedAssetIDs: ids, levels: modLevels,
                spanMode: .includeGaps
            )
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations) * 1000
        print("[PERF] hasDescendants(at: 50k middle) avg=\(String(format: "%.3f", elapsed)) ms")
        #expect(elapsed < 5.0)  // must be under 5ms for fast touch response
    }

    @Test func hasDescendants_at_50k_earlyItem() {
        let n = 50_000
        let ids = makeLargeIDs(n)
        let levels = makeLevels(for: ids)

        let earlyIdx = 100
        let earlyID = ids[earlyIdx]
        var modLevels = levels
        modLevels[earlyID] = 2

        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = PhotoNumberingLogic.hasDescendants(
                at: earlyIdx, level: 2,
                orderedAssetIDs: ids, levels: modLevels,
                spanMode: .includeGaps
            )
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations) * 1000
        print("[PERF] hasDescendants(at: 50k early idx=100) avg=\(String(format: "%.3f", elapsed)) ms")
        #expect(elapsed < 5.0)
    }

    @Test func hasDescendants_at_50k_lastItem() {
        let n = 50_000
        let ids = makeLargeIDs(n)
        let levels = makeLevels(for: ids)

        let lastIdx = n - 1
        let lastID = ids[lastIdx]
        var modLevels = levels
        modLevels[lastID] = 1

        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = PhotoNumberingLogic.hasDescendants(
                at: lastIdx, level: 1,
                orderedAssetIDs: ids, levels: modLevels,
                spanMode: .includeGaps
            )
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations) * 1000
        print("[PERF] hasDescendants(at: 50k last) avg=\(String(format: "%.3f", elapsed)) ms")
        #expect(elapsed < 1.0)  // should be instant at last item
    }

    // MARK: - hasDescendants(firstIndex variant) benchmark for comparison

    @Test func hasDescendants_viaFirstIndex_50k_middleItem() {
        let n = 50_000
        let ids = makeLargeIDs(n)
        let levels = makeLevels(for: ids)

        let midIdx = n / 2
        let midID = ids[midIdx]
        var modLevels = levels
        modLevels[midID] = 1

        let iterations = 10  // only 10 because O(n)
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = PhotoNumberingLogic.hasDescendants(
                assetID: midID,
                orderedAssetIDs: ids,
                levels: modLevels,
                spanMode: .includeGaps
            )
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations) * 1000
        print("[PERF] hasDescendants(firstIndex 50k middle) avg=\(String(format: "%.3f", elapsed)) ms")
    }

    // MARK: - contextMenuPreviousLevel fallback benchmark

    @Test func contextMenuPreviousLevel_uncached_fallback() {
        let n = 50_000
        let ids = makeLargeIDs(n)
        let levels = makeLevels(for: ids)

        // 在末尾找一个 item（反向扫描最耗时）
        let targetIdx = 49_900

        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            // simulate the fallback path
            for idx in stride(from: targetIdx - 1, through: 0, by: -1) {
                let lv = levels[ids[idx]] ?? 0
                if lv > 0 { break }
            }
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations) * 1000
        print("[PERF] prevLevel uncached fallback(50k, pos=49900) avg=\(String(format: "%.3f", elapsed)) ms")
    }

    // MARK: - SF Symbol cold load

    @Test func sfSymbols_firstLoad() {
        let names = [
            "anchor.slash", "anchor", "tag", "doc.on.clipboard", "trash",
            "list.number", "arrow.right.to.line", "list.bullet.indent",
            "arrow.left", "arrow.right", "xmark.circle",
            "rectangle.expand.vertical", "rectangle.compress.vertical"
        ]
        let start = CFAbsoluteTimeGetCurrent()
        for name in names {
            _ = UIImage(systemName: name)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print("[PERF] SF Symbols first load total=\(String(format: "%.1f", elapsed)) ms")
    }

    // MARK: - Full context menu deferred block simulation

    @Test func fullDeferredBlock_buildAllMenuElements() {
        // Simulate what the deferred block does:
        // 1. Create UIActions with SF Symbol images
        // 2. Create UIMenus
        // 3. Create UIDeferredMenuElement
        let iterations = 10
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            // Build the full context menu structure
            _ = UIMenu(title: "", children: [
                UIMenu(title: "锚点", image: UIImage(systemName: "anchor"), options: .displayInline, children: [
                    UIAction(title: "取消锚点", image: UIImage(systemName: "anchor.slash")) { _ in },
                    UIAction(title: "设为锚点", image: UIImage(systemName: "anchor")) { _ in }
                ]),
                UIDeferredMenuElement { completion in
                    completion([UIMenu(title: "层级", options: .displayInline, children: [
                        UIAction(title: "设为主级", image: UIImage(systemName: "list.number")) { _ in },
                        UIAction(title: "提升层级", image: UIImage(systemName: "arrow.left")) { _ in },
                        UIAction(title: "下降层级", image: UIImage(systemName: "arrow.right")) { _ in }
                    ])])
                },
                UIMenu(title: "其他", options: .displayInline, children: [
                    UIAction(title: "添加标签", image: UIImage(systemName: "tag")) { _ in },
                    UIAction(title: "粘贴到此后方", image: UIImage(systemName: "doc.on.clipboard")) { _ in },
                    UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in }
                ])
            ])
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations) * 1000
        print("[PERF] fullDeferredBlock build avg=\(String(format: "%.1f", elapsed)) ms")
        #expect(elapsed < 50.0)
    }

    // MARK: - First-ever UIMenu/UIAction creation (cold path)

    @Test func firstMenuCreation_coldPath() {
        // This simulates the VERY first time UIMenu/UIAction/UIImage(systemName:) are called
        // in the app's lifetime - the true cold path
        let t0 = CFAbsoluteTimeGetCurrent()

        _ = UIAction(title: "Test", image: UIImage(systemName: "star")) { _ in }
        _ = UIMenu(title: "Menu", children: [])
        _ = UIDeferredMenuElement { completion in
            completion([UIMenu(title: "Submenu", options: .displayInline, children: [])])
        }
        _ = UIMenu(title: "", children: [])

        let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        print("[PERF] firstMenuCreation cold path total=\(String(format: "%.1f", elapsed)) ms")
    }
}
