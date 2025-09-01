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
        
        #if DEBUG
        // 添加日志显示复制的照片顺序（仅 Debug）
        print("📋 复制照片顺序:")
        for (index, asset) in assets.enumerated() {
            print("  \(index + 1). \(asset.localIdentifier)")
        }
        #endif
        
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
        
        // 先构建一次查找表，整体 O(n)
        var idToAsset: [String: PHAsset] = [:]
        idToAsset.reserveCapacity(result.count)
        result.enumerateObjects { obj, _, _ in
            idToAsset[obj.localIdentifier] = obj
        }
        // 按 ids 顺序映射，保持选择顺序
        let assets: [PHAsset] = ids.compactMap { idToAsset[$0] }
        
        #if DEBUG
        // 添加日志显示粘贴的照片顺序（仅 Debug）
        print("📋 粘贴照片顺序:")
        for (index, asset) in assets.enumerated() {
            print("  \(index + 1). \(asset.localIdentifier)")
        }
        #endif
        
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
