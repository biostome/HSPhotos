import Foundation
import Photos

class PhotoOperationService {
    
    /// 排序照片并同步到系统相册
    /// - Parameters:
    ///   - sortedAssets: 排序后的照片数组
    ///   - collection: 相册集合
    ///   - completion: 完成回调
    func syncSortedAssets(_ sortedAssets: [PHAsset], for collection: PHAssetCollection, completion: @escaping (Bool, String?) -> Void) {
        PhotoChangesService.sync(sortedAssets: sortedAssets, for: collection) { success, message in
            completion(success, message)
        }
    }
    
    /// 执行删除操作
    /// - Parameters:
    ///   - assets: 要删除的照片数组
    ///   - completion: 完成回调
    func performDelete(assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        guard !assets.isEmpty else {
            completion(false)
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        } completionHandler: { success, error in
            completion(success)
        }
    }
    
    /// 执行移动操作
    /// - Parameters:
    ///   - assets: 要移动的照片数组
    ///   - destinationCollection: 目标相册
    ///   - completion: 完成回调
    func performMove(assets: [PHAsset], to destinationCollection: PHAssetCollection, completion: @escaping (Bool) -> Void) {
        guard !assets.isEmpty else {
            completion(false)
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            for asset in assets {
                let request = PHAssetCollectionChangeRequest(for: destinationCollection)
                request?.addAssets([asset] as NSArray)
            }
        } completionHandler: { success, error in
            completion(success)
        }
    }
    
    /// 检查是否所有资产都被选中
    /// - Parameters:
    ///   - assets: 所有资产数组
    ///   - selectedAssets: 已选中资产数组
    /// - Returns: 是否所有资产都被选中
    func isAllAssetsSelected(assets: [PHAsset], selectedAssets: [PHAsset]) -> Bool {
        return assets.count > 0 && assets.count == selectedAssets.count
    }
    
    /// 切换选择模式
    /// - Parameter currentMode: 当前选择模式
    /// - Returns: 新的选择模式
    func toggleSelectionMode(currentMode: PhotoSelectionMode) -> PhotoSelectionMode {
        switch currentMode {
        case .none:
            return .multiple
        case .multiple:
            return .none
        case .range:
            return .none
        }
    }
}