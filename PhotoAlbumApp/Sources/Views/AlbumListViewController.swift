import UIKit
import Photos

final class AlbumListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private var collectionView: UICollectionView!
    private var albums: [AlbumItem] = []
    private let dataSource = PhotosDataSource.shared
    private let imageManager = PHCachingImageManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "相册"

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 18
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(AlbumCell.self, forCellWithReuseIdentifier: AlbumCell.reuseId)
        view.addSubview(collectionView)

        dataSource.onLibraryChange { [weak self] in self?.reloadAlbums() }

        dataSource.requestAuthorizationIfNeeded { [weak self] status in
            guard let self = self else { return }
            if status == .authorized || status == .limited {
                self.reloadAlbums()
            } else {
                self.presentDeniedAlert()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = view.bounds.inset(by: view.safeAreaInsets)
    }

    private func presentDeniedAlert() {
        let alert = UIAlertController(title: "需要相册权限", message: "请在设置中开启照片访问权限", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func reloadAlbums() {
        albums = dataSource.fetchAllAlbums()
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { albums.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AlbumCell.reuseId, for: indexPath) as! AlbumCell
        let item = albums[indexPath.item]
        cell.titleLabel.text = item.title
        cell.countLabel.text = "\(item.estimatedCount)"

        if let keyAsset = item.keyAsset {
            let scale = UIScreen.main.scale
            let side = (view.bounds.width - 3 * 2) / 2 // 2列近似
            let target = CGSize(width: side * scale, height: side * scale)
            imageManager.requestImage(for: keyAsset, targetSize: target, contentMode: .aspectFill, options: nil) { image, _ in
                cell.imageView.image = image
            }
        } else {
            cell.imageView.image = nil
        }
        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = albums[indexPath.item]
        let vc = AssetsGridViewController(collection: item.collection)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension AlbumListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 2
        let spacing: CGFloat = 2
        let totalSpacing = (columns - 1) * spacing
        let width = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: width, height: width + 44)
    }
}

