//
//  PhotoAnchorSortLogic.swift
//  HSPhotos
//

import Photos

enum PhotoSortError: Error, LocalizedError {
    case notEnoughPhotosSelected
    case anchorPhotoMissing

    var errorDescription: String? {
        switch self {
        case .notEnoughPhotosSelected:
            return "至少需要选择两张照片才能进行排序。"
        case .anchorPhotoMissing:
            return "内部错误：无法在照片数组中找到作为排序基准的锚点照片。"
        }
    }
}

/// 锚点排序：将选中照片按选中顺序插入到锚点（或首张选中）之后。
enum PhotoAnchorSortLogic {
    static func sortedAssets(
        in assets: [PHAsset],
        selectedPhotos: [PHAsset],
        anchorPhoto: PHAsset?
    ) throws -> [PHAsset] {
        guard selectedPhotos.count > 1 else {
            throw PhotoSortError.notEnoughPhotosSelected
        }

        let anchor: PHAsset
        if let anchorPhoto {
            anchor = anchorPhoto
        } else {
            anchor = selectedPhotos[0]
        }

        let photosToMove = selectedPhotos.filter { $0.localIdentifier != anchor.localIdentifier }
        let identifiersToMove = Set(photosToMove.map(\.localIdentifier))
        var result = assets.filter { !identifiersToMove.contains($0.localIdentifier) }

        guard let anchorIndex = result.firstIndex(of: anchor) else {
            throw PhotoSortError.anchorPhotoMissing
        }

        result.insert(contentsOf: photosToMove, at: anchorIndex + 1)
        return result
    }
}
