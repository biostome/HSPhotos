//
//  AlbumListViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos


class AlbumListViewController: UIViewController {

    private var albumListItems: [AlbumListItem] = []
    private let backgroundGradientLayer = CAGradientLayer()
    
    lazy var albumListView: AlbumListView = {
        let view = AlbumListView()
        view.translatesAutoresizingMaskIntoConstraints = false;
        view.delegate = self
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadAlbums()
    }
    
    private func setupUI(){
        // 配置渐变背景
        let lightColors: [CGColor] = [
            UIColor(red: 0.91, green: 0.96, blue: 1.00, alpha: 1.0).cgColor,
            UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0).cgColor,
            UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1.0).cgColor
        ]
        let darkColors: [CGColor] = [
            UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor,
            UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0).cgColor
        ]
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundGradientLayer.colors = isDark ? darkColors : lightColors
        backgroundGradientLayer.locations = [0.0, 0.45, 1.0]
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        
        view.addSubview(albumListView)
        NSLayoutConstraint.activate([
            albumListView.topAnchor.constraint(equalTo: view.topAnchor),
            albumListView.leftAnchor.constraint(equalTo: view.leftAnchor),
            albumListView.rightAnchor.constraint(equalTo: view.rightAnchor),
            albumListView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupNavigationBar() {
        title = "相册"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // 添加创建相册按钮
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createAlbum))
        navigationItem.rightBarButtonItem = addButton
        
        // 允许视图内容延伸到四周
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
    }
    
    @objc private func createAlbum() {
        // 显示输入框让用户输入相册名称
        let alertController = UIAlertController(title: "创建相册", message: "请输入相册名称", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "相册名称"
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let createAction = UIAlertAction(title: "创建", style: .default) { [weak self] _ in
            guard let self = self, let albumName = alertController.textFields?.first?.text, !albumName.isEmpty else {
                return
            }
            
            // 创建新相册
            self.performCreateAlbum(with: albumName)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(createAction)
        
        present(alertController, animated: true)
    }
    
    private func performCreateAlbum(with name: String) {
        // 请求权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self, status == .authorized else {
                    self?.showPermissionViewController()
                    return
                }
                
                // 创建相册
                var albumPlaceholder: PHObjectPlaceholder?
                
                PHPhotoLibrary.shared().performChanges {
                    let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                    albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                } completionHandler: { [weak self] success, error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if success, let albumPlaceholder = albumPlaceholder {
                            // 重新加载相册列表
                            self.albumListItems.removeAll()
                            self.loadAlbums()
                            
                            // 延迟一下，确保相册列表已经加载完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // 查找新创建的相册
                                if let newAlbum = self.albumListItems.first(where: { $0.title == name }) {
                                    // 找到新相册在数组中的索引
                                    if let index = self.albumListItems.firstIndex(where: { $0.localIdentifier == newAlbum.localIdentifier }) {
                                        // 滚动到新创建的相册位置
                                        let indexPath = IndexPath(item: index, section: 0)
                                        self.albumListView.scrollToItem(at: indexPath, at: .top, animated: true)
                                    }
                                }
                            }
                        } else {
                            // 显示错误信息
                            let errorMessage = error?.localizedDescription ?? "创建相册失败"
                            let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "确定", style: .default))
                            self.present(alertController, animated: true)
                        }
                    }
                }
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 当界面模式改变时，更新渐变背景颜色
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            let lightColors: [CGColor] = [
                UIColor(red: 0.91, green: 0.96, blue: 1.00, alpha: 1.0).cgColor,
                UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0).cgColor,
                UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1.0).cgColor
            ]
            let darkColors: [CGColor] = [
                UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0).cgColor
            ]
            let isDark = traitCollection.userInterfaceStyle == .dark
            backgroundGradientLayer.colors = isDark ? darkColors : lightColors
        }
    }
    
    private func checkPermissionStatus() {
        let status = PhotoPermissionManager.shared.getCurrentPermissionStatus()
        if status == .denied {
            showPermissionViewController()
        } else if status == .authorized || status == .limited {
            loadAlbums()
        }
    }
    
    private func showPermissionViewController() {
        let permissionVC = PermissionViewController()
        permissionVC.modalPresentationStyle = .fullScreen
        present(permissionVC, animated: false)
    }
    
    private func loadAlbums() {
        var items: [AlbumListItem] = []
        
        // 1. 加载所有文件夹
        let folderOptions = PHFetchOptions()
        folderOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let allFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: folderOptions)
        
        // 2. 加载所有相册
        let albumOptions = PHFetchOptions()
        albumOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let allAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumOptions)
        
        // 3. 检查每个文件夹是否有父文件夹
        var topLevelFolders: [PHCollectionList] = []
        allFolders.enumerateObjects { collectionList, _, _ in
            // 获取所有可能包含此文件夹的父文件夹
            let parentFolderOptions = PHFetchOptions()
            let parentFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: parentFolderOptions)
            
            var hasParent = false
            parentFolders.enumerateObjects { parentFolder, _, stop in
                let subCollections = PHCollection.fetchCollections(in: parentFolder, options: nil)
                subCollections.enumerateObjects { subCollection, _, stopSub in
                    if subCollection.localIdentifier == collectionList.localIdentifier {
                        hasParent = true
                        stop.pointee = true
                        stopSub.pointee = true
                    }
                }
            }
            
            if !hasParent {
                topLevelFolders.append(collectionList)
            }
        }
        
        // 4. 检查每个相册是否有父文件夹
        var topLevelAlbums: [PHAssetCollection] = []
        allAlbums.enumerateObjects { collection, _, _ in
            // 获取所有可能包含此相册的父文件夹
            let parentFolderOptions = PHFetchOptions()
            let parentFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: parentFolderOptions)
            
            var hasParent = false
            parentFolders.enumerateObjects { parentFolder, _, stop in
                let subCollections = PHCollection.fetchCollections(in: parentFolder, options: nil)
                subCollections.enumerateObjects { subCollection, _, stopSub in
                    if subCollection.localIdentifier == collection.localIdentifier {
                        hasParent = true
                        stop.pointee = true
                        stopSub.pointee = true
                    }
                }
            }
            
            if !hasParent {
                topLevelAlbums.append(collection)
            }
        }
        
        // 5. 添加顶级文件夹
        for folder in topLevelFolders {
            items.append(AlbumListItem(type: .folder(folder)))
        }
        
        // 6. 添加顶级相册
        for album in topLevelAlbums {
            items.append(AlbumListItem(type: .album(album)))
        }
        
        self.albumListItems = items
        self.albumListView.collections = self.albumListItems
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 更新渐变层的frame
        backgroundGradientLayer.frame = view.bounds
    }
}

extension AlbumListViewController: AlbumListViewDelegate {
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt collection: PHAssetCollection) {
        let photoVC = PhotoGridViewController(collection: collection)
        navigationController?.pushViewController(photoVC, animated: true)
    }
    
    func albumListView(_ albumListView: AlbumListView, didSelectFolder collectionList: PHCollectionList) {
        // 显示文件夹内的子相册列表
        let folderVC = FolderViewController(collectionList: collectionList)
        navigationController?.pushViewController(folderVC, animated: true)
    }
}
