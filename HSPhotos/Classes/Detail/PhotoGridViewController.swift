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
        let button = UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(selectionButtonTapped(sender: )))
        return button
    }()
    
    private lazy var doneBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "完成", style: .plain, target: self, action: #selector(doneButtonTapped(sender: )))
        return button
    }()

    // menu button
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
        button.showsMenuAsPrimaryAction = true // 点击按钮直接显示菜单
        // 定义菜单
        let copy = UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { _ in
            print("👉 复制")
            self.onCopy()
        }
        
        let paste = UIAction(title: "粘贴", image: UIImage(systemName: "doc.on.doc")) { _ in
            print("👉 粘贴")
            self.onPaste()
        }
        let sort = UIAction(title: "排序", image: UIImage(systemName: "trash")) { _ in
            print("👉 排序")
            self.onOrder()
        }

        button.menu = UIMenu(title: "操作选项", children: [paste, copy, sort])
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
        didSet{
            self.gridView.assets = assets
        }
    }
    
    private var isSelectionMode = false {
        didSet{
            self.gridView.isSelectionMode = isSelectionMode
            self.navigationItem.rightBarButtonItem = isSelectionMode ? doneBarButton : selectBarButton
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
        
        self.navigationItem.rightBarButtonItem = selectBarButton
        
        
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
        assets.enumerateObjects { asset, index, _ in
            newAssets.append(asset)
        }
        
        // 如果为空就保存一次
        // 需求是不能受到系统相册的影响
        let orders = PhotoOrder.order(for: self.collection)
        if orders.count == 0{
            PhotoOrder.set(order: newAssets, for: self.collection)
        }
        
        if self.sortPreference == .custom {
            newAssets = PhotoOrder.apply(to: newAssets, for: collection)
        }
        
        self.assets = newAssets
    }
    
    /// 排序方式改变
    /// - Parameter preference: 
    private func onChanged(sort preference: PhotoSortPreference) {
        self.sortPreference = preference
        
        let options = PHFetchOptions()
        options.sortDescriptors = preference.sortDescriptors
        fetchOptions = options
        
        
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var newAssets: [PHAsset] = []
        assets.enumerateObjects { asset, index, _ in
            newAssets.append(asset)
        }
        
        if self.sortPreference == .custom {
            newAssets = PhotoOrder.apply(to: newAssets, for: collection)
        }
        
        self.assets = newAssets
    }
    
    private func onOrder(){
        do {
            // 开始记录同步时间
            let start = Date()
            
            // 执行排序操作
            let sortedAssets = try self.gridView.sort()
            
            // 重新交给视图刷新
            self.assets = sortedAssets
            
            // 保存自定义排序
            PhotoOrder.set(order: sortedAssets, for: self.collection)
            
            // 清除选中状态
            self.gridView.clearSelected()
            
            // 开始同步
            let loadingAlert = UIAlertController(title: "同步中", message: "正在将照片顺序同步到系统相册...", preferredStyle: .alert)
            present(loadingAlert, animated: true)
            
            PhotoSyncService.sync(sortedAssets: sortedAssets, for: self.collection) { success, message in
                // 显示耗时信息
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
            self.gridView.clearSelected()
            showAlert(title: "排序失败", message: error.localizedDescription)
        }
    }
    
    private func onCopy(){
        AssetPasteboard.copyAssets(self.gridView.selectedAssets) { success, message in
            print(success ? "✅ 已复制到剪切板" : "❌ 复制失败: \(message ?? "")")
        }
    }
    
    private func onPaste(){
        // 2. 从剪切板获取（不一定粘贴）
        guard let assets = AssetPasteboard.assetsFromPasteboard() else {
            print("👉 剪切板里没有资源")
            return
        }
        print("👉 剪切板里有 \(assets.count) 个资源")
        
        AssetPasteboard.pasteAssets(assets, into: collection) { success, error in
            print(success ? "✅ 已粘贴到相册" : "❌ 粘贴失败: \(error ?? "")")
            self.loadPhoto()
        }
    }

    /// 选择按钮点击
    @objc private func selectionButtonTapped(sender: UIBarButtonItem) {
        self.isSelectionMode = true
    }
    
    @objc private func doneButtonTapped(sender: UIBarButtonItem) {
        self.isSelectionMode = false
        self.gridView.clearSelected()
        self.updateMenus()
    }

    /// 同步成功
    /// - Parameter message: 提示消息
    private func syncSuccess(message: String) {
        self.showAlert(title: "同步成功", message: message)
    }
    
    /// 同步失败
    /// - Parameter message: 提示消息
    private func syncFailed(message: String) {
        self.showAlert(title: "同步失败", message: message)
    }
    
    private func updateMenus(){
        let attributes: UIMenuElement.Attributes = gridView.selectedAssets.isEmpty ? .disabled : []
        // 定义菜单
        let copy = UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc"), attributes: attributes) { _ in
            print("👉 复制")
            self.onCopy()
        }
        
        let paste = UIAction(title: "粘贴", image: UIImage(systemName: "doc.on.doc")) { _ in
            print("👉 粘贴")
            self.onPaste()
        }
        let sort = UIAction(title: "排序", image: UIImage(systemName: "trash"), attributes: attributes) { _ in
            print("👉 排序")
            self.onOrder()
        }

        menuButton.menu = UIMenu(title: "操作选项", children: [paste, copy, sort])
    }
}

extension PhotoGridViewController: PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {
        updateMenus()
    }
}

extension PhotoGridViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
