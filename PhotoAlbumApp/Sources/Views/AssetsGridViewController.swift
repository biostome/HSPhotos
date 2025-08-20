import UIKit
import Photos

final class AssetsGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching {
    private let collection: PHAssetCollection
    private var fetchResult: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>()
    private var collectionView: UICollectionView!
    private let caching = ImageCachingController()
    private var isAscending = false // standard sort: creationDate desc by default

    init(collection: PHAssetCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = collection.localizedTitle

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(AssetCell.self, forCellWithReuseIdentifier: AssetCell.reuseId)
        view.addSubview(collectionView)

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "排序", style: .plain, target: self, action: #selector(toggleSort)),
            UIBarButtonItem(title: "自定义排序", style: .plain, target: self, action: #selector(startCustomReorder))
        ]

        reloadFetch()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = view.bounds
    }

    private func reloadFetch() {
        fetchResult = PhotosDataSource.shared.fetchAssets(in: collection, sortByCreationDateAscending: isAscending)
        caching.reset()
        collectionView.reloadData()
    }

    @objc private func toggleSort() {
        isAscending.toggle()
        reloadFetch()
    }

    @objc private func startCustomReorder() {
        guard collection.assetCollectionSubtype == .albumRegular || collection.assetCollectionType == .album else {
            let alert = UIAlertController(title: "不可自定义排序", message: "仅用户创建的相册支持重排。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }

        collectionView.isEditing = true
        let done = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(finishCustomReorder))
        navigationItem.rightBarButtonItems?.append(done)
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }

    @objc private func finishCustomReorder() {
        collectionView.isEditing = false
        navigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems?.filter { $0.title != "完成" }
        // 顺序已在交互中写回系统相册
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { fetchResult.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AssetCell.reuseId, for: indexPath) as! AssetCell
        let asset = fetchResult.object(at: indexPath.item)
        let side = (collectionView.bounds.width - 3) / 4
        let scale = UIScreen.main.scale
        let target = CGSize(width: side * scale, height: side * scale)
        _ = caching.requestThumbnail(for: asset, targetSize: target) { image in
            cell.imageView.image = image
        }
        switch asset.mediaSubtypes.contains(.photoLive) {
        case true:
            cell.badgeLabel.isHidden = false
            cell.badgeLabel.text = "LIVE"
        default:
            if asset.mediaType == .video {
                cell.badgeLabel.isHidden = false
                cell.badgeLabel.text = self.format(duration: asset.duration)
            } else {
                cell.badgeLabel.isHidden = true
            }
        }
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let side = (collectionView.bounds.width - 3) / 4
        let scale = UIScreen.main.scale
        let target = CGSize(width: side * scale, height: side * scale)
        caching.updateCaching(in: collectionView, with: fetchResult, targetSize: target)
    }

    // MARK: - Prefetch
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // 可拓展：在这里显式 startCachingImages
    }

    // MARK: - Helpers
    private func format(duration: TimeInterval) -> String {
        let total = Int(duration)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

extension AssetsGridViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 4
        let spacing: CGFloat = 1
        let totalSpacing = (columns - 1) * spacing
        let side = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: side, height: side)
    }
}

// MARK: - Drag & Drop for custom sorting
extension AssetsGridViewController: UICollectionViewDragDelegate, UICollectionViewDropDelegate, UIDragInteractionDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let asset = fetchResult.object(at: indexPath.item)
        let itemProvider = NSItemProvider(object: asset.localIdentifier as NSString)
        return [UIDragItem(itemProvider: itemProvider)]
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destination = coordinator.destinationIndexPath else { return }
        let items = coordinator.items
        let sourceIndexes: [Int] = items.compactMap { item in
            guard let source = item.sourceIndexPath else { return nil }
            return source.item
        }
        guard !sourceIndexes.isEmpty else { return }

        // 更新系统相册顺序
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: self.collection) else { return }
            let indexSet = IndexSet(sourceIndexes)
            changeRequest.moveAssets(at: indexSet, to: destination.item)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.reloadFetch()
                } else {
                    let msg = error?.localizedDescription ?? "重排失败"
                    let alert = UIAlertController(title: "错误", message: msg, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool { true }
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {}
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {}
}

