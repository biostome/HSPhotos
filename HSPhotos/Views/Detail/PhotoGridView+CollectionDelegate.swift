//
//  PhotoGridView+CollectionDelegate.swift
//  HSPhotos
//

import UIKit
import Photos

// MARK: - UICollectionViewDelegate
extension PhotoGridView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
         guard indexPath.item < visibleAssets.count else { return }
         let photo = visibleAssets[indexPath.item]

         switch selectionMode {
         case .none:
             // 调用代理方法
             delegate?.photoGridView(self, didSelectItemAt: photo)
         case .multiple:
             handleMultipleSelection(at: indexPath, in: collectionView, with: photo)
         case .range:
             handleRangeSelection(at: indexPath, in: collectionView, with: photo)
         }
     }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard (selectionMode == .multiple || selectionMode == .range), indexPath.item < visibleAssets.count else { return }
        let photo = visibleAssets[indexPath.item]
        handleDeselection(at: indexPath, in: collectionView, with: photo)
    }

}

// MARK: - Helper Methods
extension PhotoGridView {
    private func handleMultipleSelection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击选择
        guard !isSlidingSelectionEnabled else { return }

        let wasSelected = selectionState.contains(photo.localIdentifier)
        let rankChanged = Set(toggle(photo: photo))
        let reloadIndexPaths = indexPathsMergingExplicitAndVisibleRankChanges(
            rankChangedIDs: rankChanged,
            explicit: [indexPath]
        )
        reloadItemsForSelectionChange(at: reloadIndexPaths) { _ in
            if wasSelected {
                self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
                self.delegate?.photoGridView(self, didDeselectItemAt: photo)
            } else {
                self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                self.delegate?.photoGridView(self, didSelectItemAt: photo)
            }
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
        }
    }

    private func handleRangeSelection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击选择
        guard !isSlidingSelectionEnabled else { return }

        let index = indexPath.item
        let isSelected = selectionState.contains(photo.localIdentifier)

        if isSelected {
            let rankChanged = Set(toggle(photo: photo))
            let reloadIndexPaths = indexPathsMergingExplicitAndVisibleRankChanges(
                rankChangedIDs: rankChanged,
                explicit: [indexPath]
            )
            reloadItemsForSelectionChange(at: reloadIndexPaths) { _ in
                self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
                self.delegate?.photoGridView(self, didDeselectItemAt: photo)
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
            }
            selectedStart = nil
            selectedEnd = nil
            return
        }

        if selectedStart == nil {
            // 第一次点击：设置开始位置，选中单个
            selectedStart = index
            _ = toggle(photo: photo)
            reloadItemsForSelectionChange(at: [indexPath]) { _ in
                self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                self.delegate?.photoGridView(self, didSelectItemAt: photo)
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
            }
        } else {
            // 第二次点击：设置结束位置，选中范围，重设范围
            selectedEnd = index

            // 检查范围内是否所有照片都已选中，如果是则执行反选，否则执行选中
            let startIndex = min(selectedStart!, selectedEnd!)
            let endIndex = max(selectedStart!, selectedEnd!)
            var allSelected = true

            for i in startIndex...endIndex {
                if i < visibleAssets.count {
                    let asset = visibleAssets[i]
                    if !selectionState.contains(asset.localIdentifier) {
                        allSelected = false
                        break
                    }
                }
            }

            if allSelected {
                // 范围内所有照片都已选中，执行反选
                deselectRange(from: startIndex, to: endIndex)
            } else {
                // 范围内有未选中的照片，执行选中
                let reverse = selectedEnd! < selectedStart!
                selectRange(from: startIndex, to: endIndex, reverse: reverse)
            }

            selectedStart = nil
            selectedEnd = nil
        }
    }

    private func handleDeselection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击取消选择
        guard !isSlidingSelectionEnabled else { return }

        let rankChanged = Set(toggle(photo: photo))
        let reloadIndexPaths = indexPathsMergingExplicitAndVisibleRankChanges(
            rankChangedIDs: rankChanged,
            explicit: [indexPath]
        )
        reloadItemsForSelectionChange(at: reloadIndexPaths) { _ in
            self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
            self.delegate?.photoGridView(self, didDeselectItemAt: photo)
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
        }
        selectedStart = nil
        selectedEnd = nil
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension PhotoGridView: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 如果 CollectionView 宽度和列数没有变化，直接返回缓存的尺寸
        if collectionView.bounds.width == lastCollectionViewWidth,
           let cachedSize = cachedCellSize {
            return cachedSize
        }

        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let sectionInset = flowLayout.sectionInset
        let interItemSpacing = flowLayout.minimumInteritemSpacing

        let totalSpacing = sectionInset.left + sectionInset.right + (CGFloat(columns - 1) * interItemSpacing)
        let width = max(1, (collectionView.bounds.width - totalSpacing) / CGFloat(columns))
        let size = CGSize(width: width, height: width)

        // 缓存结果
        cachedCellSize = size
        lastCollectionViewWidth = collectionView.bounds.width

        return size
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !isSlidingSelectionEnabled {
            scrollDelegate?.scrollViewDidScroll?(scrollView)
        }
    }

    // 新增：重写 scrollViewWillBeginDragging 方法来控制滚动
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 如果正在滑动选择，则阻止滚动
        if isSlidingSelectionEnabled {
            scrollView.isScrollEnabled = false
        }

        scrollDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    // 新增：重写 scrollViewDidEndDragging 方法来恢复滚动
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !isSlidingSelectionEnabled {
            scrollView.isScrollEnabled = true
        }
        scrollDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {

    }
}

