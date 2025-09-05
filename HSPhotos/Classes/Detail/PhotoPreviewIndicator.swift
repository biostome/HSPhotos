//
//  PhotoPreviewIndicator.swift
//  HSPhotos
//
//  Created by Hans on 2025/1/9.
//

import UIKit
import Photos

// MARK: - PhotoPreviewIndicatorDelegate

protocol PhotoPreviewIndicatorDelegate: AnyObject {
    func photoPreviewIndicator(_ indicator: PhotoPreviewIndicator, didSelectPhotoAt index: Int)
    func photoPreviewIndicator(_ indicator: PhotoPreviewIndicator, didScrollTo offset: CGFloat, contentHeight: CGFloat, visibleHeight: CGFloat)
}

// MARK: - PhotoPreviewIndicator

class PhotoPreviewIndicator: UIView {
    
    // MARK: - Properties
    
    weak var delegate: PhotoPreviewIndicatorDelegate?
    
    private var assets: [PHAsset] = []
    private var thumbnailToAssetIndexMap: [Int: Int] = [:]
    private var sortPreference: PhotoSortPreference = .custom
    private var isUserScrolling = false // 跟踪用户是否正在滚动指示器
    
    // MARK: - UI Components
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.clipsToBounds = true
        collectionView.layer.cornerRadius = 10
        collectionView.isScrollEnabled = true // 启用滚动
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        
        return collectionView
    }()
    
    // MARK: - Layout Constants
    private let barHeight: CGFloat = 300
    
    // MARK: - Constraints
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        configureAppearance()
        setupCollectionView()
        setupConstraints()
        setupGestures()
    }
    
    private func configureAppearance() {
        backgroundColor = UIColor.white.withAlphaComponent(0.6)
        layer.cornerRadius = 10
        
        // 增强阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 16
        layer.shadowOpacity = 0.25
        layer.masksToBounds = false
        clipsToBounds = false
    }
    
    private func setupCollectionView() {
        addSubview(collectionView)
    }
    
    private func setupConstraints() {
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.cancelsTouchesInView = false
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Public Methods
    
    func configure(with assets: [PHAsset], sortPreference: PhotoSortPreference) {
        self.sortPreference = sortPreference
        self.assets = assets // 显示所有图片
        createIndexMapping(from: assets)
        
        print("PhotoPreviewIndicator: Configuring with \(self.assets.count) thumbnails")
        self.collectionView.reloadData()
        print("PhotoPreviewIndicator: Setup complete, frame: \(frame)")
    }
    
    func updateScrollPosition(basedOn mainScrollOffset: CGFloat, mainContentHeight: CGFloat, mainVisibleHeight: CGFloat) {
        guard !assets.isEmpty else { return }
        
        // 如果用户正在滚动指示器，不进行同步
        guard !isUserScrolling else { return }
        
        // 计算主相册的滚动进度 (0.0 到 1.0)
        let mainScrollableHeight = mainContentHeight - mainVisibleHeight
        guard mainScrollableHeight > 0 else { return }
        
        let mainProgress = min(max(mainScrollOffset / mainScrollableHeight, 0), 1)
        
        // 计算指示器的可滚动高度
        let indicatorContentHeight = self.collectionView.contentSize.height
        let indicatorVisibleHeight = self.collectionView.bounds.height
        let indicatorScrollableHeight = indicatorContentHeight - indicatorVisibleHeight
        
        guard indicatorScrollableHeight > 0 else { return }
        
        // 根据主相册的滚动进度计算指示器应该滚动到的位置
        let targetOffset = mainProgress * indicatorScrollableHeight
        
        // 更新指示器的滚动位置
        self.collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
    }
    
    // MARK: - Private Methods
    
    
    private func createIndexMapping(from originalAssets: [PHAsset]) {
        // 显示所有图片，创建1:1映射
        thumbnailToAssetIndexMap = Dictionary(uniqueKeysWithValues: originalAssets.indices.map { ($0, $0) })
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            expandIndicator()
        case .ended, .cancelled:
            collapseIndicator()
        default:
            break
        }
    }
    
    private func expandIndicator() {
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }, completion: { _ in
//            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    private func collapseIndicator() {
        // 使用苹果风格的弹性动画，收缩时稍微快一些
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.3, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.transform = .identity
        }, completion: { _ in
//            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
}

// MARK: - UICollectionViewDataSource

extension PhotoPreviewIndicator: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThumbnailCell", for: indexPath) as! ThumbnailCell
        let asset = assets[indexPath.item]
        cell.configure(with: asset, index: indexPath.item, sortPreference: sortPreference)
        cell.delegate = self
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PhotoPreviewIndicator: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = collectionView.bounds.width
        // 设置合适的最小cell高度，让collectionView可以滚动显示所有图片
        let minCellHeight: CGFloat = 20
        let totalHeight = barHeight
        let calculatedHeight = totalHeight / CGFloat(assets.count)
        let cellHeight = max(calculatedHeight, minCellHeight)
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoPreviewIndicator: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户开始滚动指示器
        isUserScrolling = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 用户正在滚动指示器，通知代理进行反向同步
        guard isUserScrolling else { return }
        
        let indicatorContentHeight = scrollView.contentSize.height
        let indicatorVisibleHeight = scrollView.bounds.height
        
        delegate?.photoPreviewIndicator(
            self,
            didScrollTo: scrollView.contentOffset.y,
            contentHeight: indicatorContentHeight,
            visibleHeight: indicatorVisibleHeight
        )
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // 滚动结束，恢复同步
            isUserScrolling = false
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 滚动结束，恢复同步
        isUserScrolling = false
    }
}

// MARK: - ThumbnailCellDelegate

extension PhotoPreviewIndicator: ThumbnailCellDelegate {
    func thumbnailCell(_ cell: ThumbnailCell, didSelectAt index: Int) {
        let originalIndex = thumbnailToAssetIndexMap[index] ?? index
        delegate?.photoPreviewIndicator(self, didSelectPhotoAt: originalIndex)
    }
}

// MARK: - ThumbnailCellDelegate Protocol

protocol ThumbnailCellDelegate: AnyObject {
    func thumbnailCell(_ cell: ThumbnailCell, didSelectAt index: Int)
}

// MARK: - ThumbnailCell

class ThumbnailCell: UICollectionViewCell {
    
    // MARK: - Properties
    
    weak var delegate: ThumbnailCellDelegate?
    
    private var index: Int = 0
    private var asset: PHAsset?
    private var sortPreference: PhotoSortPreference = .custom
    
    // MARK: - UI Components
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.addSubview(imageView)
        setupConstraints()
        setupGestures()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 图片完全填充cell，无边距
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Public Methods
    
    func configure(with asset: PHAsset, index: Int, sortPreference: PhotoSortPreference) {
        self.asset = asset
        self.index = index
        self.sortPreference = sortPreference
        
        loadImage()
        updateText()
    }
    
    // MARK: - Private Methods
    
    private func loadImage() {
        guard let asset = asset else { return }
        
        // 使用固定的目标尺寸，不变化
        let targetSize = CGSize(width: 40 * UIScreen.main.scale, height: 40 * UIScreen.main.scale)
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }
    
    private func updateText() {
        switch sortPreference {
        case .creationDate, .modificationDate, .recentDate:
            if let asset = asset {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                textLabel.text = formatter.string(from: asset.creationDate ?? Date())
            }
        case .custom:
            textLabel.text = "第\(index + 1)张"
        }
    }
    
    @objc private func handleTap() {
        delegate?.thumbnailCell(self, didSelectAt: index)
    }
}
