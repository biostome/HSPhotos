//
//  PhotoGridView+SelectionQuickNav.swift
//  HSPhotos
//

import UIKit
import Photos

// MARK: - 选择模式快速定位（连续块头 / 尾）

extension PhotoGridView {

    /// 将链式锚点对齐到「选中序号最大」（最近选入）的格；无选中或非选择模式时清空。
    /// 若该格在头尾目标链上无法向两侧移动（如只选一张且唯一目标即自身），则置 `nil`，改用视口边界判断可用性，避免两键全灰。
    func syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset() {
        var newJump: Int?
        defer {
            selectionQuickNavJumpIndex = newJump
            postSelectionQuickNavToolbarRefresh()
        }
        guard selectionQuickNavIsActive, selectionState.count > 0,
              let lastID = selectionState.orderedIDs.last,
              let idx = visibleAssets.firstIndex(where: { $0.localIdentifier == lastID }) else {
            return
        }
        let targets = selectionQuickNavSortedTargetIndices()
        let canMoveAlongTargets = targets.contains { $0 < idx } || targets.contains { $0 > idx }
        newJump = canMoveAlongTargets ? idx : nil
    }

    func syncSelectionQuickNavBarButtons(previous: UIBarButtonItem, next: UIBarButtonItem) {
        guard selectionQuickNavIsActive else {
            selectionQuickNavSetBarButtons(previous: previous, next: next, canPrev: false, canNext: false)
            return
        }
        let targets = selectionQuickNavSortedTargetIndices()
        guard !targets.isEmpty else {
            selectionQuickNavSetBarButtons(previous: previous, next: next, canPrev: false, canNext: false)
            return
        }
        let (vmin, vmax) = selectionQuickNavVisibleItemBounds()
        let (canPrev, canNext) = selectionQuickNavAvailability(targets: targets, vmin: vmin, vmax: vmax)
        selectionQuickNavSetBarButtons(previous: previous, next: next, canPrev: canPrev, canNext: canNext)
    }

    func performSelectionQuickNavPrevious() {
        performSelectionQuickNav(step: .towardLowerIndex)
    }

    func performSelectionQuickNavNext() {
        performSelectionQuickNav(step: .towardHigherIndex)
    }

    private enum SelectionQuickNavStep {
        case towardLowerIndex
        case towardHigherIndex
    }

    private func performSelectionQuickNav(step: SelectionQuickNavStep) {
        guard selectionQuickNavIsActive else { return }
        let targets = selectionQuickNavSortedTargetIndices()
        guard !targets.isEmpty else { return }

        let (vmin, vmax) = selectionQuickNavVisibleItemBounds()
        guard let index = selectionQuickNavDestination(targets: targets, step: step, vmin: vmin, vmax: vmax) else { return }

        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        selectionQuickNavJumpIndex = index
        postSelectionQuickNavToolbarRefresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.selectionQuickNavHighlightDelay) { [weak self] in
            guard let self else { return }
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell else { return }
            cell.performQuickNavigationHighlightAnimation()
        }
    }

    /// 所有连续选中块：每块贡献「头」；块内多于一张时再贡献「尾」。按可见顺序去重排序。
    private func selectionQuickNavSortedTargetIndices() -> [Int] {
        guard selectionQuickNavIsActive else { return [] }
        let ids = selectionState.selectedIdentifierSet
        guard !ids.isEmpty else { return [] }

        var result = Set<Int>()
        var i = 0
        while i < visibleAssets.count {
            guard ids.contains(visibleAssets[i].localIdentifier) else {
                i += 1
                continue
            }
            let range = selectionQuickNavExpandContiguousRange(from: i, selectedIDs: ids)
            result.insert(range.lowerBound)
            if range.lowerBound != range.upperBound {
                result.insert(range.upperBound)
            }
            i = range.upperBound + 1
        }
        return Array(result).sorted()
    }

    private func selectionQuickNavExpandContiguousRange(from anchor: Int, selectedIDs: Set<String>) -> ClosedRange<Int> {
        var lo = anchor
        var hi = anchor
        while lo > 0, selectedIDs.contains(visibleAssets[lo - 1].localIdentifier) {
            lo -= 1
        }
        while hi + 1 < visibleAssets.count, selectedIDs.contains(visibleAssets[hi + 1].localIdentifier) {
            hi += 1
        }
        return lo...hi
    }

    private static let selectionQuickNavHighlightDelay: TimeInterval = 0.32

    private var selectionQuickNavIsActive: Bool {
        selectionMode == .multiple || selectionMode == .range
    }

    private func postSelectionQuickNavToolbarRefresh() {
        onSelectionQuickNavToolbarRefresh?()
    }

    private func selectionQuickNavVisibleItemBounds() -> (min: Int, max: Int) {
        let items = collectionView.indexPathsForVisibleItems.map(\.item)
        return (items.min() ?? 0, items.max() ?? 0)
    }

    private func selectionQuickNavSetBarButtons(previous: UIBarButtonItem, next: UIBarButtonItem, canPrev: Bool, canNext: Bool) {
        previous.isEnabled = canPrev
        next.isEnabled = canNext
    }

    private func selectionQuickNavDestination(targets: [Int], step: SelectionQuickNavStep, vmin: Int, vmax: Int) -> Int? {
        switch step {
        case .towardLowerIndex:
            if let last = selectionQuickNavJumpIndex {
                return targets.last { $0 < last }
            }
            return targets.last { $0 < vmax }
        case .towardHigherIndex:
            if let last = selectionQuickNavJumpIndex {
                return targets.first { $0 > last }
            }
            return targets.first { $0 > vmin }
        }
    }

    private func selectionQuickNavAvailability(targets: [Int], vmin: Int, vmax: Int) -> (canPrev: Bool, canNext: Bool) {
        if let last = selectionQuickNavJumpIndex {
            return (targets.contains { $0 < last }, targets.contains { $0 > last })
        }
        return (targets.contains { $0 < vmax }, targets.contains { $0 > vmin })
    }
}
