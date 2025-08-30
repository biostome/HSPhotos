//
//  PhotoCopyService.swift
//  HSPhotos
//

import Photos
import UIKit
import UIKit
import Photos

class AssetPasteboard {
    
    private static let pasteboardType = "com.myapp.phasset.ids"
    
    // MARK: - 复制（存储 localIdentifier）
    static func copyAssets(_ assets: [PHAsset], completion: @escaping (Bool, String?) -> Void) {
        let ids = assets.map { $0.localIdentifier }
        guard !ids.isEmpty else {
            completion(false, "没有可复制的资源")
            return
        }
        let idsString = ids.joined(separator: ",")
        UIPasteboard.general.string = idsString
        completion(true, nil)
    }
    
    // MARK: - 获取粘贴板里的资源
    static func assetsFromPasteboard() -> [PHAsset]? {
        
        guard let idsString = UIPasteboard.general.string else {
            return nil
        }

        let ids = idsString.components(separatedBy: ",")
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        
        var assets: [PHAsset] = []
        result.enumerateObjects { obj, _, _ in
            assets.append(obj)
        }
        return assets
    }

    
    // MARK: - 粘贴到相册（基于已有 assets）
    static func pasteAssets(_ assets: [PHAsset],
                            into collection: PHAssetCollection,
                            completion: @escaping (Bool, String?) -> Void) {
        guard !assets.isEmpty else {
            completion(false, "没有可粘贴的资源")
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            if let changeRequest = PHAssetCollectionChangeRequest(for: collection) {
                changeRequest.addAssets(assets as NSFastEnumeration)
            }
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, error?.localizedDescription ?? "粘贴失败")
                }
            }
        })
    }
}
