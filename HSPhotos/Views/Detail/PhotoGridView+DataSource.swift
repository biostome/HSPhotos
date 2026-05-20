//
//  PhotoGridView+DataSource.swift
//  HSPhotos
//

import UIKit
import Photos

// MARK: - UICollectionViewDataSourcePrefetching
extension PhotoGridView: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let cellSize = effectiveCellSize(for: collectionView)
        let scale = collectionView.window?.screen.scale ?? collectionView.traitCollection.displayScale
        let targetSize = PhotoCell.thumbnailSize(for: cellSize, scale: scale)
        let assets = indexPaths.compactMap { $0.item < visibleAssets.count ? visibleAssets[$0.item] : nil }
        guard !assets.isEmpty else { return }
        PhotoCell.cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: PhotoCell.thumbnailOptionsFast
        )
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let cellSize = effectiveCellSize(for: collectionView)
        let scale = collectionView.window?.screen.scale ?? collectionView.traitCollection.displayScale
        let targetSize = PhotoCell.thumbnailSize(for: cellSize, scale: scale)
        let assets = indexPaths.compactMap { $0.item < visibleAssets.count ? visibleAssets[$0.item] : nil }
        guard !assets.isEmpty else { return }
        PhotoCell.cachingManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: PhotoCell.thumbnailOptionsFast
        )
    }

    private func effectiveCellSize(for collectionView: UICollectionView) -> CGSize {
        if let cached = cachedCellSize, collectionView.bounds.width == lastCollectionViewWidth {
            return cached
        }
        let sectionInset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let spacing = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? PhotoGridConstants.defaultSpacing
        let totalSpacing = sectionInset.left + sectionInset.right + (CGFloat(columns - 1) * spacing)
        let width = max(1, (collectionView.bounds.width - totalSpacing) / CGFloat(columns))
        return CGSize(width: width, height: width)
    }
}

