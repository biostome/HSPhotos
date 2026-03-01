//
//  FolderViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

/// 文件夹详情视图控制器，显示文件夹内的所有子相册
class FolderViewController: UIViewController {
    
    private let collectionList: PHCollectionList
    private var subAlbums: [PHAssetCollection] = []
    private let backgroundGradientLayer = CAGradientLayer()
    
    lazy var albumListView: AlbumListView = {
        let view = AlbumListView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    init(collectionList: PHCollectionList) {
        self.collectionList = collectionList
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSubAlbums()
        setupTraitChangeObserver()
    }
    
    private func setupUI() {
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
        
        // 设置标题
        title = collectionList.localizedTitle ?? "文件夹"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    private func loadSubAlbums() {
        var items: [AlbumListItem] = []
        
        // 获取当前文件夹下的所有子内容
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let collections = PHCollection.fetchCollections(in: collectionList, options: options)
        
        // 遍历所有子内容，区分文件夹和相册
        collections.enumerateObjects { (collection, _, _) in
            if let subFolder = collection as? PHCollectionList {
                // 子文件夹
                items.append(AlbumListItem(type: .folder(subFolder)))
            } else {
                // 子相册
                let subAlbum = collection as! PHAssetCollection
                items.append(AlbumListItem(type: .album(subAlbum)))
            }
        }
        
        // 设置到列表视图
        self.albumListView.collections = items
    }
    
    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: FolderViewController, previousTraitCollection: UITraitCollection) in
            // 当界面模式改变时，更新渐变背景颜色
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
            let isDark = self.traitCollection.userInterfaceStyle == .dark
            self.backgroundGradientLayer.colors = isDark ? darkColors : lightColors
        }
    }
    
    deinit {
        // 系统会自动处理trait变化注册的清理
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
    }
}

extension FolderViewController: AlbumListViewDelegate {
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt collection: PHAssetCollection) {
        let photoVC = PhotoGridViewController(collection: collection)
        navigationController?.pushViewController(photoVC, animated: true)
    }
    
    func albumListView(_ albumListView: AlbumListView, didSelectFolder collectionList: PHCollectionList) {
        // 嵌套文件夹（如果存在）
        let folderVC = FolderViewController(collectionList: collectionList)
        navigationController?.pushViewController(folderVC, animated: true)
    }
}
