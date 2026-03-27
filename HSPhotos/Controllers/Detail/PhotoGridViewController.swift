//
//  PhotoGridViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

class PhotoGridViewController: BasePhotoViewController {
    
    private lazy var shareButton: UIButton = {
        var config = UIButton.Configuration.glass()
        config.image = UIImage(systemName: "square.and.arrow.up")
        config.baseForegroundColor = UIColor.systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        let button = UIButton(type: .custom)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(didTapShareButton), for: .touchUpInside)
        button.isHidden = true
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
        config.image = UIImage(systemName: "line.3.horizontal.decrease")
        config.baseForegroundColor = UIColor.systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        let button = UIButton(type: .custom)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.menu = createSortMenu()
        return button
    }()
    
    override init(collection: PHAssetCollection) {
        super.init(collection: collection)
        
        // 初始化排序偏好
        self.sortPreference = PhotoSortPreference.albumCustom.preference(for: collection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 添加底部排序按钮
        view.addSubview(sortButton)
        view.addSubview(shareButton)
        NSLayoutConstraint.activate([
            sortButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            sortButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sortButton.heightAnchor.constraint(equalToConstant: 44),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            
            shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            shareButton.widthAnchor.constraint(equalToConstant: 44)
        ])
        
        updateBottomActionButtons()
    }
    
    // MARK: - 重写方法
    
    override func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按最旧的排最前排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .albumOldestFirst ? .on : .off
        ) { [unowned self] _ in
            self.onChanged(sort: .albumOldestFirst)
            self.sortButton.menu = self.createSortMenu()
        }
        
        let modificationDateAction = UIAction(
            title: "按最新的排最前排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .albumNewestFirst ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .albumNewestFirst)
            self?.sortButton.menu = self?.createSortMenu()
        }
        
        let customAction = UIAction(
            title: "按自定义排序",
            image: UIImage(systemName: "hand.draw"),
            state: sortPreference == .albumCustom ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .albumCustom)
            self?.sortButton.menu = self?.createSortMenu()
        }
        
        return UIMenu(
            title: "排序方式",
            children: [customAction, modificationDateAction, creationDateAction]
        )
    }
    
    override func updateOperationMenu() {
        menuButton.menu = createOperationMenu()
        menuBarButton.menu = createOperationMenu()
    }
    
    override func updateNavigationBar() {
        super.updateNavigationBar()
        updateBottomActionButtons()
    }
    
    @objc(photoGridView:didPasteAssets:after:) override func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset) {
        guard let index = self.assets.firstIndex(of: after) else {
            showAlert(title: "粘贴失败", message: "无法找到目标照片")
            return
        }
        
        let insertIndex = index + 1
        
        let loadingAlert = UIAlertController(title: "粘贴中", message: "正在粘贴照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
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
                    // 以系统相册顺序回读，确保与系统保持一致
                    self.loadPhoto()
                    
                    // 记录撤销操作
                    let undoAction = UndoAction.paste(assets: assets, into: self.collection, at: insertIndex)
                    self.addAction(undoAction)
                    
                    // 清除选中状态
                    self.gridView.clearSelected()
                    
                    // 重要：粘贴操作后，自动切换到自定义排序模式
                    if self.sortPreference != .albumCustom {
                        self.sortPreference = .albumCustom
                        // 同步排序偏好到 PhotoGridView
                        self.gridView.sortPreference = .albumCustom
                        // 保存排序偏好
                        PhotoSortPreference.albumCustom.set(preference: self.collection)
                        // 更新排序按钮菜单
                        self.sortButton.menu = self.createSortMenu()
                    }
                    
                    self.showAlert(title: "粘贴成功", message: "已成功粘贴 \(assets.count) 张照片")
                } else {
                    self.showAlert(title: "粘贴失败", message: error?.localizedDescription ?? "无法粘贴照片")
                }
                
                self.updateUndoRedoButtons()
                self.updateOperationMenu()
            }
        })
    }
    
    override func updateSelectAllButton() {
        let isAllSelected = isAllAssetsSelected()
        if isAllSelected {
            // 已全选，显示取消全选按钮
            navigationItem.setLeftBarButtonItems([deselectAllBarButton], animated: true)
        } else {
            // 未全选，显示全选按钮
            navigationItem.setLeftBarButtonItems([selectAllBarButton], animated: true)
        }
        updateBottomActionButtons()
    }
    
    @objc private func didTapShareButton() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else { return }
        
        let addToAlbumActivity = AddToAlbumActivity { [weak self] in
            self?.showAddToAlbumPicker(for: selectedAssets)
        }
        
        let activityItems: [Any] = [makeSharePlaceholderText(for: selectedAssets.count)]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: [addToAlbumActivity])
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityVC, animated: true)
    }
    
    private func updateBottomActionButtons() {
        let inSelectionMode = selectionMode != .none
        let hasSelectedAssets = !gridView.selectedAssets.isEmpty
        
        sortButton.isHidden = inSelectionMode
        shareButton.isHidden = !inSelectionMode
        shareButton.isEnabled = hasSelectedAssets
    }
    
    private func makeSharePlaceholderText(for count: Int) -> String {
        if count == 1 {
            return "已选择 1 张照片"
        }
        return "已选择 \(count) 张照片"
    }
}


private final class AddToAlbumActivity: UIActivity {
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.hsphotos.activity.addToAlbum")
    }
    
    override var activityTitle: String? {
        "添加到相簿"
    }
    
    override var activityImage: UIImage? {
        UIImage(systemName: "plus.rectangle.on.folder")
    }
    
    override class var activityCategory: UIActivity.Category {
        .action
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
    }
    
    override func perform() {
        activityDidFinish(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.action()
        }
    }
}
