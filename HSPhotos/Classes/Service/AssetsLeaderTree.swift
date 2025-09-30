//
//  AssetsLeaderTree.swift
//  HSPhotos
//
//  Created by Hans on 2025/1/27.
//

import Foundation

// 树节点 - 使用结构体
struct AssetsLeaderNode: Codable {
    let id: String
    var value: [String]                  // 当前节点的资产列表
    var children: [AssetsLeaderNode]     // 子节点
    
    // 不再需要 parent 引用，因为结构体是值类型
    
    init(id: String = UUID().uuidString,
         value: [String] = [],
         children: [AssetsLeaderNode] = []) {
        self.id = id
        self.value = value
        self.children = children
    }
    
    // MARK: - 树操作
    
    /// 添加子节点
    func addingChild(_ node: AssetsLeaderNode) -> AssetsLeaderNode {
        var newSelf = self
        newSelf.children.append(node)
        return newSelf
    }
    
    /// 插入子节点
    func insertingChild(_ node: AssetsLeaderNode, at index: Int) -> AssetsLeaderNode {
        var newSelf = self
        if index >= 0 && index <= newSelf.children.count {
            newSelf.children.insert(node, at: index)
        }
        return newSelf
    }
    
    /// 移除子节点
    func removingChild(_ nodeId: String) -> AssetsLeaderNode {
        var newSelf = self
        newSelf.children.removeAll { $0.id == nodeId }
        return newSelf
    }
    
    /// 移除指定位置的子节点
    func removingChild(at index: Int) -> (node: AssetsLeaderNode, removedChild: AssetsLeaderNode?) {
        var newSelf = self
        guard index >= 0 && index < children.count else {
            return (newSelf, nil)
        }
        let removed = newSelf.children.remove(at: index)
        return (newSelf, removed)
    }
    
    // MARK: - 树遍历
    
    /// 深度优先遍历
    func traverseDepthFirst(_ action: (AssetsLeaderNode) -> Void) {
        action(self)
        for child in children {
            child.traverseDepthFirst(action)
        }
    }
    
    /// 带路径的深度优先遍历
    func traverseDepthFirstWithPath(_ action: ([Int], AssetsLeaderNode) -> Void, currentPath: [Int] = []) {
        action(currentPath, self)
        for (index, child) in children.enumerated() {
            child.traverseDepthFirstWithPath(action, currentPath: currentPath + [index])
        }
    }
    
    /// 广度优先遍历
    func traverseBreadthFirst(_ action: (AssetsLeaderNode) -> Void) {
        var queue: [AssetsLeaderNode] = [self]
        while !queue.isEmpty {
            let node = queue.removeFirst()
            action(node)
            queue.append(contentsOf: node.children)
        }
    }
    
    // MARK: - 查询操作
    
    /// 通过ID查找节点
    func findNode(by id: String) -> AssetsLeaderNode? {
        if self.id == id { return self }
        
        for child in children {
            if let found = child.findNode(by: id) {
                return found
            }
        }
        return nil
    }
    
    /// 通过路径获取节点
    func getNode(at indexPath: [Int]) -> AssetsLeaderNode? {
        guard !indexPath.isEmpty else { return self }
        
        let firstIndex = indexPath.first!
        guard firstIndex >= 0 && firstIndex < children.count else { return nil }
        
        return children[firstIndex].getNode(at: Array(indexPath.dropFirst()))
    }
    
    /// 更新指定路径的节点
    func updatingNode(at indexPath: [Int], transform: (AssetsLeaderNode) -> AssetsLeaderNode) -> AssetsLeaderNode {
        guard !indexPath.isEmpty else { return transform(self) }
        
        var newSelf = self
        let firstIndex = indexPath.first!
        guard firstIndex >= 0 && firstIndex < children.count else { return self }
        
        let updatedChild = children[firstIndex].updatingNode(
            at: Array(indexPath.dropFirst()),
            transform: transform
        )
        newSelf.children[firstIndex] = updatedChild
        return newSelf
    }
    
    /// 获取节点的深度（相对于根节点）
    func depth(relativeTo root: AssetsLeaderNode) -> Int? {
        return root.findPath(to: self.id)?.count
    }
    
    /// 查找从当前节点到目标节点的路径
    func findPath(to nodeId: String, currentPath: [Int] = []) -> [Int]? {
        if self.id == nodeId { return currentPath }
        
        for (index, child) in children.enumerated() {
            if let path = child.findPath(to: nodeId, currentPath: currentPath + [index]) {
                return path
            }
        }
        return nil
    }
    
    /// 获取节点的高度（叶子节点高度为0）
    var height: Int {
        if children.isEmpty { return 0 }
        return children.map { $0.height + 1 }.max() ?? 0
    }
    
