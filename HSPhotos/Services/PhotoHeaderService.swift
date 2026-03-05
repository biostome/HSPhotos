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
            } else if currentHeader != nil {
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
                if currentHeader != nil {
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

struct PhotoHierarchyNode: Codable {
    var path: [Int]
    var isCollapsed: Bool
}

enum PhotoHierarchyError: LocalizedError {
    case assetNotFound
    case invalidLevel
    case missingParent(level: Int)
    case invalidPath
    case missingParentPath
    case pathOccupied

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "无法在当前相片列表中找到目标图片"
        case .invalidLevel:
            return "层级必须是大于等于 0 的整数"
        case .missingParent(let level):
            return "无法设置为 \(level) 级：前方不存在可作为父级的 \(level - 1) 级图片"
        case .invalidPath:
            return "层级路径格式无效，请输入如 1、2 或 1.2、2.3.1"
        case .missingParentPath:
            return "无法设置该层级路径：父级路径不存在"
        case .pathOccupied:
            return "该层级路径已被占用，请换一个路径"
        }
    }
}

final class PhotoHierarchyService {
    static let shared = PhotoHierarchyService()

    private init() {}

    func node(for asset: PHAsset, in collection: PHAssetCollection) -> PhotoHierarchyNode? {
        loadNodes(for: collection)[asset.localIdentifier]
    }

    func hierarchyText(for asset: PHAsset, in collection: PHAssetCollection) -> String? {
        guard let node = node(for: asset, in: collection), !node.path.isEmpty else { return nil }
        return node.path.map(String.init).joined(separator: ".")
    }

    func isCollapsed(_ asset: PHAsset, in collection: PHAssetCollection) -> Bool {
        node(for: asset, in: collection)?.isCollapsed ?? false
    }

    func level(for asset: PHAsset, in collection: PHAssetCollection) -> Int {
        node(for: asset, in: collection)?.path.count ?? 0
    }

    func hasDescendants(_ asset: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) -> Bool {
        let nodes = loadNodes(for: collection)
        guard let current = nodes[asset.localIdentifier], !current.path.isEmpty else { return false }
        guard let startIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) else { return false }

