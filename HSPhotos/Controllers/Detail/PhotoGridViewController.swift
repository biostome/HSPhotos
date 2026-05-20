//
//  PhotoGridViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

class PhotoGridViewController: BasePhotoViewController {
    private var hierarchyShortcutAnchorAssetID: String?
    private var hierarchyShortcutLastShouldCollapse: Bool?
    
    private lazy var shareButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
            config.baseBackgroundColor = UIColor.systemGray5.withAlphaComponent(0.8)
        }
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
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
            config.baseBackgroundColor = UIColor.systemGray5.withAlphaComponent(0.8)
        }
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
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
            config.baseBackgroundColor = UIColor.systemGray5.withAlphaComponent(0.8)
        }
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

    private lazy var hierarchyCollapseButton: UIButton = {
        makeBottomIconButton(
            systemImageName: "rectangle.compress.vertical",
            accessibilityLabel: "折叠中心层级",
            action: #selector(didTapHierarchyCollapseButton)
        )
    }()

    private lazy var hierarchyExpandButton: UIButton = {
        makeBottomIconButton(
            systemImageName: "rectangle.expand.vertical",
            accessibilityLabel: "展开中心层级",
            action: #selector(didTapHierarchyExpandButton)
        )
    }()

    private lazy var overlaySettingsBarButton: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(didTapOverlaySettings)
        )
    }()
    
    override init(collection: PHAssetCollection) {
        super.init(collection: collection)
        
        // 初始化排序偏好
        self.sortPreference = PhotoSortPreference.custom.preference(for: collection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 添加底部排序按钮
        view.addSubview(sortButton)
        view.addSubview(hierarchyCollapseButton)
        view.addSubview(hierarchyExpandButton)
        view.addSubview(shareButton)
        NSLayoutConstraint.activate([
            sortButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            sortButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sortButton.heightAnchor.constraint(equalToConstant: 44),
            sortButton.widthAnchor.constraint(equalToConstant: 44),

            hierarchyCollapseButton.bottomAnchor.constraint(equalTo: sortButton.bottomAnchor),
            hierarchyCollapseButton.leadingAnchor.constraint(equalTo: sortButton.trailingAnchor, constant: 12),
            hierarchyCollapseButton.heightAnchor.constraint(equalToConstant: 44),
            hierarchyCollapseButton.widthAnchor.constraint(equalToConstant: 44),

            hierarchyExpandButton.bottomAnchor.constraint(equalTo: sortButton.bottomAnchor),
            hierarchyExpandButton.leadingAnchor.constraint(equalTo: hierarchyCollapseButton.trailingAnchor, constant: 12),
            hierarchyExpandButton.heightAnchor.constraint(equalToConstant: 44),
            hierarchyExpandButton.widthAnchor.constraint(equalToConstant: 44),
            
            shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            shareButton.widthAnchor.constraint(equalToConstant: 44)
        ])
        
        appendOverlaySettingsButtonIfNeeded()
        updateBottomActionButtons()
    }
    
    // MARK: - 重写方法
    
    override func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按最旧的排最前排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .creationDate ? .on : .off
        ) { [unowned self] _ in
            self.onChanged(sort: .creationDate)
            self.sortButton.menu = self.createSortMenu()
        }
        
        let newestSortAction = UIAction(
            title: "按最新的排最前排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .newest ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .newest)
            self?.sortButton.menu = self?.createSortMenu()
        }
        
        let customAction = UIAction(
            title: "按自定义排序",
            image: UIImage(systemName: "hand.draw"),
            state: sortPreference == .custom ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .custom)
            self?.sortButton.menu = self?.createSortMenu()
        }
        
        return UIMenu(
            title: "排序方式",
            children: [customAction, newestSortAction, creationDateAction]
        )
    }
    
    override func updateOperationMenu() {
        menuButton.menu = createOperationMenu()
        menuBarButton.menu = createOperationMenu()
        updateBottomActionButtons()
    }
    
    override func updateNavigationBar() {
        super.updateNavigationBar()
        appendOverlaySettingsButtonIfNeeded()
        updateBottomActionButtons()
    }

    @objc private func didTapOverlaySettings() {
        gridRouter.pushOverlaySettings()
    }

    private func appendOverlaySettingsButtonIfNeeded() {
        guard selectionMode == .none else { return }
        guard var current = navigationItem.rightBarButtonItems else {
            navigationItem.rightBarButtonItems = [overlaySettingsBarButton]
            return
        }
        if current.contains(where: { $0 === overlaySettingsBarButton }) { return }
        if let menuIndex = current.firstIndex(where: { $0 === menuBarButton }) {
            current.insert(overlaySettingsBarButton, at: menuIndex)
        } else {
            current.append(overlaySettingsBarButton)
        }
        navigationItem.rightBarButtonItems = current
    }
    
    override func refreshSortUIAfterPasteIfNeeded() {
        sortButton.menu = createSortMenu()
    }

    override func updateSelectAllButton() {
        super.updateSelectAllButton()
        updateBottomActionButtons()
    }
    
    @objc private func didTapShareButton() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else { return }
        
        let addToAlbumActivity = AddToAlbumActivity { [weak self] in
            self?.showAddToAlbumPicker(for: selectedAssets)
        }
        
        let activityItems: [Any] = [makeSharePlaceholderText(for: selectedAssets.count)]
        gridRouter.presentShareSheet(
            activityItems: activityItems,
            applicationActivities: [addToAlbumActivity],
            sourceView: shareButton,
            sourceRect: shareButton.bounds
        )
    }
    
    private func updateBottomActionButtons() {
        let inSelectionMode = selectionMode != .none
        let hasSelectedAssets = gridView.hasSelectedAssets
        let canUseHierarchyShortcuts = sortPreference == .custom && supportsHierarchyNumbering
        
        sortButton.isHidden = inSelectionMode
        hierarchyCollapseButton.isHidden = inSelectionMode || !canUseHierarchyShortcuts
        hierarchyExpandButton.isHidden = inSelectionMode || !canUseHierarchyShortcuts
        shareButton.isHidden = !inSelectionMode
        shareButton.isEnabled = hasSelectedAssets
    }

    private func makeBottomIconButton(systemImageName: String, accessibilityLabel: String, action: Selector) -> UIButton {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
            config.baseBackgroundColor = UIColor.systemGray5.withAlphaComponent(0.8)
        }
        config.image = UIImage(systemName: systemImageName)
        config.baseForegroundColor = UIColor.systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

        let button = UIButton(type: .custom)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = accessibilityLabel
        return button
    }

    @objc private func didTapHierarchyCollapseButton() {
        performHierarchyCollapseShortcut(shouldCollapse: true)
    }

    @objc private func didTapHierarchyExpandButton() {
        performHierarchyCollapseShortcut(shouldCollapse: false)
    }

    private func performHierarchyCollapseShortcut(shouldCollapse: Bool) {
        guard sortPreference == .custom, supportsHierarchyNumbering else { return }
        let isContinuingSameAction = hierarchyShortcutLastShouldCollapse == shouldCollapse
        let anchorAsset = isContinuingSameAction ? assetForHierarchyShortcutAnchor() : nil
        guard let centerAsset = anchorAsset ?? gridView.centerVisibleAsset else { return }
        guard let target = session.nearestCollapsibleAncestor(
            from: centerAsset,
            in: assets,
            shouldBecomeCollapsed: shouldCollapse
        ) else { return }

        session.toggleCollapse(target)
        hierarchyShortcutAnchorAssetID = target.localIdentifier
        hierarchyShortcutLastShouldCollapse = shouldCollapse
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    private func assetForHierarchyShortcutAnchor() -> PHAsset? {
        guard let id = hierarchyShortcutAnchorAssetID else { return nil }
        return assets.first { $0.localIdentifier == id }
    }

    private func resetHierarchyShortcutAnchor() {
        hierarchyShortcutAnchorAssetID = nil
        hierarchyShortcutLastShouldCollapse = nil
    }

    override func onChanged(sort preference: PhotoSortPreference) {
        resetHierarchyShortcutAnchor()
        super.onChanged(sort: preference)
    }

    @objc override internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging {
            resetHierarchyShortcutAnchor()
        }
        super.scrollViewDidScroll(scrollView)
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