    /// 判断是否为叶子节点
    var isLeaf: Bool {
        return children.isEmpty
    }
    
    /// 获取所有后代节点
    var descendants: [AssetsLeaderNode] {
        var result: [AssetsLeaderNode] = []
        traverseDepthFirst { node in
            if node.id != self.id {
                result.append(node)
            }
        }
        return result
    }
    
    // MARK: - 节点操作
    
    /// 更新节点值
    func updatingValue(_ newValue: [String]) -> AssetsLeaderNode {
        var newSelf = self
        newSelf.value = newValue
        return newSelf
    }
    
    /// 插入资产
    func insertingAsset(_ asset: String, at index: Int) -> AssetsLeaderNode {
        var newSelf = self
        if index >= 0 && index <= newSelf.value.count {
            newSelf.value.insert(asset, at: index)
        }
        return newSelf
    }
    
    /// 移除资产
    func removingAsset(_ asset: String) -> AssetsLeaderNode {
        var newSelf = self
        newSelf.value.removeAll { $0 == asset }
        return newSelf
    }
    
    /// 克隆节点
    func clone() -> AssetsLeaderNode {
        let clonedChildren = children.map { $0.clone() }
        return AssetsLeaderNode(id: UUID().uuidString,
                              value: value,
                              children: clonedChildren)
    }
}

// 树容器 - 使用结构体
struct AssetsLeaderTree: Codable {
    let id: String
    var rootNodes: [AssetsLeaderNode]    // 多个根节点（森林）
    
    // 索引用于快速查询
    private var nodeIndex: [String: AssetsLeaderNode] = [:]
    private var pathIndex: [String: [Int]] = [:] // 节点路径索引
    private var leadingAssetIndex: [String: String] = [:] // [assetId: nodeId]
    
    init(id: String = UUID().uuidString, rootNodes: [AssetsLeaderNode] = []) {
        self.id = id
        self.rootNodes = rootNodes
        rebuildIndexes()
    }
    
    // MARK: - 索引管理
    
    mutating func rebuildIndexes() {
        nodeIndex.removeAll()
        pathIndex.removeAll()
        leadingAssetIndex.removeAll()
        
        for (rootIndex, rootNode) in rootNodes.enumerated() {
            rootNode.traverseDepthFirstWithPath { path, node in
                let fullPath = [rootIndex] + path
                nodeIndex[node.id] = node
                pathIndex[node.id] = fullPath
                
                // 构建首图索引
                if let leadingAsset = node.value.first {
                    leadingAssetIndex[leadingAsset] = node.id
                }
            }
        }
    }
    
    // MARK: - 快速查询
    
    /// 通过节点ID获取节点 - O(1)
    func getNode(by id: String) -> AssetsLeaderNode? {
        return nodeIndex[id]
    }
    
    /// 获取节点路径 - O(1)
    func getPath(for nodeId: String) -> [Int]? {
        return pathIndex[nodeId]
    }
    
    /// 判断资产是否为首图 - O(1)
    func isLeadingAsset(_ assetId: String) -> Bool {
        return leadingAssetIndex[assetId] != nil
    }
    
    /// 获取父节点路径
    func getParentPath(for nodeId: String) -> [Int]? {
        guard let path = getPath(for: nodeId), path.count > 1 else {
            return nil
        }
        return Array(path.dropLast())
    }
    
    /// 获取所有首图资产
    var allLeadingAssets: [String] {
        return Array(leadingAssetIndex.keys)
    }
    
    // MARK: - 树操作
    
    mutating func addRootNode(_ node: AssetsLeaderNode) {
        rootNodes.append(node)
        updateIndexesForNode(node, rootIndex: rootNodes.count - 1)
    }
    
    mutating func removeRootNode(at index: Int) -> AssetsLeaderNode? {
        guard index >= 0 && index < rootNodes.count else { return nil }
        let removedNode = rootNodes.remove(at: index)
        rebuildIndexes() // 需要重新构建索引
        return removedNode
    }
    
    private mutating func updateIndexesForNode(_ node: AssetsLeaderNode, rootIndex: Int) {
        node.traverseDepthFirstWithPath { path, node in
            let fullPath = [rootIndex] + path
            nodeIndex[node.id] = node
            pathIndex[node.id] = fullPath
            
            if let leadingAsset = node.value.first {
                leadingAssetIndex[leadingAsset] = node.id
            }
        }
    }
    
    // MARK: - 节点层级操作
    
