//
//  PHAssets+.swift
//  HSPhotos
//
//  Created by Hans on 2025/9/11.
//

import Foundation
import SKPhotoBrowser
import Photos
import ObjectiveC
import UIKit

extension PHAsset: @retroactive SKPhotoProtocol {
    private struct AssociatedKeys {
        static var index: UInt8 = 0
        static var underlyingImage: UInt8 = 0
    }
    
    public var index: Int {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.index) as? Int ?? 0
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.index, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public var underlyingImage: UIImage! {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.underlyingImage) as? UIImage
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.underlyingImage, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public var caption: String? {
        // 返回资产的标题或描述（如果有的话）
        return nil
    }
    
    public var contentMode: UIView.ContentMode {
        get {
            return .scaleAspectFill
        }
        set(newValue) {
            // 不需要实现setter，因为contentMode通常由显示控件决定
        }
    }
    
    public func loadUnderlyingImageAndNotify() {
        // 使用PHImageManager加载图片
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        // 请求全尺寸图片
        PHImageManager.default().requestImage(
            for: self,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            guard let self = self else { return }
            self.underlyingImage = image
            loadUnderlyingImageComplete()
        }
    }
    
    func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
    }
    
    
    public func checkCache() {
        // 在这个实现中，我们不使用缓存机制
        // 如果需要可以集成NSCache或其他缓存机制
    }
}
