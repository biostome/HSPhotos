//
//  PhotoGridViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

class PhotoGridViewController: UIViewController {
    
    private lazy var searchTextField: SearchBarView = {
        let searchBarView = SearchBarView()
        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.delegate = self
        searchBarView.alpha = 0.0
        return searchBarView
    }()
    
    private lazy var gridView: PhotoGridView = {
        let view = PhotoGridView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private lazy var selectBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(toggleSelectionMode))
        return button
    }()
    
    private lazy var rangeSwitchItem: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "checkmark.seal"), style: .plain, target: self, action: #selector(toggleRangeSelection))
        button.tag = 0 // 0: 未选中, 1: 选中
        return button
    }()
    
    private lazy var undoBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.left"),
            style: .plain,
            target: self,
            action: #selector(undoAction)
        )
        button.isEnabled = false
        return button
    }()
    
    private lazy var redoBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.right"),
            style: .plain,
            target: self,
            action: #selector(redoAction)
        )
        button.isEnabled = false
        return button
    }()
    
    private lazy var menuButton: UIButton = {
        // iOS 26 新增的 Glass 样式
        var config = UIButton.Configuration.glass()
        config.image = UIImage(systemName: "ellipsis")
        config.baseForegroundColor = UIColor.systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        let button = UIButton(type: .custom)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.menu = createOperationMenu()
        return button
    }()
    
    private lazy var sortButton: UIButton = {
        // iOS 26 新增的 Glass 样式
        var config = UIButton.Configuration.glass()
        config.image = UIImage(systemName: "arrow.up.arrow.down")
        config.baseForegroundColor = UIColor.systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        let button = UIButton(type: .custom)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.menu = createSortMenu()
        return button
    }()
    
    private lazy var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = sortPreference.sortDescriptors
        return options
    }()
    
    private let collection: PHAssetCollection
    
    private var sortPreference: PhotoSortPreference = .custom
    
    private var assets: [PHAsset] = [] {
        didSet {
            self.gridView.assets = assets
        }
    }
    
    private var selectionMode: PhotoSelectionMode = .none {
        didSet {
            gridView.selectionMode = selectionMode
            updateNavigationBar()
            updateOperationMenu()
        }
    }
    
    private var lastContentOffsetY: CGFloat = 0
    private var searchTextFieldTopConstraint: NSLayoutConstraint!
    
    init(collection: PHAssetCollection) {
        self.collection = collection
                
        // 初始化排序偏好
        self.sortPreference = PhotoSortPreference.custom.preference(for: collection)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = collection.localizedTitle
        
        // 禁用大标题模式
        navigationItem.largeTitleDisplayMode = .never
        
        // 允许视图内容延伸到四周
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all

        setupUI()
        
        // 同步初始排序偏好到 PhotoGridView
        gridView.sortPreference = sortPreference
        // 设置当前相册引用（必须在loadPhoto之前设置）
        gridView.currentCollection = collection
        
        loadPhoto()
        setupUndoManager()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        
        view.addSubview(gridView)
        view.addSubview(searchTextField)
        
        // 创建搜索条的顶部约束
        searchTextFieldTopConstraint = searchTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            searchTextFieldTopConstraint,
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchTextField.heightAnchor.constraint(equalToConstant: 44),
            
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // 初始状态下的按钮顺序
        navigationItem.rightBarButtonItems = [selectBarButton, redoBarButton, undoBarButton]
        
        // 设置 gridView 的滚动委托
        gridView.scrollDelegate = self
        
        view.addSubview(menuButton)
        NSLayoutConstraint.activate([
            menuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.heightAnchor.constraint(equalToConstant: 44),
            menuButton.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        view.addSubview(sortButton)
        NSLayoutConstraint.activate([
            sortButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            sortButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sortButton.heightAnchor.constraint(equalToConstant: 44),
            sortButton.widthAnchor.constraint(equalToConstant: 44)
        ])

    }
    
    private func setupUndoManager() {
        // 定期检查撤销和重做状态
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateUndoRedoButtons()
            }
        }
    }
    
    private func updateUndoRedoButtons() {
        undoBarButton.isEnabled = canUndo
        redoBarButton.isEnabled = canRedo
    }
    
    @objc private func undoAction() {
        guard let action = UndoManagerService.shared.undo() else { return }
        
        let loadingAlert = UIAlertController(title: "撤销中", message: "正在撤销操作...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.undo(action) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    self.loadPhoto() // 重新加载照片列表
                } else {
                    self.showAlert(title: "撤销失败", message: error ?? "无法撤销操作")
                }
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    @objc private func redoAction() {
        guard let action = UndoManagerService.shared.redo() else { return }
        
        // 对于重做操作，我们需要执行原始操作而不是撤销操作
        let loadingAlert = UIAlertController(title: "重做中", message: "正在重做操作...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.redo(action) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    self.loadPhoto() // 重新加载照片列表
                } else {
                    self.showAlert(title: "重做失败", message: error ?? "无法重做操作")
                }
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    private func performRedo(action: UndoAction, completion: @escaping (Bool, String?) -> Void) {
        switch action.type {
        case .sort(let collection, let originalAssets, let sortedAssets):
            // 重做排序操作，恢复排序后的顺序
            PhotoChangesService.sync(sortedAssets: sortedAssets, for: collection, completion: completion)
        case .delete(let collection, let assets):
            // 重做删除操作，再次从相册删除照片
            PhotoChangesService.delete(assets: assets, for: collection, completion: completion)
        case .move(let sourceCollection, let destinationCollection, let assets):
            // 重做移动操作，再次将照片从源相册移到目标相册
            PhotoChangesService.move(assets: assets, from: sourceCollection, to: destinationCollection, completion: completion)
        case .copy(let sourceAssets, let destinationCollection):
            // 重做复制操作，再次将照片复制到目标相册
            PhotoChangesService.copy(assets: sourceAssets, to: destinationCollection, completion: completion)
        case .paste(let assets, let collection, let index):
            // 重做粘贴操作，再次将照片粘贴到相册
            PhotoChangesService.paste(assets: assets, into: collection, at: index, completion: completion)
        }
    }
    
    private func loadPhoto() {
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var newAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            newAssets.append(asset)
        }
        
        // 检查是否有自定义排序数据，如果没有则创建默认的
        let customOrder = PhotoOrder.order(for: collection)
        if customOrder.isEmpty && !newAssets.isEmpty {
            print("📝 初始化自定义排序数据")
            PhotoOrder.set(order: newAssets, for: collection)
        }
        
        // 如果是自定义排序，应用自定义排序
        if sortPreference == .custom {
            newAssets = PhotoOrder.apply(to: newAssets, for: collection)
        }
        
        // 清理无效的首图数据
        PhotoHeaderService.shared.cleanupInvalidHeaders(for: collection)
        
        self.assets = newAssets
    }
    
    private func onChanged(sort preference: PhotoSortPreference) {
        self.sortPreference = preference
        
        let options = PHFetchOptions()
        options.sortDescriptors = preference.sortDescriptors
        fetchOptions = options
        
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var newAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            newAssets.append(asset)
        }
        
        // 如果是自定义排序，应用自定义排序
        if preference == .custom {
            newAssets = PhotoOrder.apply(to: newAssets, for: collection)
        }
        
        self.assets = newAssets
        
        // 同步排序偏好到 PhotoGridView
        gridView.sortPreference = preference
        
        // 保存排序偏好
        preference.set(preference: self.collection)
    }

    private func onOrder() {
        do {
            let start = Date()
            let sortedAssets = try gridView.sort()
            self.assets = sortedAssets
            
            let loadingAlert = UIAlertController(title: "同步中", message: "正在将照片顺序同步到系统相册...", preferredStyle: .alert)
            present(loadingAlert, animated: true)
            
            PhotoChangesService.sync(sortedAssets: sortedAssets, for: self.collection) { [weak self] success, message in
                guard let self = self else { return }
                let duration = Date().timeIntervalSince(start)
                loadingAlert.dismiss(animated: true) {
                    if success {
                        // 保存自定义排序数据到 UserDefaults
                        PhotoOrder.set(order: sortedAssets, for: self.collection)
                        
                        // 记录撤销操作
                        let originalAssets = self.assets // 保存原始顺序用于撤销
                        let undoAction = UndoAction.sort(collection: self.collection, originalAssets: originalAssets, sortedAssets: sortedAssets)
                        self.addAction(undoAction)
                        
                        let message = "排序耗时: \(String(format: "%.2f", duration))秒"
                        self.syncSuccess(message: message)
                    } else {
                        let message = "无法同步照片顺序到系统相册：\(message ?? "")"
                        self.syncFailed(message: message)
                    }
                    // 更新按钮状态
                    self.updateUndoRedoButtons()
                }
            }
        } catch {
            gridView.clearSelected()
            showAlert(title: "排序失败", message: error.localizedDescription)
        }
    }
    
    private func onCopy() {
        AssetPasteboard.copyAssets(gridView.selectedAssets) { [weak self] success, message in
            guard let self = self else { return }
            let title = success ? "复制成功" : "复制失败"
            let alertMessage = success ? "已复制到剪切板" : (message ?? "无法复制到剪切板")
            self.showAlert(title: title, message: alertMessage)
        }
    }
    
    private func onPaste() {
        guard let assets = AssetPasteboard.assetsFromPasteboard() else {
            showAlert(title: "粘贴失败", message: "剪切板里没有资源")
            return
        }
        AssetPasteboard.pasteAssets(assets, into: collection) { [weak self] success, error in
            guard let self = self else { return }
            let title = success ? "粘贴成功" : "粘贴失败"
            let message = success ? "已粘贴到相册" : (error ?? "无法粘贴到相册")
            self.showAlert(title: title, message: message)
            if success {
                self.loadPhoto()
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    private func onDelete() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "删除失败", message: "请先选择要删除的照片")
            return
        }
        
        showDeleteConfirmationAlert(for: selectedAssets)
    }
    
    private func onMove() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "移动失败", message: "请先选择要移动的照片")
            return
        }
        
        // 显示相册选择器
        showAlbumPicker(for: selectedAssets)
    }
    
    private func showAlbumPicker(for assets: [PHAsset]) {
        // 获取所有用户创建的相册
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        var albumList: [PHAssetCollection] = []
        
        collections.enumerateObjects { collection, _, _ in
            // 排除当前相册
            if collection.localIdentifier != self.collection.localIdentifier {
                albumList.append(collection)
            }
        }
        
        guard !albumList.isEmpty else {
            showAlert(title: "移动失败", message: "没有找到其他相册")
            return
        }
        
        // 创建相册选择动作表
        let alert = UIAlertController(title: "选择目标相册", message: nil, preferredStyle: .actionSheet)
        
        for collection in albumList {
            let action = UIAlertAction(title: collection.localizedTitle ?? "未命名相册", style: .default) { _ in
                self.performMove(assets: assets, to: collection)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func performMove(assets: [PHAsset], to destinationCollection: PHAssetCollection) {
        let loadingAlert = UIAlertController(title: "移动中", message: "正在将照片移动到其他相册...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.move(assets: assets, from: self.collection, to: destinationCollection) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    // 记录撤销操作
                    let undoAction = UndoAction.move(sourceCollection: self.collection, destinationCollection: destinationCollection, assets: assets)
                    self.addAction(undoAction)
                    
                    let count = assets.count
                    let message = count == 1 ? "已移动 1 张照片" : "已移动 \(count) 张照片"
                    self.showAlert(title: "移动成功", message: message)
                    self.gridView.clearSelected()
                    self.loadPhoto() // 重新加载照片列表
                } else {
                    let message = error ?? "无法移动照片"
                    self.showAlert(title: "移动失败", message: message)
                }
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    private func showDeleteConfirmationAlert(for assets: [PHAsset]) {
        let count = assets.count
        let message = count == 1 ? "确定要从相册中删除这张照片吗？" : "确定要从相册中删除这\(count)张照片吗？"
        
        let alert = UIAlertController(title: "删除照片", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.performDelete(assets: assets)
        })
        
        present(alert, animated: true)
    }
    
    private func performDelete(assets: [PHAsset]) {
        let loadingAlert = UIAlertController(title: "删除中", message: "正在从相册中删除照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        let selectedAssets = self.gridView.selectedAssets
        // 删除照片和 Cell
        gridView.deleteAssets(assets: selectedAssets) { success in
            PhotoChangesService.delete(assets: selectedAssets, for: self.collection) { success, error in
                loadingAlert.dismiss(animated: true) {
                    if success {
                        // 记录撤销操作
                        let undoAction = UndoAction.delete(collection: self.collection, assets: selectedAssets)
                        self.addAction(undoAction)
                        
                        let count = assets.count
                        let message = count == 1 ? "已删除 1 张照片" : "已删除 \(count) 张照片"
                        self.showAlert(title: "删除成功", message: message)
                        self.gridView.clearSelected()
                        self.loadPhoto() // 重新加载照片列表
                    } else {
                        let message = error ?? "无法删除照片"
                        self.showAlert(title: "删除失败", message: message)
                    }
                    // 更新按钮状态
                    self.updateUndoRedoButtons()
                }
            }
        }

    }
    
    private func setSelectionMode(_ mode: PhotoSelectionMode) {
        if mode == .none {
            gridView.clearSelected()
            gridView.selectedStart = nil
            gridView.selectedEnd = nil
        }
        selectionMode = mode
    }
    
    /// 切换选择模式：点击进入多选模式，再次点击退出选择模式
    @objc private func toggleSelectionMode() {
        if selectionMode == .none {
            // 进入多选模式
            setSelectionMode(.multiple)
            selectBarButton.title = "取消"
        } else {
            // 退出选择模式
            setSelectionMode(.none)
            selectBarButton.title = "选择"
            // 同时关闭范围选择
            toggleRangeSelection(forceOff: true)
        }
        updateNavigationBar()
    }
    
    /// 切换范围选择开关
    @objc private func toggleRangeSelection(forceOff: Bool = false) {
        let isCurrentlyOn = rangeSwitchItem.tag == 1
        let shouldTurnOn = !isCurrentlyOn && !forceOff
        
        if shouldTurnOn {
            // 打开范围选择
            rangeSwitchItem.image = UIImage(systemName: "checkmark.seal.fill")
            rangeSwitchItem.tag = 1
            setSelectionMode(.range)
        } else {
            // 关闭范围选择
            rangeSwitchItem.image = UIImage(systemName: "checkmark.seal")
            rangeSwitchItem.tag = 0
            if selectionMode == .range {
                setSelectionMode(.multiple)
            }
        }
    }
    
    private func updateNavigationBar() {
        // 根据选择模式更新按钮状态
        if selectionMode == .none {
            selectBarButton.title = "选择"
            // 退出选择模式时，隐藏范围选择开关
            navigationItem.rightBarButtonItems = [selectBarButton, redoBarButton, undoBarButton]
        } else {
            selectBarButton.title = "取消"
            // 进入选择模式时，显示范围选择开关
            navigationItem.rightBarButtonItems = [selectBarButton, rangeSwitchItem, redoBarButton, undoBarButton]
        }
    }
    
    // MARK: - Undo Manager Helper Methods
    
    private func addAction(_ action: UndoAction) {
        UndoManagerService.shared.addUndoAction(action)
    }
    
    private var canUndo: Bool {
        return UndoManagerService.shared.canUndo
    }
    
    private var canRedo: Bool {
        return UndoManagerService.shared.canRedo
    }
    
    // MARK: - Menu Creation Methods
    
    private func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按照拍摄时间排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .creationDate ? .on : .off
        ) { [unowned self] _ in
            self.onChanged(sort: .creationDate)
            self.sortButton.menu = self.createSortMenu()
        }
        
        let modificationDateAction = UIAction(
            title: "按照最近加入时间排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .recentDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .recentDate)
            self?.sortButton.menu = self?.createSortMenu()
        }
        
        let customAction = UIAction(
            title: "按照自定义排序",
            image: UIImage(systemName: "hand.draw"),
            state: sortPreference == .custom ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .custom)
            self?.sortButton.menu = self?.createSortMenu()
        }
        
        return UIMenu(
            title: "排序方式",
            children: [customAction, modificationDateAction, creationDateAction]
        )
    }
    
    private func createOperationMenu() -> UIMenu {
        let attributes: UIMenuElement.Attributes = gridView.selectedAssets.isEmpty ? .disabled : []
        
        let copy = UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc"), attributes: attributes) { [weak self] _ in
            self?.onCopy()
        }
        
        let paste = UIAction(title: "粘贴", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
            self?.onPaste()
        }
        
        let sort = UIAction(title: "排序", image: UIImage(systemName: "arrow.up.arrow.down"), attributes: attributes) { [weak self] _ in
            self?.onOrder()
        }
        
        let delete = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: [attributes, .destructive].compactMap { $0 }.reduce([], { $0.union($1) })) { [weak self] _ in
            self?.onDelete()
        }
        
        let move = UIAction(title: "剪切", image: UIImage(systemName: "scissors"), attributes: attributes) { [weak self] _ in
            self?.onMove()
        }
        
        return UIMenu(title: "操作选项", children: [delete, move, paste, copy, sort])
    }
    
    private func updateOperationMenu() {
        menuButton.menu = createOperationMenu()
    }
    
    private func syncSuccess(message: String) {
        showAlert(title: "同步成功", message: message)
    }
    
    private func syncFailed(message: String) {
        showAlert(title: "同步失败", message: message)
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Search Methods
    
    private func performSearch(with text: String) {
        // 判断输入内容是否为数字
        if let index = Int(text) {
            // 输入的是数字，调用 scrollTo 方法
            gridView.scrollTo(index: index - 1) // 用户输入从1开始，数组索引从0开始
        } else {
            // 非数字内容的其他搜索逻辑
            print("执行搜索: \(text)")
        }
    }

}

