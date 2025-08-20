import UIKit
import Photos

final class ImageCachingController {
    private let imageManager = PHCachingImageManager()
    private var previousPreheatRect: CGRect = .zero

    func reset() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }

    func requestThumbnail(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
            completion(image)
        }
    }

    func updateCaching(in collectionView: UICollectionView, with fetchResult: PHFetchResult<PHAsset>, targetSize: CGSize) {
        guard collectionView.isDragging || collectionView.isDecelerating else { return }
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)

        // Only update if the visible area is significantly different
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > collectionView.bounds.height / 3 else { return }

        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)

        let addedAssets = assets(in: addedRects, collectionView: collectionView, fetchResult: fetchResult)
        let removedAssets = assets(in: removedRects, collectionView: collectionView, fetchResult: fetchResult)

        imageManager.startCachingImages(for: addedAssets, targetSize: targetSize, contentMode: .aspectFill, options: nil)
        imageManager.stopCachingImages(for: removedAssets, targetSize: targetSize, contentMode: .aspectFill, options: nil)

        previousPreheatRect = preheatRect
    }

    private func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY { added += [CGRect(x: new.origin.x, y: old.maxY, width: new.width, height: new.maxY - old.maxY)] }
            if old.minY > new.minY { added += [CGRect(x: new.origin.x, y: new.minY, width: new.width, height: old.minY - new.minY)] }

            var removed = [CGRect]()
            if new.maxY < old.maxY { removed += [CGRect(x: new.origin.x, y: new.maxY, width: new.width, height: old.maxY - new.maxY)] }
            if old.minY < new.minY { removed += [CGRect(x: new.origin.x, y: old.minY, width: new.width, height: new.minY - old.minY)] }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }

    private func assets(in rects: [CGRect], collectionView: UICollectionView, fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        guard !rects.isEmpty else { return [] }
        let layoutAttributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: rects.reduce(CGRect.null) { $0.union($1) }) ?? []
        let indexPaths = layoutAttributes.map { $0.indexPath }
        var assets: [PHAsset] = []
        assets.reserveCapacity(indexPaths.count)
        for indexPath in indexPaths {
            if indexPath.item < fetchResult.count {
                assets.append(fetchResult.object(at: indexPath.item))
            }
        }
        return assets
    }
}

