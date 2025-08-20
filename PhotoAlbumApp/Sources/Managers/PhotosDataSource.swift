import Foundation
import Photos

struct AlbumItem {
    let collection: PHAssetCollection
    let title: String
    let estimatedCount: Int
    let keyAsset: PHAsset?
}

final class PhotosDataSource: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotosDataSource()

    private let imageManager = PHCachingImageManager()
    private var changeHandlers: [() -> Void] = []

    override private init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func onLibraryChange(_ handler: @escaping () -> Void) {
        changeHandlers.append(handler)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.changeHandlers.forEach { $0() }
        }
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded(_ completion: @escaping (PHAuthorizationStatus) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async { completion(newStatus) }
            }
        } else {
            completion(status)
        }
    }

    // MARK: - Albums

    func fetchAllAlbums() -> [AlbumItem] {
        var items: [AlbumItem] = []

        func addCollections(_ fetchResult: PHFetchResult<PHAssetCollection>) {
            fetchResult.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                guard assets.count > 0 else { return }
                let title = collection.localizedTitle ?? ""
                let keyAsset = PHAsset.fetchKeyAssets(in: collection, options: nil)?.firstObject
                let item = AlbumItem(collection: collection, title: title, estimatedCount: assets.count, keyAsset: keyAsset)
                items.append(item)
            }
        }

        // Smart Albums (系统智能相册)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        addCollections(smartAlbums)

        // User Albums (用户相册)
        let userAlbums = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            guard let album = collection as? PHAssetCollection else { return }
            let assets = PHAsset.fetchAssets(in: album, options: nil)
            guard assets.count > 0 else { return }
            let title = album.localizedTitle ?? ""
            let keyAsset = PHAsset.fetchKeyAssets(in: album, options: nil)?.firstObject
            let item = AlbumItem(collection: album, title: title, estimatedCount: assets.count, keyAsset: keyAsset)
            items.append(item)
        }

        // 去重（部分智能相册与用户相册可能重复显示）
        var seenLocalIds = Set<String>()
        items = items.filter { item in
            let id = item.collection.localIdentifier
            if seenLocalIds.contains(id) { return false }
            seenLocalIds.insert(id)
            return true
        }

        return items
    }

    // MARK: - Assets

    func fetchAssets(in collection: PHAssetCollection, sortByCreationDateAscending: Bool) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortByCreationDateAscending)]
        return PHAsset.fetchAssets(in: collection, options: options)
    }
}

