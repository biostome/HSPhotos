import UIKit
import Photos

class HomeViewController: GalleryViewController {

    /// 首页（图库）不支持层级编号，仅在相册内支持
    override var supportsHierarchyNumbering: Bool { false }

    override init() {
        // 使用所有照片的集合
        let allPhotosCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject!
        super.init(collection: allPhotosCollection)
        sortPreference = PhotoSortPreference.homeCaptureDate.preference(for: allPhotosCollection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "图库"
        navigationItem.setRightBarButtonItems([selectBarButton, sortBarButton, menuBarButton], animated: true)
    }

    override func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按拍摄日期排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .homeCaptureDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .homeCaptureDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }

        let modificationDateAction = UIAction(
            title: "按最近添加排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .homeRecentAdded ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .homeRecentAdded)
            self?.sortBarButton.menu = self?.createSortMenu()
        }

        return UIMenu(
            title: "排序方式",
            children: [modificationDateAction, creationDateAction]
        )
    }

    override func sortDescriptors(for preference: PhotoSortPreference) -> [NSSortDescriptor]? {
        switch preference {
        case .homeRecentAdded:
            // 首页「最近添加」使用系统默认顺序，保持与系统图库一致。
            return nil
        default:
            return super.sortDescriptors(for: preference)
        }
    }

    override func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, sortBarButton, menuBarButton], animated: true)
            navigationItem.leftBarButtonItem = nil
            tabBarController?.tabBar.isHidden = false
            additionalSafeAreaInsets.bottom = 0
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton], animated: true)
            updateSelectAllButton()
            tabBarController?.tabBar.isHidden = true
            let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
            additionalSafeAreaInsets.bottom = -tabBarHeight
        }
        view.layoutIfNeeded()
        updateShareButtonState()
    }
    
    override func updateSelectAllButton() {
        let isAllSelected = isAllAssetsSelected()
        if isAllSelected {
            navigationItem.setLeftBarButtonItems([deselectAllBarButton], animated: true)
        } else {
            navigationItem.setLeftBarButtonItems([selectAllBarButton], animated: true)
        }
    }
}