        for index in (startIndex + 1)..<orderedAssets.count {
            let nextAsset = orderedAssets[index]
            guard let nextNode = nodes[nextAsset.localIdentifier], !nextNode.path.isEmpty else { continue }
            if isPrefix(current.path, of: nextNode.path) {
                return true
            }
            if comparePath(nextNode.path, current.path) != .orderedDescending {
                return false
            }
        }
        return false
    }

    func setAsNextRoot(_ asset: PHAsset, in collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
        nodes[asset.localIdentifier] = PhotoHierarchyNode(path: [maxRoot + 1], isCollapsed: false)
        saveNodes(nodes, for: collection)
    }

    func setAsTopLevel(_ asset: PHAsset, in collection: PHAssetCollection) {
        setAsNextRoot(asset, in: collection)
    }

    func setAsChildOfPrevious(_ asset: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard let currentIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
              currentIndex > 0 else {
            setAsNextRoot(asset, in: collection)
            return
        }

        var nodes = loadNodes(for: collection)
        var foundParentPath: [Int]?
        for index in stride(from: currentIndex - 1, through: 0, by: -1) {
            let candidateID = orderedAssets[index].localIdentifier
            if let candidatePath = nodes[candidateID]?.path, !candidatePath.isEmpty {
                foundParentPath = candidatePath
                break
            }
        }
        let parentPath: [Int]
        if let path = foundParentPath {
            parentPath = path
        } else {
            let nextRoot = nextSiblingIndex(under: [], nodes: nodes, excluding: asset.localIdentifier)
            parentPath = [nextRoot]
        }

        let oldPath = nodes[asset.localIdentifier]?.path ?? []
        let childIndex = nextChildIndex(of: parentPath, nodes: nodes)
        let newPath = parentPath + [childIndex]
        moveSubtree(of: asset.localIdentifier, from: oldPath, to: newPath, nodes: &nodes)
        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func setAsSiblingOfPrevious(_ asset: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard let currentIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
              currentIndex > 0 else {
            setAsNextRoot(asset, in: collection)
            return
        }

        var nodes = loadNodes(for: collection)
        let previousPath: [Int]
        if let directPreviousNode = nodes[orderedAssets[currentIndex - 1].localIdentifier], !directPreviousNode.path.isEmpty {
            previousPath = directPreviousNode.path
        } else {
            var foundPath: [Int]?
            for index in stride(from: currentIndex - 1, through: 0, by: -1) {
                let candidateID = orderedAssets[index].localIdentifier
                if let candidatePath = nodes[candidateID]?.path, !candidatePath.isEmpty {
                    foundPath = candidatePath
                    break
                }
            }
            if let path = foundPath {
                previousPath = path
            } else {
                let nextRoot = nextSiblingIndex(under: [], nodes: nodes, excluding: asset.localIdentifier)
                previousPath = [nextRoot]
            }
        }

        let parentPath = Array(previousPath.dropLast())
        let nextIndex = nextSiblingIndex(under: parentPath, nodes: nodes, excluding: asset.localIdentifier)
        let oldPath = nodes[asset.localIdentifier]?.path ?? []
        let newPath = parentPath + [nextIndex]
        moveSubtree(of: asset.localIdentifier, from: oldPath, to: newPath, nodes: &nodes)
        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func setLevelOrClear(for asset: PHAsset, to level: Int, in orderedAssets: [PHAsset], collection: PHAssetCollection) throws {
        if level == 0 {
            clearSubtree(of: asset, in: collection)
            return
        }
        try setLevel(for: asset, to: level, in: orderedAssets, collection: collection)
    }

    func setLevel(for asset: PHAsset, to level: Int, in orderedAssets: [PHAsset], collection: PHAssetCollection) throws {
        var nodes = loadNodes(for: collection)
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        try setLevel(for: asset.localIdentifier, to: level, in: orderedIDs, nodes: &nodes)
        nodes = normalized(nodes: nodes, in: orderedIDs)
        saveNodes(nodes, for: collection)
    }

    func setPathOrClear(for asset: PHAsset, to path: [Int], in orderedAssets: [PHAsset], collection: PHAssetCollection) throws {
        var nodes = loadNodes(for: collection)
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        if path == [0] {
            try setLevelOrClear(for: asset.localIdentifier, to: 0, in: orderedIDs, nodes: &nodes)
        } else {
            try setPath(for: asset.localIdentifier, to: path, in: orderedIDs, nodes: &nodes)
        }
        nodes = normalized(nodes: nodes, in: orderedIDs)
        saveNodes(nodes, for: collection)
    }

    func setAsChild(_ asset: PHAsset, of parent: PHAsset, in collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        let parentPath: [Int]
        if let parentNode = nodes[parent.localIdentifier], !parentNode.path.isEmpty {
            parentPath = parentNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            parentPath = [maxRoot + 1]
            nodes[parent.localIdentifier] = PhotoHierarchyNode(path: parentPath, isCollapsed: false)
        }

        let childIndex = nextChildIndex(of: parentPath, nodes: nodes)
        nodes[asset.localIdentifier] = PhotoHierarchyNode(path: parentPath + [childIndex], isCollapsed: false)
        saveNodes(nodes, for: collection)
    }

    func insertAsSiblingAfter(_ asset: PHAsset, reference: PHAsset, in collection: PHAssetCollection) {
        guard asset.localIdentifier != reference.localIdentifier else { return }
        var nodes = loadNodes(for: collection)
        let referencePath: [Int]
        if let refNode = nodes[reference.localIdentifier], !refNode.path.isEmpty {
            referencePath = refNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            referencePath = [maxRoot + 1]
            nodes[reference.localIdentifier] = PhotoHierarchyNode(path: referencePath, isCollapsed: false)
        }

        let parentPath = Array(referencePath.dropLast())
        let referenceID = reference.localIdentifier
        let movingID = asset.localIdentifier

        var siblingIDs = siblingIDs(under: parentPath, nodes: nodes)
        siblingIDs.removeAll { $0 == movingID }
        guard let referenceIndex = siblingIDs.firstIndex(of: referenceID) else { return }
        siblingIDs.insert(movingID, at: referenceIndex + 1)

        for (index, siblingID) in siblingIDs.enumerated() {
            let collapsed = nodes[siblingID]?.isCollapsed ?? false
            nodes[siblingID] = PhotoHierarchyNode(path: parentPath + [index + 1], isCollapsed: collapsed)
        }
        saveNodes(nodes, for: collection)
    }

    func setAsSibling(_ asset: PHAsset, of reference: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard asset.localIdentifier != reference.localIdentifier else { return }
        var nodes = loadNodes(for: collection)
        let referencePath: [Int]
        if let refNode = nodes[reference.localIdentifier], !refNode.path.isEmpty {
            referencePath = refNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            referencePath = [maxRoot + 1]
            nodes[reference.localIdentifier] = PhotoHierarchyNode(path: referencePath, isCollapsed: false)
        }

        let parentPath = Array(referencePath.dropLast())
        let nextIndex = nextChildIndex(of: parentPath, nodes: nodes)
        let oldPath = nodes[asset.localIdentifier]?.path ?? []
        let newPath = parentPath + [nextIndex]
        moveSubtree(of: asset.localIdentifier, from: oldPath, to: newPath, nodes: &nodes)
        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func promote(_ asset: PHAsset, in collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        guard var node = nodes[asset.localIdentifier], node.path.count > 1 else { return }

        // 提升一级时分配新的同级序号，避免与现有层级重复
        let promotedParentPath = Array(node.path.dropLast(2))
        let nextIndex = firstAvailableSiblingIndex(under: promotedParentPath, nodes: nodes, excluding: asset.localIdentifier)
        node.path = promotedParentPath + [nextIndex]
        nodes[asset.localIdentifier] = node
        saveNodes(nodes, for: collection)
    }

    func promote(_ asset: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        guard let current = nodes[asset.localIdentifier], current.path.count > 1 else { return }
        let oldPath = current.path
        let promotedParentPath = Array(current.path.dropLast(2))
        let nextIndex = nextChildIndex(of: promotedParentPath, nodes: nodes)
        let newPath = promotedParentPath + [nextIndex]
        moveSubtree(of: asset.localIdentifier, from: oldPath, to: newPath, nodes: &nodes)
        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func demote(_ asset: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        setAsChildOfPrevious(asset, in: orderedAssets, collection: collection)
    }

    func clear(_ asset: PHAsset, in collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        nodes.removeValue(forKey: asset.localIdentifier)
        saveNodes(nodes, for: collection)
    }

    func clearSubtree(of asset: PHAsset, in collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        guard let rootPath = nodes[asset.localIdentifier]?.path, !rootPath.isEmpty else { return }
        nodes = nodes.filter { (_, node) in
            !isPrefix(rootPath, of: node.path)
        }
        saveNodes(nodes, for: collection)
    }

    func toggleCollapse(_ asset: PHAsset, in collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        if var node = nodes[asset.localIdentifier], !node.path.isEmpty {
            node.isCollapsed.toggle()
            nodes[asset.localIdentifier] = node
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            nodes[asset.localIdentifier] = PhotoHierarchyNode(path: [maxRoot + 1], isCollapsed: true)
        }
        saveNodes(nodes, for: collection)
    }

    func getVisibleAssets(from assets: [PHAsset], in collection: PHAssetCollection) -> [PHAsset] {
        let nodes = loadNodes(for: collection)
        var visible: [PHAsset] = []
        var collapsedStack: [[Int]] = []

        for asset in assets {
            let path = nodes[asset.localIdentifier]?.path ?? []
            collapsedStack.removeAll { !isPrefix($0, of: path) }

            let shouldHide = collapsedStack.contains { isPrefix($0, of: path) && $0.count < path.count }
            if shouldHide {
                continue
            }

            visible.append(asset)

            if let node = nodes[asset.localIdentifier], node.isCollapsed, !node.path.isEmpty {
                collapsedStack.append(node.path)
            }
        }
        return visible
    }

    func cleanupInvalidNodes(validAssetIDs: Set<String>, for collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        let before = nodes.count
        nodes = nodes.filter { validAssetIDs.contains($0.key) }
        if nodes.count != before {
            saveNodes(nodes, for: collection)
        }
    }

    func resolveDuplicatePaths(in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        var nodes = loadNodes(for: collection)
        guard !nodes.isEmpty else { return }

        var usedPathKeys = Set<String>()
        var maxSiblingByParent: [String: Int] = [:]
        maxSiblingByParent.reserveCapacity(nodes.count)

        for asset in orderedAssets {
            let id = asset.localIdentifier
            guard var node = nodes[id], !node.path.isEmpty else { continue }

            let currentPathKey = pathKey(node.path)
            if !usedPathKeys.contains(currentPathKey) {
                usedPathKeys.insert(currentPathKey)
                let parentPath = Array(node.path.dropLast())
                let parentKey = pathKey(parentPath)
                let index = node.path.last ?? 0
                maxSiblingByParent[parentKey] = max(maxSiblingByParent[parentKey] ?? 0, index)
                continue
            }

            // 冲突路径：改为同父级下一个可用序号
            let parentPath = Array(node.path.dropLast())
            let parentKey = pathKey(parentPath)
            let nextIndex = (maxSiblingByParent[parentKey] ?? 0) + 1
            maxSiblingByParent[parentKey] = nextIndex
            node.path = parentPath + [nextIndex]
            nodes[id] = node
            usedPathKeys.insert(pathKey(node.path))
        }

        saveNodes(nodes, for: collection)
    }

    func setAsNextRoots(_ assets: [PHAsset], in collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)
        var currentRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
        for asset in assets {
            currentRoot += 1
            nodes[asset.localIdentifier] = PhotoHierarchyNode(path: [currentRoot], isCollapsed: false)
        }
        saveNodes(nodes, for: collection)
    }

    func setAsTopLevels(_ assets: [PHAsset], in collection: PHAssetCollection) {
        setAsNextRoots(assets, in: collection)
    }

    func setAsTopLevels(_ assets: [PHAsset], in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)
        var currentRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
        for asset in assets {
            currentRoot += 1
            let oldPath = nodes[asset.localIdentifier]?.path ?? []
            moveSubtree(of: asset.localIdentifier, from: oldPath, to: [currentRoot], nodes: &nodes)
        }
        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func setAsChildrenOfPrevious(_ selectedAssets: [PHAsset], in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard !selectedAssets.isEmpty else { return }
        var nodes = loadNodes(for: collection)

        // 预计算：ID -> 顺序下标，避免反复 firstIndex 查找
        var orderedIndexByID: [String: Int] = [:]
        orderedIndexByID.reserveCapacity(orderedAssets.count)
        for (index, asset) in orderedAssets.enumerated() {
            orderedIndexByID[asset.localIdentifier] = index
        }

        // 预计算：父路径 -> 当前最大子序号，避免每次扫描所有节点
        var maxChildIndexByParentKey: [String: Int] = [:]
        maxChildIndexByParentKey.reserveCapacity(nodes.count)
        for node in nodes.values where node.path.count >= 2 {
            let parentPath = Array(node.path.dropLast())
            let parentKey = pathKey(parentPath)
            let currentChild = node.path.last ?? 0
            let cachedMax = maxChildIndexByParentKey[parentKey] ?? 0
            if currentChild > cachedMax {
                maxChildIndexByParentKey[parentKey] = currentChild
            }
        }

        let selectedIDs = Set(selectedAssets.map { $0.localIdentifier })
        let orderedSelected = orderedAssets.filter { selectedIDs.contains($0.localIdentifier) }

        var currentMaxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0

        for asset in orderedSelected {
            guard let currentIndex = orderedIndexByID[asset.localIdentifier], currentIndex > 0 else {
                currentMaxRoot += 1
                nodes[asset.localIdentifier] = PhotoHierarchyNode(path: [currentMaxRoot], isCollapsed: false)
                continue
            }

            let previousAsset = orderedAssets[currentIndex - 1]
            let parentPath: [Int]
            if let previousNode = nodes[previousAsset.localIdentifier], !previousNode.path.isEmpty {
                parentPath = previousNode.path
            } else {
                currentMaxRoot += 1
                parentPath = [currentMaxRoot]
                nodes[previousAsset.localIdentifier] = PhotoHierarchyNode(path: parentPath, isCollapsed: false)
            }

            let parentKey = pathKey(parentPath)
            let nextChild = (maxChildIndexByParentKey[parentKey] ?? 0) + 1
            maxChildIndexByParentKey[parentKey] = nextChild

            nodes[asset.localIdentifier] = PhotoHierarchyNode(path: parentPath + [nextChild], isCollapsed: false)
        }

        saveNodes(nodes, for: collection)
    }

    func setAsChildren(_ assets: [PHAsset], of parent: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)

        let parentPath: [Int]
        if let parentNode = nodes[parent.localIdentifier], !parentNode.path.isEmpty {
            parentPath = parentNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            parentPath = [maxRoot + 1]
            nodes[parent.localIdentifier] = PhotoHierarchyNode(path: parentPath, isCollapsed: false)
        }

        let selectedIDs = Set(assets.map { $0.localIdentifier })
        let orderedSelected = orderedAssets.filter { selectedIDs.contains($0.localIdentifier) }

        var nextChild = nextChildIndex(of: parentPath, nodes: nodes)
        for asset in orderedSelected {
            nodes[asset.localIdentifier] = PhotoHierarchyNode(path: parentPath + [nextChild], isCollapsed: false)
            nextChild += 1
        }

        saveNodes(nodes, for: collection)
    }

    func setAsSiblings(_ assets: [PHAsset], of reference: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)

        let referencePath: [Int]
        if let refNode = nodes[reference.localIdentifier], !refNode.path.isEmpty {
            referencePath = refNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            referencePath = [maxRoot + 1]
            nodes[reference.localIdentifier] = PhotoHierarchyNode(path: referencePath, isCollapsed: false)
        }

        let parentPath = Array(referencePath.dropLast())
        var nextIndex = nextChildIndex(of: parentPath, nodes: nodes)
        let selectedIDs = Set(assets.map(\.localIdentifier))
        let orderedSelected = orderedAssets.filter { selectedIDs.contains($0.localIdentifier) && $0.localIdentifier != reference.localIdentifier }

        for asset in orderedSelected {
            let oldPath = nodes[asset.localIdentifier]?.path ?? []
            moveSubtree(of: asset.localIdentifier, from: oldPath, to: parentPath + [nextIndex], nodes: &nodes)
            nextIndex += 1
        }
        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func insertAsSiblingsAfter(_ assets: [PHAsset], reference: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)

        let referencePath: [Int]
        if let refNode = nodes[reference.localIdentifier], !refNode.path.isEmpty {
            referencePath = refNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            referencePath = [maxRoot + 1]
            nodes[reference.localIdentifier] = PhotoHierarchyNode(path: referencePath, isCollapsed: false)
        }

        let parentPath = Array(referencePath.dropLast())
        let referenceID = reference.localIdentifier
        let selectedIDs = Set(assets.map { $0.localIdentifier })
        let orderedSelectedIDs = orderedAssets.map(\.localIdentifier).filter { selectedIDs.contains($0) && $0 != referenceID }

        var siblingIDs = siblingIDs(under: parentPath, nodes: nodes)
        siblingIDs.removeAll { orderedSelectedIDs.contains($0) }
        guard let referenceIndex = siblingIDs.firstIndex(of: referenceID) else { return }
        siblingIDs.insert(contentsOf: orderedSelectedIDs, at: referenceIndex + 1)

        for (index, siblingID) in siblingIDs.enumerated() {
            let collapsed = nodes[siblingID]?.isCollapsed ?? false
            nodes[siblingID] = PhotoHierarchyNode(path: parentPath + [index + 1], isCollapsed: collapsed)
        }

        saveNodes(nodes, for: collection)
    }

    func promote(_ assets: [PHAsset], in collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)

        var usedSiblingByParent: [String: Set<Int>] = [:]
        usedSiblingByParent.reserveCapacity(nodes.count)
        for (assetID, node) in nodes where !node.path.isEmpty {
            let parentPath = Array(node.path.dropLast())
            let parentKey = pathKey(parentPath)
            let index = node.path.last ?? 0
            if usedSiblingByParent[parentKey] == nil {
                usedSiblingByParent[parentKey] = []
            }
            usedSiblingByParent[parentKey]?.insert(index)
            // 提前保留 key，后续快速更新
            _ = assetID
        }

        for asset in assets {
            guard var node = nodes[asset.localIdentifier], node.path.count > 1 else { continue }
            let oldParentPath = Array(node.path.dropLast())
            let oldParentKey = pathKey(oldParentPath)
            if let oldIndex = node.path.last {
                usedSiblingByParent[oldParentKey]?.remove(oldIndex)
            }

            let promotedParentPath = Array(node.path.dropLast(2))
            let promotedParentKey = pathKey(promotedParentPath)
            if usedSiblingByParent[promotedParentKey] == nil {
                usedSiblingByParent[promotedParentKey] = []
            }
            let nextIndex = firstMissingPositive(in: usedSiblingByParent[promotedParentKey] ?? [])
            usedSiblingByParent[promotedParentKey]?.insert(nextIndex)
            node.path = promotedParentPath + [nextIndex]
            nodes[asset.localIdentifier] = node
        }

        saveNodes(nodes, for: collection)
    }

    func promote(_ assets: [PHAsset], in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)
        let selectedIDs = Set(assets.map(\.localIdentifier))
        let orderedSelected = orderedAssets.filter { selectedIDs.contains($0.localIdentifier) }

        for asset in orderedSelected {
            guard let current = nodes[asset.localIdentifier], current.path.count > 1 else { continue }
            let oldPath = current.path
            let promotedParentPath = Array(current.path.dropLast(2))
            let nextIndex = nextChildIndex(of: promotedParentPath, nodes: nodes)
            let newPath = promotedParentPath + [nextIndex]
            moveSubtree(of: asset.localIdentifier, from: oldPath, to: newPath, nodes: &nodes)
        }

        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    func demote(_ assets: [PHAsset], in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        setAsChildrenOfPrevious(assets, in: orderedAssets, collection: collection)
    }

    func clear(_ assets: [PHAsset], in collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)
        for asset in assets {
            nodes.removeValue(forKey: asset.localIdentifier)
        }
        saveNodes(nodes, for: collection)
    }

    func clearSubtrees(of assets: [PHAsset], in collection: PHAssetCollection) {
        guard !assets.isEmpty else { return }
        var nodes = loadNodes(for: collection)
        let rootPaths = assets.compactMap { nodes[$0.localIdentifier]?.path }.filter { !$0.isEmpty }
        guard !rootPaths.isEmpty else { return }
        nodes = nodes.filter { (_, node) in
            !rootPaths.contains(where: { isPrefix($0, of: node.path) })
        }
        saveNodes(nodes, for: collection)
    }

    func assignFollowingUnleveledAsChildren(of parent: PHAsset, in orderedAssets: [PHAsset], collection: PHAssetCollection) {
        guard let parentIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == parent.localIdentifier }) else { return }
        var nodes = loadNodes(for: collection)

        let parentPath: [Int]
        if let parentNode = nodes[parent.localIdentifier], !parentNode.path.isEmpty {
            parentPath = parentNode.path
        } else {
            let maxRoot = nodes.values.compactMap { $0.path.first }.max() ?? 0
            parentPath = [maxRoot + 1]
            nodes[parent.localIdentifier] = PhotoHierarchyNode(path: parentPath, isCollapsed: false)
        }

        var nextChild = nextChildIndex(of: parentPath, nodes: nodes)
        for index in (parentIndex + 1)..<orderedAssets.count {
            let asset = orderedAssets[index]
            if nodes[asset.localIdentifier]?.path.isEmpty ?? true {
                nodes[asset.localIdentifier] = PhotoHierarchyNode(path: parentPath + [nextChild], isCollapsed: false)
                nextChild += 1
            }
        }

        nodes = normalized(nodes: nodes, in: orderedAssets)
        saveNodes(nodes, for: collection)
    }

    @discardableResult
    func setLevelOrClear(_ assets: [PHAsset], to level: Int, in orderedAssets: [PHAsset], collection: PHAssetCollection) -> [String] {
        guard !assets.isEmpty else { return [] }
        let selectedIDs = Set(assets.map(\.localIdentifier))
        let orderedSelected = orderedAssets.filter { selectedIDs.contains($0.localIdentifier) }

        var failedAssetIDs: [String] = []
        var nodes = loadNodes(for: collection)
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        for asset in orderedSelected {
            do {
                try setLevelOrClear(for: asset.localIdentifier, to: level, in: orderedIDs, nodes: &nodes)
            } catch {
                failedAssetIDs.append(asset.localIdentifier)
            }
        }
        nodes = normalized(nodes: nodes, in: orderedIDs)
        saveNodes(nodes, for: collection)
        return failedAssetIDs
    }

    private func nextChildIndex(of parentPath: [Int], nodes: [String: PhotoHierarchyNode]) -> Int {
        let used: Set<Int> = Set(
            nodes.values.compactMap { node in
                guard node.path.count == parentPath.count + 1,
                      Array(node.path.dropLast()) == parentPath else { return nil }
                return node.path.last
            }
        )
        return firstMissingPositive(in: used)
    }

    private func nextSiblingIndex(under parentPath: [Int], nodes: [String: PhotoHierarchyNode], excluding assetID: String) -> Int {
        let used: Set<Int> = Set(
            nodes.filter { $0.key != assetID }.values.compactMap { node in
                guard node.path.count == parentPath.count + 1,
                      Array(node.path.dropLast()) == parentPath else { return nil }
                return node.path.last
            }
        )
        return firstMissingPositive(in: used)
    }

    private func firstAvailableSiblingIndex(under parentPath: [Int], nodes: [String: PhotoHierarchyNode], excluding assetID: String) -> Int {
        let used: Set<Int> = Set(
            nodes.filter { $0.key != assetID }.values.compactMap { node in
                guard node.path.count == parentPath.count + 1,
                      Array(node.path.dropLast()) == parentPath else { return nil }
                return node.path.last
            }
        )
        return firstMissingPositive(in: used)
    }

    private func firstMissingPositive(in used: Set<Int>) -> Int {
        var candidate = 1
        while used.contains(candidate) {
            candidate += 1
        }
        return candidate
    }

    private func siblingIDs(under parentPath: [Int], nodes: [String: PhotoHierarchyNode]) -> [String] {
        nodes
            .filter {
                $0.value.path.count == parentPath.count + 1 &&
                Array($0.value.path.dropLast()) == parentPath
            }
            .sorted { (lhs, rhs) in
                (lhs.value.path.last ?? 0) < (rhs.value.path.last ?? 0)
            }
            .map(\.key)
    }

    private func isPrefix(_ prefix: [Int], of full: [Int]) -> Bool {
        guard !prefix.isEmpty, prefix.count <= full.count else { return false }
        return Array(full.prefix(prefix.count)) == prefix
    }

    private func comparePath(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = min(lhs.count, rhs.count)
        for index in 0..<count {
            if lhs[index] < rhs[index] { return .orderedAscending }
            if lhs[index] > rhs[index] { return .orderedDescending }
        }
        if lhs.count == rhs.count { return .orderedSame }
        return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
    }

    private func storageKey(for collection: PHAssetCollection) -> String {
        "photo_hierarchy_nodes_\(collection.localIdentifier)"
    }

    private func pathKey(_ path: [Int]) -> String {
        path.map(String.init).joined(separator: ".")
    }

    private func moveSubtree(of assetID: String, from oldPath: [Int], to newPath: [Int], nodes: inout [String: PhotoHierarchyNode]) {
        let collapse = nodes[assetID]?.isCollapsed ?? false
        if oldPath.isEmpty {
            nodes[assetID] = PhotoHierarchyNode(path: newPath, isCollapsed: collapse)
            return
        }

        let descendants = nodes.filter { key, node in
            key != assetID && isPrefix(oldPath, of: node.path)
        }
        for (descendantID, descendantNode) in descendants {
            let suffix = Array(descendantNode.path.dropFirst(oldPath.count))
            nodes[descendantID] = PhotoHierarchyNode(path: newPath + suffix, isCollapsed: descendantNode.isCollapsed)
        }
        nodes[assetID] = PhotoHierarchyNode(path: newPath, isCollapsed: collapse)
    }

    /// 当某个节点被改级且离开原父级时，将其后续同级自动并入为新节点子级。
    /// 例如：1, 1.1, 1.2, 1.3 中把 1.2 改为 2，则 1.3 -> 2.1。
    private func moveFollowingSiblingsUnderMovedNode(from oldPath: [Int], to newPath: [Int], nodes: inout [String: PhotoHierarchyNode]) {
        guard oldPath.count >= 1 else { return }
        let oldParent = Array(oldPath.dropLast())
        let oldIndex = oldPath.last ?? 0

        let followingSiblings: [(id: String, path: [Int])] = nodes
            .compactMap { key, node in
                guard node.path.count == oldPath.count,
                      Array(node.path.dropLast()) == oldParent,
                      (node.path.last ?? 0) > oldIndex else { return nil }
                return (id: key, path: node.path)
            }
            .sorted { ($0.path.last ?? 0) < ($1.path.last ?? 0) }

        var nextChild = nextChildIndex(of: newPath, nodes: nodes)
        for sibling in followingSiblings {
            let targetPath = newPath + [nextChild]
            moveSubtree(of: sibling.id, from: sibling.path, to: targetPath, nodes: &nodes)
            nextChild += 1
        }
    }

    private func normalized(nodes: [String: PhotoHierarchyNode], in orderedAssets: [PHAsset]) -> [String: PhotoHierarchyNode] {
        normalized(nodes: nodes, in: orderedAssets.map(\.localIdentifier))
    }

    private func normalized(nodes: [String: PhotoHierarchyNode], in orderedIDs: [String]) -> [String: PhotoHierarchyNode] {
        guard !nodes.isEmpty else { return nodes }
        var result = nodes
        var usedByParent: [String: Set<Int>] = [:]

        for assetID in orderedIDs {
            guard var node = result[assetID], !node.path.isEmpty else { continue }
            let parentPath = Array(node.path.dropLast())
            let parentKey = pathKey(parentPath)
            let currentIndex = node.path.last ?? 1

            if usedByParent[parentKey]?.contains(currentIndex) == true {
                let newIndex = firstMissingPositive(in: usedByParent[parentKey] ?? [])
                node.path = parentPath + [newIndex]
                result[assetID] = node
                usedByParent[parentKey, default: []].insert(newIndex)
            } else {
                usedByParent[parentKey, default: []].insert(currentIndex)
            }
        }

        return result
    }

    private func setLevelOrClear(for assetID: String, to level: Int, in orderedIDs: [String], nodes: inout [String: PhotoHierarchyNode]) throws {
        if level == 0 {
            clearSubtree(of: assetID, nodes: &nodes)
            return
        }
        try setLevel(for: assetID, to: level, in: orderedIDs, nodes: &nodes)
    }

    private func setLevel(for assetID: String, to level: Int, in orderedIDs: [String], nodes: inout [String: PhotoHierarchyNode]) throws {
        guard level >= 1 else { throw PhotoHierarchyError.invalidLevel }
        guard let currentIndex = orderedIDs.firstIndex(of: assetID) else {
            throw PhotoHierarchyError.assetNotFound
        }

        let oldPath = nodes[assetID]?.path ?? []
        let parentPath: [Int]

        if level == 1 {
            parentPath = []
        } else {
            var foundParent: [Int]?
            for index in stride(from: currentIndex - 1, through: 0, by: -1) {
                let candidateID = orderedIDs[index]
                guard let candidateNode = nodes[candidateID], candidateNode.path.count == level - 1 else { continue }
                foundParent = candidateNode.path
                break
            }
            guard let validParent = foundParent else {
                throw PhotoHierarchyError.missingParent(level: level)
            }
            parentPath = validParent
        }

        let nextIndex = nextSiblingIndex(under: parentPath, nodes: nodes, excluding: assetID)
        let newPath = parentPath + [nextIndex]
        moveSubtree(of: assetID, from: oldPath, to: newPath, nodes: &nodes)
        if !oldPath.isEmpty, Array(oldPath.dropLast()) != parentPath {
            moveFollowingSiblingsUnderMovedNode(from: oldPath, to: newPath, nodes: &nodes)
        }
    }

    private func setPath(for assetID: String, to path: [Int], in orderedIDs: [String], nodes: inout [String: PhotoHierarchyNode]) throws {
        guard !path.isEmpty, path.allSatisfy({ $0 > 0 }) else {
            throw PhotoHierarchyError.invalidPath
        }
        guard let currentIndex = orderedIDs.firstIndex(of: assetID) else {
            throw PhotoHierarchyError.assetNotFound
        }

        let oldPath = nodes[assetID]?.path ?? []
        if !oldPath.isEmpty, isPrefix(oldPath, of: path), path.count > oldPath.count {
            throw PhotoHierarchyError.invalidPath
        }

        if path.count > 1 {
            let parentPath = Array(path.dropLast())
            var parentExistsBefore = false
            if currentIndex > 0 {
                for index in stride(from: currentIndex - 1, through: 0, by: -1) {
                    let candidateID = orderedIDs[index]
                    if nodes[candidateID]?.path == parentPath {
                        parentExistsBefore = true
                        break
                    }
                }
            }
            guard parentExistsBefore else {
                throw PhotoHierarchyError.missingParentPath
            }
        }

        let occupied = nodes.first { key, node in
            key != assetID && node.path == path
        } != nil
        if occupied {
            throw PhotoHierarchyError.pathOccupied
        }

        moveSubtree(of: assetID, from: oldPath, to: path, nodes: &nodes)
        let newParent = Array(path.dropLast())
        if !oldPath.isEmpty, Array(oldPath.dropLast()) != newParent {
            moveFollowingSiblingsUnderMovedNode(from: oldPath, to: path, nodes: &nodes)
        }
    }

    private func clearSubtree(of assetID: String, nodes: inout [String: PhotoHierarchyNode]) {
        guard let rootPath = nodes[assetID]?.path, !rootPath.isEmpty else { return }
        nodes = nodes.filter { (_, node) in
            !isPrefix(rootPath, of: node.path)
        }
    }

    private func loadNodes(for collection: PHAssetCollection) -> [String: PhotoHierarchyNode] {
        let key = storageKey(for: collection)
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder().decode([String: PhotoHierarchyNode].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveNodes(_ nodes: [String: PhotoHierarchyNode], for collection: PHAssetCollection) {
        let key = storageKey(for: collection)
        do {
            let data = try JSONEncoder().encode(nodes)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    #if DEBUG
    // MARK: - Test Helpers

    internal func test_nextAvailableIndex(in used: Set<Int>) -> Int {
        firstMissingPositive(in: used)
    }

    internal func test_nextChildIndex(parentPath: [Int], nodes: [String: PhotoHierarchyNode]) -> Int {
        nextChildIndex(of: parentPath, nodes: nodes)
    }

    internal func test_applySetLevel(assetID: String, level: Int, orderedIDs: [String], nodes: [String: PhotoHierarchyNode]) throws -> [String: PhotoHierarchyNode] {
        var output = nodes
        try setLevel(for: assetID, to: level, in: orderedIDs, nodes: &output)
        return normalized(nodes: output, in: orderedIDs)
    }

    internal func test_applySetLevelOrClear(assetID: String, level: Int, orderedIDs: [String], nodes: [String: PhotoHierarchyNode]) throws -> [String: PhotoHierarchyNode] {
        var output = nodes
        try setLevelOrClear(for: assetID, to: level, in: orderedIDs, nodes: &output)
        return normalized(nodes: output, in: orderedIDs)
    }

    internal func test_applyBatchSetLevelOrClear(orderedIDs: [String], selectedIDs: [String], level: Int, nodes: [String: PhotoHierarchyNode]) -> (nodes: [String: PhotoHierarchyNode], failed: [String]) {
        var output = nodes
        var failed: [String] = []
        for assetID in orderedIDs where selectedIDs.contains(assetID) {
            do {
                try setLevelOrClear(for: assetID, to: level, in: orderedIDs, nodes: &output)
            } catch {
                failed.append(assetID)
            }
        }
        output = normalized(nodes: output, in: orderedIDs)
        return (output, failed)
    }

    internal func test_applySetPathOrClear(assetID: String, path: [Int], orderedIDs: [String], nodes: [String: PhotoHierarchyNode]) throws -> [String: PhotoHierarchyNode] {
        var output = nodes
        if path == [0] {
            try setLevelOrClear(for: assetID, to: 0, in: orderedIDs, nodes: &output)
        } else {
            try setPath(for: assetID, to: path, in: orderedIDs, nodes: &output)
        }
        return normalized(nodes: output, in: orderedIDs)
    }

    internal func test_applySetAsSiblingOfPrevious(assetID: String, orderedIDs: [String], nodes: [String: PhotoHierarchyNode]) -> [String: PhotoHierarchyNode] {
        guard let currentIndex = orderedIDs.firstIndex(of: assetID), currentIndex > 0 else { return nodes }
        var output = nodes

        let previousPath: [Int]
        if let directPreviousNode = output[orderedIDs[currentIndex - 1]], !directPreviousNode.path.isEmpty {
            previousPath = directPreviousNode.path
        } else {
            var foundPath: [Int]?
            for index in stride(from: currentIndex - 1, through: 0, by: -1) {
                let candidateID = orderedIDs[index]
                if let candidatePath = output[candidateID]?.path, !candidatePath.isEmpty {
                    foundPath = candidatePath
                    break
                }
            }
            if let path = foundPath {
                previousPath = path
            } else {
                let nextRoot = nextSiblingIndex(under: [], nodes: output, excluding: assetID)
                previousPath = [nextRoot]
            }
        }

        let parentPath = Array(previousPath.dropLast())
        let nextIndex = nextSiblingIndex(under: parentPath, nodes: output, excluding: assetID)
        let oldPath = output[assetID]?.path ?? []
        let newPath = parentPath + [nextIndex]
        moveSubtree(of: assetID, from: oldPath, to: newPath, nodes: &output)
        return normalized(nodes: output, in: orderedIDs)
    }

    internal func test_applySetAsChildOfPrevious(assetID: String, orderedIDs: [String], nodes: [String: PhotoHierarchyNode]) -> [String: PhotoHierarchyNode] {
        guard let currentIndex = orderedIDs.firstIndex(of: assetID), currentIndex > 0 else { return nodes }
        var output = nodes

        var foundParentPath: [Int]?
        for index in stride(from: currentIndex - 1, through: 0, by: -1) {
            let candidateID = orderedIDs[index]
            if let candidatePath = output[candidateID]?.path, !candidatePath.isEmpty {
                foundParentPath = candidatePath
                break
            }
        }
        let parentPath: [Int]
        if let path = foundParentPath {
            parentPath = path
        } else {
            let nextRoot = nextSiblingIndex(under: [], nodes: output, excluding: assetID)
            parentPath = [nextRoot]
        }

        let oldPath = output[assetID]?.path ?? []
        let childIndex = nextChildIndex(of: parentPath, nodes: output)
        let newPath = parentPath + [childIndex]
        moveSubtree(of: assetID, from: oldPath, to: newPath, nodes: &output)
        return normalized(nodes: output, in: orderedIDs)
    }
    #endif
}
