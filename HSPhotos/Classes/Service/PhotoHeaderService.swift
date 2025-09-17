//
//  PhotoHeaderService.swift
//  HSPhotos
//
//  Created by Hans on 2025/1/27.
//

import Foundation
import Photos

/// 照片扩展信息
struct PhotoExtendedInfo: Codable {
    let assetIdentifier: String
    var isHeader: Bool = false        // 是否为首图
    var isCollapsed: Bool = false     // 所在段落是否折叠
    var headerIdentifier: String?     // 所属段落的头图ID
    
    init(assetIdentifier: String) {
        self.assetIdentifier = assetIdentifier
    }
}

/// 照片段落
struct PhotoParagraph {
    let headerAsset: PHAsset          // 段落首图
    var isCollapsed: Bool = false     // 段落折叠状态
    var followingAssets: [PHAsset]    // 段落内的其他照片
    
    init(headerAsset: PHAsset, isCollapsed: Bool = false, followingAssets: [PHAsset] = []) {
        self.headerAsset = headerAsset
        self.isCollapsed = isCollapsed
        self.followingAssets = followingAssets
    }
}

/// 首图管理服务
class PhotoHeaderService {
    static let shared = PhotoHeaderService()
    
    private init() {}
    
    // MARK: - 首图管理
    