    /// 将节点提升为根节点
    mutating func makeNodeRoot(_ nodeId: String) -> Bool {
        guard let path = getPath(for: nodeId),
              let node = getNode(by: nodeId),
              path.count > 1 else {
            return false // 已经是根节点或未找到
        }
        
        // 从原位置移除
        _ = removeNode(at: path)
        
        // 添加到根节点
        addRootNode(node)
        
        return true
    }
    
    /// 移除指定路径的节点
    @discardableResult
    mutating func removeNode(at path: [Int]) -> AssetsLeaderNode? {
        guard !path.isEmpty else { return nil }
        
        if path.count == 1 {
            // 根节点
            return removeRootNode(at: path[0])
        } else {
            // 子节点
            let parentPath = Array(path.dropLast())
            let childIndex = path.last!
            
            if let parent = getNode(at: parentPath) {
                let (updatedParent, removed) = parent.removingChild(at: childIndex)
                // 更新树
                _ = updatingNode(at: parentPath) { _ in updatedParent }
                return removed
            }
        }
        return nil
    }
    
    /// 更新指定路径的节点
    @discardableResult
    mutating func updatingNode(at path: [Int], transform: (AssetsLeaderNode) -> AssetsLeaderNode) -> Bool {
        guard !path.isEmpty else { return false }
        
        if path.count == 1 {
            // 根节点
            let rootIndex = path[0]
            guard rootIndex >= 0 && rootIndex < rootNodes.count else { return false }
            rootNodes[rootIndex] = transform(rootNodes[rootIndex])
            rebuildIndexes()
            return true
        } else {
            // 子节点
            let rootIndex = path[0]
            guard rootIndex >= 0 && rootIndex < rootNodes.count else { return false }
            
            let childPath = Array(path.dropFirst())
            let updatedRoot = rootNodes[rootIndex].updatingNode(at: childPath, transform: transform)
            rootNodes[rootIndex] = updatedRoot
            rebuildIndexes()
            return true
        }
    }
    
    /// 获取指定路径的节点
    func getNode(at path: [Int]) -> AssetsLeaderNode? {
        guard !path.isEmpty else { return nil }
        
        if path.count == 1 {
            let rootIndex = path[0]
            return rootIndex >= 0 && rootIndex < rootNodes.count ? rootNodes[rootIndex] : nil
        } else {
            let rootIndex = path[0]
            guard rootIndex >= 0 && rootIndex < rootNodes.count else { return nil }
            
            let childPath = Array(path.dropFirst())
            return rootNodes[rootIndex].getNode(at: childPath)
        }
    }
    
    // MARK: - 统计信息
    
    /// 获取树的总节点数
    var totalNodeCount: Int {
        return nodeIndex.count
    }
    
    /// 获取树的深度（最大深度）
    var maxDepth: Int {
        return rootNodes.map { $0.height }.max() ?? 0
    }
    
    /// 获取所有叶子节点
    var leafNodes: [AssetsLeaderNode] {
        return nodeIndex.values.filter { $0.isLeaf }
    }
}

// MARK: - 数据持久化扩展
extension AssetsLeaderTree {
    
    /// 保存到应用支持目录（推荐）
    func saveToFile(_ fileName: String = "assets_leader_tree.json") throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(self)
        let fileURL = AssetsLeaderTree.getApplicationSupportDirectory().appendingPathComponent(fileName)
        
        // 确保目录存在
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                              withIntermediateDirectories: true,
                                              attributes: nil)
        
        try data.write(to: fileURL, options: .atomic)
        print("数据已保存到: \(fileURL.path)")
    }
    
    /// 从应用支持目录加载
    static func loadFromFile(_ fileName: String = "assets_leader_tree.json") throws -> AssetsLeaderTree? {
        let fileURL = getApplicationSupportDirectory().appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let tree = try decoder.decode(AssetsLeaderTree.self, from: data)
        
        return tree
    }
    
    /// 获取应用支持目录URL
    private static func getApplicationSupportDirectory() -> URL {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    
}

// MARK: - 使用示例
extension AssetsLeaderTree {
    static func example() -> AssetsLeaderTree {
        let root1 = AssetsLeaderNode(id: "root1", value: ["photo1", "photo2"])
        let root2 = AssetsLeaderNode(id: "root2", value: ["photo3", "photo4"])
        
        let child1 = AssetsLeaderNode(id: "child1", value: ["child_photo1"])
        let child2 = AssetsLeaderNode(id: "child2", value: ["child_photo2"])
        
        // 使用值语义构建树
        let root1WithChildren = root1
            .addingChild(child1)
            .addingChild(child2)
        
        var tree = AssetsLeaderTree()
        tree.addRootNode(root1WithChildren)
        tree.addRootNode(root2)
        
        return tree
    }
}
