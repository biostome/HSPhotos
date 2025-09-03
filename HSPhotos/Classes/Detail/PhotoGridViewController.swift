//
//  PhotoGridViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

class PhotoGridViewController: UIViewController {
    
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
    
    init(collection: PHAssetCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = collection.localizedTitle
        setupUI()
        loadPhoto()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        view.addSubview(gridView)
        
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        navigationItem.rightBarButtonItem = selectBarButton
        
        view.addSubview(menuButton)
        NSLayoutConstraint.activate([
            menuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.heightAnchor.constraint(equalToConstant: 44),
            menuButton.widthAnchor.constraint(equalToConstant: 60)
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
        gridView.clearSelected()
        gridView.selectedStart = nil
        gridView.selectedEnd = nil
        selectionMode = mode
    }
    
    private func updateNavigationBar() {
        selectBarButton.menu = createSelectionMenu()
    }
    
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
        
        return UIMenu(title: "操作选项", children: [paste, copy, sort, delete])
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

}

extension PhotoGridViewController: PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didSelctedItems assets: [PHAsset]) {
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
