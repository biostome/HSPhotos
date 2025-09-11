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
        let button = UIBarButtonItem(title: "选择", style: .plain, target: self, action: nil)
        button.menu = createSelectionMenu()
        return button
    }()
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 44 / 2.0
        button.backgroundColor = .white
        button.layer.shadowColor = UIColor.lightGray.cgColor
        button.layer.shadowRadius = 44 / 2.0
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.5
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.menu = createOperationMenu()
        return button
    }()
    
    private lazy var sortButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        button.tintColor = UIColor.systemBlue
        button.layer.cornerRadius = 44 / 2.0
        button.backgroundColor = .white
        button.layer.shadowColor = UIColor.lightGray.cgColor
        button.layer.shadowRadius = 44 / 2.0
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.5
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

        setupUI()
        loadPhoto()
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
            
            gridView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        navigationItem.rightBarButtonItem = selectBarButton
        
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
    
    private func loadPhoto() {
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var newAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            newAssets.append(asset)
        }
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
        self.assets = newAssets
        
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
                        let message = "排序耗时: \(String(format: "%.2f", duration))秒"
                        self.syncSuccess(message: message)
                    } else {
                        let message = "无法同步照片顺序到系统相册：\(message ?? "")"
                        self.syncFailed(message: message)
                    }
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
            if success { loadPhoto() }
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
                    let count = assets.count
                    let message = count == 1 ? "已移动 1 张照片" : "已移动 \(count) 张照片"
                    self.showAlert(title: "移动成功", message: message)
                    self.gridView.clearSelected()
                    self.loadPhoto() // 重新加载照片列表
                } else {
                    let message = error ?? "无法移动照片"
                    self.showAlert(title: "移动失败", message: message)
                }
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
                        let count = assets.count
                        let message = count == 1 ? "已删除 1 张照片" : "已删除 \(count) 张照片"
                        self.showAlert(title: "删除成功", message: message)
                        self.gridView.clearSelected()
                        self.loadPhoto() // 重新加载照片列表
                    } else {
                        let message = error ?? "无法删除照片"
                        self.showAlert(title: "删除失败", message: message)
                    }
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
    
    private func updateNavigationBar() {
        selectBarButton.menu = createSelectionMenu()
    }
    
    // MARK: - Menu Creation Methods
    
    private func createSelectionMenu() -> UIMenu {
        let multipleSelectAction = UIAction(title: "多选", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            self?.setSelectionMode(.multiple)
        }
        
        let rangeSelectAction = UIAction(title: "范围选择", image: UIImage(systemName: "square.grid.2x2")) { [weak self] _ in
            self?.setSelectionMode(.range)
        }
        
        let cancelAction = UIAction(title: "取消", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in
            self?.setSelectionMode(.none)
        }
        
        return UIMenu(
            title: "选择模式",
            children: [multipleSelectAction, rangeSelectAction, cancelAction]
        )
    }
    
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
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {
        updateOperationMenu()
    }
}

extension PhotoGridViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
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