    /// 设置首图
    /// - Parameters:
    ///   - asset: 要设为首图的照片
    ///   - collection: 相册
    func setHeader(_ asset: PHAsset, for collection: PHAssetCollection) {
        var headerAssets = getHeaderAssets(for: collection)
        if !headerAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            headerAssets.append(asset)
            saveHeaderAssets(headerAssets, for: collection)
            print("✅ 设置首图: \(asset.localIdentifier)")
        }
    }
    
    /// 取消首图
    /// - Parameters:
    ///   - asset: 要取消首图的照片
    ///   - collection: 相册
    func removeHeader(_ asset: PHAsset, for collection: PHAssetCollection) {
        var headerAssets = getHeaderAssets(for: collection)
        headerAssets.removeAll { $0.localIdentifier == asset.localIdentifier }
        saveHeaderAssets(headerAssets, for: collection)
        print("✅ 取消首图: \(asset.localIdentifier)")
    }
    
    /// 检查是否为首图
    /// - Parameters:
    ///   - asset: 照片
    ///   - collection: 相册
    /// - Returns: 是否为首图
    func isHeader(_ asset: PHAsset, for collection: PHAssetCollection) -> Bool {
        let headerAssets = getHeaderAssets(for: collection)
        return headerAssets.contains { $0.localIdentifier == asset.localIdentifier }
    }
    
    // MARK: - 段落管理
    
    /// 切换段落折叠状态
    /// - Parameters:
    ///   - headerAsset: 段落首图
    ///   - collection: 相册
    func toggleParagraphCollapse(_ headerAsset: PHAsset, for collection: PHAssetCollection) {
        var collapseStates = getParagraphCollapseStates(for: collection)
        let currentState = collapseStates[headerAsset.localIdentifier] ?? false
        collapseStates[headerAsset.localIdentifier] = !currentState
        saveParagraphCollapseStates(collapseStates, for: collection)
        print("✅ 切换段落状态: \(headerAsset.localIdentifier) -> \(!currentState ? "折叠" : "展开")")
    }
    
    /// 获取段落折叠状态
    /// - Parameters:
    ///   - headerAsset: 段落首图
    ///   - collection: 相册
    /// - Returns: 是否折叠
    func isParagraphCollapsed(_ headerAsset: PHAsset, for collection: PHAssetCollection) -> Bool {
        let collapseStates = getParagraphCollapseStates(for: collection)
        return collapseStates[headerAsset.localIdentifier] ?? false
    }
    
    /// 计算段落结构
    /// - Parameters:
    ///   - assets: 照片数组
    ///   - collection: 相册
    /// - Returns: 段落数组
    func calculateParagraphs(for assets: [PHAsset], in collection: PHAssetCollection) -> [PhotoParagraph] {
        let headerAssets = getHeaderAssets(for: collection)
        let collapseStates = getParagraphCollapseStates(for: collection)
        
        var paragraphs: [PhotoParagraph] = []
        var currentHeader: PHAsset?
        var followingAssets: [PHAsset] = []
        
        for asset in assets {
            if headerAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                // 如果当前有段落，先保存
                if let header = currentHeader {
                    let isCollapsed = collapseStates[header.localIdentifier] ?? false
                    paragraphs.append(PhotoParagraph(headerAsset: header, isCollapsed: isCollapsed, followingAssets: followingAssets))
                }
                // 开始新段落
                currentHeader = asset
                followingAssets = []
            } else if let header = currentHeader {
                // 添加到当前段落
                followingAssets.append(asset)
            } else {
                // 如果还没有首图，这些照片应该正常显示
                // 创建一个虚拟段落来包含这些照片
                if paragraphs.isEmpty || !paragraphs.last!.followingAssets.isEmpty {
                    // 如果这是第一个段落或者上一个段落有内容，创建新段落
                    let dummyHeader = asset // 使用第一张照片作为虚拟首图
                    paragraphs.append(PhotoParagraph(headerAsset: dummyHeader, isCollapsed: false, followingAssets: []))
                }
            }
        }
        
        // 保存最后一个段落
        if let header = currentHeader {
            let isCollapsed = collapseStates[header.localIdentifier] ?? false
            paragraphs.append(PhotoParagraph(headerAsset: header, isCollapsed: isCollapsed, followingAssets: followingAssets))
        }
        
        return paragraphs
    }
    
    /// 获取可见的照片（根据段落折叠状态过滤）
    /// - Parameters:
    ///   - assets: 原始照片数组
    ///   - collection: 相册
    /// - Returns: 可见照片数组
    func getVisibleAssets(from assets: [PHAsset], in collection: PHAssetCollection) -> [PHAsset] {
        let headerAssets = getHeaderAssets(for: collection)
        let collapseStates = getParagraphCollapseStates(for: collection)
        
        var visibleAssets: [PHAsset] = []
        var currentHeader: PHAsset?
        var isCurrentParagraphCollapsed = false
        
        for asset in assets {
            if headerAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                // 这是一个首图
                currentHeader = asset
                isCurrentParagraphCollapsed = collapseStates[asset.localIdentifier] ?? false
                // 总是显示首图
                visibleAssets.append(asset)
            } else {
                // 这不是首图
                if let header = currentHeader {
                    // 如果当前有首图，检查段落是否折叠
                    if !isCurrentParagraphCollapsed {
                        visibleAssets.append(asset)
                    }
                } else {
                    // 如果当前没有首图，正常显示
                    visibleAssets.append(asset)
                }
            }
        }
        
        return visibleAssets
    }
    
    // MARK: - 数据持久化
    
    /// 获取首图列表
    /// - Parameter collection: 相册
    /// - Returns: 首图数组
    private func getHeaderAssets(for collection: PHAssetCollection) -> [PHAsset] {
        let key = "header_photos_\(collection.localIdentifier)"
        let headerIdentifiers = UserDefaults.standard.stringArray(forKey: key) ?? []
        
        // 根据标识符获取PHAsset对象
        var headerAssets: [PHAsset] = []
        for identifier in headerIdentifiers {
            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject {
                headerAssets.append(asset)
            }
        }
        
        return headerAssets
    }
    
    /// 保存首图列表
    /// - Parameters:
    ///   - headerAssets: 首图数组
    ///   - collection: 相册
    private func saveHeaderAssets(_ headerAssets: [PHAsset], for collection: PHAssetCollection) {
        let key = "header_photos_\(collection.localIdentifier)"
        let identifiers = headerAssets.map { $0.localIdentifier }
        UserDefaults.standard.set(identifiers, forKey: key)
    }
    
    /// 获取段落折叠状态
    /// - Parameter collection: 相册
    /// - Returns: 折叠状态字典
    private func getParagraphCollapseStates(for collection: PHAssetCollection) -> [String: Bool] {
        let key = "paragraph_collapse_\(collection.localIdentifier)"
        return UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }
    
    /// 保存段落折叠状态
    /// - Parameters:
    ///   - states: 折叠状态字典
    ///   - collection: 相册
    private func saveParagraphCollapseStates(_ states: [String: Bool], for collection: PHAssetCollection) {
        let key = "paragraph_collapse_\(collection.localIdentifier)"
        UserDefaults.standard.set(states, forKey: key)
    }
    
    // MARK: - 数据清理
    
    /// 清理无效的首图数据
    /// - Parameter collection: 相册
    func cleanupInvalidHeaders(for collection: PHAssetCollection) {
        let headerAssets = getHeaderAssets(for: collection)
        let validHeaders = headerAssets.filter { asset in
            // 检查照片是否仍然存在于相册中
            let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            return fetchResult.contains(asset)
        }
        
        if validHeaders.count != headerAssets.count {
            saveHeaderAssets(validHeaders, for: collection)
            print("🧹 清理了 \(headerAssets.count - validHeaders.count) 个无效首图")
        }
    }
}
