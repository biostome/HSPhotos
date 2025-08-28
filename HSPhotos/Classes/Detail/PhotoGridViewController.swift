//
//  PhotoGridViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

class PhotoGridViewController: UIViewController {
    
    private let collection: PHAssetCollection
    
    public var assets: [PHAsset] = [] {
        didSet{
            self.gridView.assets = assets
        }
    }
    
    private lazy var gridView: PhotoGridView = {
        let view = PhotoGridView()
        view.translatesAutoresizingMaskIntoConstraints = false
//        view.delegate = self
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
    
    private var selectedPhotos: [IndexPath] = []
    
    private var isSelectionMode = false {
        didSet{
            self.gridView.isSelectionMode = isSelectionMode
        }
    }
    
    private lazy var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        
        // 读取系统相册排序偏好
        let key = "system_sort_preference_\(collection.localIdentifier)"
        if let sortPreference = UserDefaults.standard.string(forKey: key) {
            // 根据保存的排序偏好设置 sortDescriptors
            switch sortPreference {
            case "creationDate":
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            case "modificationDate":
                options.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
            case "filename":
                options.sortDescriptors = [NSSortDescriptor(key: "filename", ascending: true)]
            case "custom":
                // 自定义排序，不设置 sortDescriptors，使用相册的自定义排序
                break
            default:
                // 默认按创建时间倒序
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            }
        } else {
            // 如果没有保存的排序偏好，使用相册的自定义排序
            // 系统相册会按照用户自定义的顺序返回照片
        }
        
        return options
    }()

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
    }
    
    private func loadPhoto() {
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var newAssets: [PHAsset] = []
        assets.enumerateObjects { asset, index, _ in
            newAssets.append(asset)
        }
        self.assets = newAssets
    }
    
    @objc private func selectionButtonTapped(sender: UIBarButtonItem) {
        print("selectionButtonTapped")
        self.isSelectionMode = true
        self.navigationItem.rightBarButtonItem = doneBarButton
    }
    

    
    @objc private func doneButtonTapped(sender: UIBarButtonItem) {
        print("doneButtonTapped")
        
        self.isSelectionMode = false
        self.navigationItem.rightBarButtonItem = selectBarButton
        
        do {
            
            let start = Date()
            // 执行排序操作
            let sortedAssets = try self.gridView.sort()
            self.gridView.assets = sortedAssets
            
            // 清除选中状态
            self.gridView.clearSelected()
            
            let loadingAlert = UIAlertController(title: "同步中", message: "正在将照片顺序同步到系统相册...", preferredStyle: .alert)
            present(loadingAlert, animated: true)
            
            self.sync(sortedAssets: sortedAssets, for: self.collection) { success, message in
                // 显示耗时信息
                let duration = Date().timeIntervalSince(start)
                loadingAlert.dismiss(animated: true) {
                    if success {
                        // 获取同步后的结果并显示
                        let fetchResult = PHAsset.fetchAssets(in: self.collection, options: nil)
                        var syncedAssets: [PHAsset] = []
                        fetchResult.enumerateObjects { asset, _, _ in
                            syncedAssets.append(asset)
                        }
                        
//                        let message = """
//                                    排序前：\(sortedAssets.map { $0.localIdentifier }.joined(separator: ", "))
//                                    
//                                    排序后：\(syncedAssets.map { $0.localIdentifier }.joined(separator: ", "))
//                                    
//                                    排序耗时: \(String(format: "%.2f", duration))秒
//                                    """
                        let message = """
                                    排序耗时: \(String(format: "%.2f", duration))秒
                                    """
                        self.showAlert(title: "同步成功", message: message)
                    } else {
                        self.showAlert(title: "同步失败", message: "无法同步照片顺序到系统相册：\(message ?? "")")
                    }
                }
            }
            
        } catch {
            self.gridView.clearSelected()
            showAlert(title: "排序失败", message: error.localizedDescription)
        }
    }
    
    typealias SortCompletion = (Bool, String?) -> Void
    
    /// 将修改的顺序同步到系统相册
    /// - Parameters:
    ///   - sortedAssets: 已经改变顺序的数据
    ///   - collection: 目标相册
    func sync(sortedAssets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        // Check permission
        guard PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .limited else {
            completion(false, "No photo library access permission")
            return
        }
        
        // Fetch original assets efficiently
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        let count = fetchResult.count
        guard count > 0 else {
            completion(false, "No assets in collection")
            return
        }
        
        var originalAssets = [PHAsset]()
        originalAssets.reserveCapacity(count)
        for i in 0..<count {
            originalAssets.append(fetchResult.object(at: i))
        }
        
        // Validate sortedAssets
        guard sortedAssets.count == count else {
            completion(false, "Sorted assets count must match collection assets count")
            return
        }
        
        // Validate that sortedAssets contains exactly the same assets as originalAssets
        let originalSet = Set(originalAssets.map { $0.localIdentifier })
        let sortedSet = Set(sortedAssets.map { $0.localIdentifier })
        guard originalSet == sortedSet else {
            completion(false, "Sorted assets must exactly match the original assets")
            return
        }
        
        // Convert sortedAssets to NSArray for replaceAssets
        let sortedAssetsNSArray = sortedAssets as NSArray
        
        // Execute reorder using replaceAssets
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: collection) else {
                return
            }
            
            let indices = IndexSet(0..<count)
            changeRequest.replaceAssets(at: indices, withAssets: sortedAssetsNSArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Sync operation failed"))
            }
        })
    }
    
    /// 保存相册的排序偏好
    /// - Parameter sortPreference: 排序偏好 ("creationDate", "modificationDate", "filename", "custom")
    func saveSortPreference(_ sortPreference: String) {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        UserDefaults.standard.set(sortPreference, forKey: key)
        
        // 更新 fetchOptions 并重新加载照片
        updateFetchOptionsSorting()
        loadPhoto()
    }
    
    /// 获取相册的排序偏好
    /// - Returns: 排序偏好字符串，如果没有设置则返回 nil
    func getSortPreference() -> String? {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    /// 更新 fetchOptions 的排序设置
    private func updateFetchOptionsSorting() {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        if let sortPreference = UserDefaults.standard.string(forKey: key) {
            switch sortPreference {
            case "creationDate":
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            case "modificationDate":
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
            case "filename":
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "filename", ascending: true)]
            case "custom":
                fetchOptions.sortDescriptors = nil
            default:
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            }
        } else {
            fetchOptions.sortDescriptors = nil
        }
    }
}

extension PhotoGridViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
