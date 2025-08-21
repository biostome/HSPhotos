import Foundation
import Photos

final class ExperimentalDuplicateSorter {
    struct Config {
        let newAlbumTitle: String
        let startDate: Date
        let stepSeconds: Int
    }

    static func rebuildAsNewAlbum(from sourceCollection: PHAssetCollection,
                                  orderedAssetIds: [String],
                                  config: Config,
                                  progress: ((Int, Int) -> Void)? = nil,
                                  completion: @escaping (Bool, Error?) -> Void) {
        // 仅处理照片，忽略视频/Live（可后续扩展）
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: orderedAssetIds, options: nil)
        var assetsOrdered: [PHAsset] = []
        let map = Dictionary(uniqueKeysWithValues: (0..<fetch.count).map { (fetch.object(at: $0).localIdentifier, fetch.object(at: $0)) })
        for id in orderedAssetIds { if let a = map[id], a.mediaType == .image { assetsOrdered.append(a) } }

        let total = assetsOrdered.count
        guard total > 0 else {
            completion(false, NSError(domain: "ExperimentalDuplicateSorter", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有可处理的照片资源"]))
            return
        }

        // 导出为临时文件
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ExperimentalDuplicateSorter.export")
        var tempURLs: [URL?] = Array(repeating: nil, count: total)
        var exportError: Error?

        for (idx, asset) in assetsOrdered.enumerated() {
            group.enter()
            queue.async {
                let resources = PHAssetResource.assetResources(for: asset)
                guard let res = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first else {
                    exportError = NSError(domain: "ExperimentalDuplicateSorter", code: -2, userInfo: [NSLocalizedDescriptionKey: "未找到资源数据"])
                    group.leave()
                    return
                }
                let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                let opts = PHAssetResourceRequestOptions()
                opts.isNetworkAccessAllowed = true
                PHAssetResourceManager.default().writeData(for: res, toFile: tmpURL, options: opts) { err in
                    if let err = err { exportError = err }
                    tempURLs[idx] = tmpURL
                    DispatchQueue.main.async { progress?(idx + 1, total) }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if let err = exportError {
                completion(false, err)
                return
            }

            // 统一创建新相册+新资源并插入
            var albumPlaceholder: PHObjectPlaceholder?
            var assetPlaceholders: [PHObjectPlaceholder] = []
            PHPhotoLibrary.shared().performChanges({
                let createAlbum = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: config.newAlbumTitle)
                albumPlaceholder = createAlbum.placeholderForCreatedAssetCollection

                for (i, urlOpt) in tempURLs.enumerated() {
                    guard let fileURL = urlOpt else { continue }
                    let req = PHAssetCreationRequest()
                    let date = config.startDate.addingTimeInterval(TimeInterval(i * config.stepSeconds))
                    req.creationDate = date
                    let addOpts = PHAssetResourceCreationOptions()
                    req.addResource(with: .photo, fileURL: fileURL, options: addOpts)
                    if let ph = req.placeholderForCreatedAsset { assetPlaceholders.append(ph) }
                }

                if let albumPh = albumPlaceholder, let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumPh.localIdentifier], options: nil).firstObject {
                    let change = PHAssetCollectionChangeRequest(for: album)
                    let indexes = IndexSet(0..<assetPlaceholders.count)
                    change?.insertAssets(assetPlaceholders as NSArray, at: indexes)
                }
            }) { success, error in
                // 清理临时文件
                for urlOpt in tempURLs { if let u = urlOpt { try? FileManager.default.removeItem(at: u) } }
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}