extension PhotoGridViewController: PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {
        updateOperationMenu()
        updateUndoRedoButtons()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {
        updateOperationMenu()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset) {
        guard let index = self.assets.firstIndex(of: after) else {
            showAlert(title: "粘贴失败", message: "无法找到目标照片")
            return
        }
        
        let insertIndex = index + 1
        
        let loadingAlert = UIAlertController(title: "粘贴中", message: "正在粘贴照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 先更新本地数据和自定义排序
        var newAssets = self.assets
        newAssets.insert(contentsOf: assets, at: insertIndex)
        
        // 立即更新自定义排序数据
        PhotoOrder.set(order: newAssets, for: self.collection)
        
        // 提交到系统相册
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: self.collection) else {
                return
            }
            changeRequest.insertAssets(assets as NSArray, at: IndexSet(integer: insertIndex))
        }, completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true)
                
                guard let self = self else { return }
                
                if success {
                    // 直接使用我们维护的顺序，不重新加载
                    self.assets = newAssets
                    
                    // 记录撤销操作
                    let undoAction = UndoAction.paste(assets: assets, into: self.collection, at: insertIndex)
                    self.addAction(undoAction)
                    
                    // 清除选中状态
                    self.gridView.clearSelected()
                    
                    // 重要：粘贴操作后，自动切换到自定义排序模式
                    if self.sortPreference != .custom {
                        self.sortPreference = .custom
                        // 同步排序偏好到 PhotoGridView
                        self.gridView.sortPreference = .custom
                        // 保存排序偏好
                        PhotoSortPreference.custom.set(preference: self.collection)
                        // 更新排序按钮菜单
                        self.sortButton.menu = self.createSortMenu()
                    }
                    
                    self.showAlert(title: "粘贴成功", message: "已成功粘贴 \(assets.count) 张照片")
                } else {
                    // 失败时回滚自定义排序数据
                    PhotoOrder.set(order: self.assets, for: self.collection)
                    self.showAlert(title: "粘贴失败", message: error?.localizedDescription ?? "无法粘贴照片")
                }
                
                self.updateUndoRedoButtons()
                self.updateOperationMenu()
            }
        })
    }
}

