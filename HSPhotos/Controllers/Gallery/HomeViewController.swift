import UIKit
import Photos

class HomeViewController: GalleryViewController {

    /// 首页（图库）不支持层级编号，仅在相册内支持
    override var supportsHierarchyNumbering: Bool { false }

    override init() {
        // 使用所有照片的集合
        let allPhotosCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject!
        super.init(collection: allPhotosCollection)
        sortPreference = PhotoSortPreference.creationDate.preference(for: allPhotosCollection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "图库"
        navigationItem.setRightBarButtonItems([selectBarButton, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
    }

    override func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按拍摄日期排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .creationDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .creationDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }

        let modificationDateAction = UIAction(
            title: "按最近添加排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .recentDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .recentDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }

        return UIMenu(
            title: "排序方式",
            children: [modificationDateAction, creationDateAction]
        )
    }

    override func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
            navigationItem.leftBarButtonItem = nil
            tabBarController?.tabBar.isHidden = false
            additionalSafeAreaInsets.bottom = 0
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
            tabBarController?.tabBar.isHidden = true
            let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
            additionalSafeAreaInsets.bottom = -tabBarHeight
        }
        view.layoutIfNeeded()
        updateShareButtonState()
    }
    
    override func updateSelectAllButton() {
        
    }
}