// MARK: - UIGestureRecognizerDelegate
extension PhotoGridView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 不允许滑动手势和滚动同时进行
        return false
    }

    // 新增：控制手势识别的条件
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只处理pan手势
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }

        // 只有在选择模式下才考虑滑动选择
        guard selectionMode == .multiple || selectionMode == .range else { return false }

        // 检查手势的初始方向
        let velocity = panGesture.velocity(in: collectionView)
        let verticalVelocity = abs(velocity.y)
        let horizontalVelocity = abs(velocity.x)

        // 只有横向滑动才触发滑动选择，纵向滑动保持正常滚动
        return horizontalVelocity > verticalVelocity
    }

    // 新增：控制手势是否应该被取消
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 让滚动手势在滑动选择手势开始后失败，优先处理滑动选择
        if gestureRecognizer is UIPanGestureRecognizer,
           otherGestureRecognizer is UIPanGestureRecognizer,
           otherGestureRecognizer.view == collectionView {
            // 检查是否在选择模式下
            return selectionMode == .multiple || selectionMode == .range
        }
        return false
    }

    // 新增：控制手势是否应该取消其他手势
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldCancelOtherGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 当滑动选择手势开始时，取消滚动手势
        if gestureRecognizer is UIPanGestureRecognizer,
           otherGestureRecognizer is UIPanGestureRecognizer,
           otherGestureRecognizer.view == collectionView {
            // 检查是否在选择模式下
            return selectionMode == .multiple || selectionMode == .range
        }
        return false
    }
}
// MARK: - CustomVerticalScrollIndicatorDelegate
extension PhotoGridView: CustomVerticalScrollIndicatorDelegate {
    func scrollIndicator(_ indicator: CustomVerticalScrollIndicator, textForScrollProgress scrollProgress: CGFloat) -> String? {
        guard !visibleAssets.isEmpty else { return nil }

        // 根据滚动进度计算当前显示的照片索引
        let totalItems = visibleAssets.count
        let currentIndex = Int(scrollProgress * CGFloat(totalItems - 1))
        let clampedIndex = max(0, min(currentIndex, totalItems - 1))

        let asset = visibleAssets[clampedIndex]

        switch sortPreference {
        case .creationDate, .modificationDate, .recentDate, .oldest, .newest:
            // 日期排序：显示日期
            return formatDate(for: asset)
        case .custom:
            // 自定义排序：显示下标（从1开始）
            return "\(clampedIndex + 1)"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    private func formatDate(for asset: PHAsset) -> String {
        let date: Date
        switch sortPreference {
        case .creationDate,.oldest,.newest:
            date = asset.creationDate ?? Date()
        case .modificationDate, .recentDate:
            date = asset.modificationDate ?? asset.creationDate ?? Date()
        case .custom:
            date = asset.creationDate ?? Date()
        }

        return Self.dateFormatter.string(from: date)
    }

    // MARK: - 粘贴到此后方处理
    internal func handlePasteToAfter(asset: PHAsset, assets: [PHAsset]) {
        guard currentCollection != nil else { return }
        self.delegate?.photoGridView(self, didPasteAssets: assets, after: asset)
    }
}