// MARK: - SearchBarViewDelegate

extension PhotoGridViewController: SearchBarViewDelegate {
    func searchBarView(_ searchBarView: SearchBarView, didSearchWith text: String) {
        performSearch(with: text)
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoGridViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging {
            let currentOffsetY = scrollView.contentOffset.y
            let offsetDifference = currentOffsetY - lastContentOffsetY
            
            // 如果偏移量为0，显示搜索条（移动到导航栏下方）
            if currentOffsetY <= 0 {
                moveSearchBarToHidden()
            }
            // 向上滚动（负值）显示搜索条
            else if offsetDifference < 0 {
                moveSearchBarToHidden()
            }
            // 向下滚动（正值）隐藏搜索条（移动到导航栏上方）
            else if offsetDifference > 0 {
                moveSearchBarToVisible()
            }
            
            lastContentOffsetY = currentOffsetY
            
        }
    }
    
    private func moveSearchBarToVisible() {
        UIView.animate(withDuration: 0.3) {
            self.searchTextField.transform = CGAffineTransform(translationX: 0, y: 0)
            self.searchTextField.alpha = 1.0
        }
    }
    
    private func moveSearchBarToHidden() {
        let searchBarHeight = searchTextField.frame.height + 8 // 搜索条高度 + 间距
        UIView.animate(withDuration: 0.3) {
            self.searchTextField.transform = CGAffineTransform(translationX: 0, y: -searchBarHeight)
            self.searchTextField.alpha = 0.0
        }
    }
}
