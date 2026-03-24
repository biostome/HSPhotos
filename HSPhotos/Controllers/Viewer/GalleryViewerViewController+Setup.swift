//
//  GalleryViewerViewController+Setup.swift
//  HSPhotos
//

import UIKit
import Photos

extension GalleryViewerViewController {
    func setupCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setupPageIndicator() {
        pageIndicator.textColor = .white
        pageIndicator.font = .systemFont(ofSize: 14, weight: .medium)
        pageIndicator.textAlignment = .center
        pageIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        pageIndicator.layer.cornerRadius = 12
        pageIndicator.clipsToBounds = true
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageIndicator)

        NSLayoutConstraint.activate([
            pageIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageIndicator.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 4),
            pageIndicator.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func setupThumbnailStrip() {
        thumbnailStripView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbnailStripView)

        NSLayoutConstraint.activate([
            thumbnailStripView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            thumbnailStripView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            thumbnailStripView.bottomAnchor.constraint(equalTo: bottomChromeContainer.topAnchor, constant: -GalleryViewerChromeMetrics.thumbnailStripAboveChromeGap),
            thumbnailStripView.heightAnchor.constraint(equalToConstant: GalleryViewerStripMetrics.stripHeight)
        ])

        thumbnailStripView.assets = assets
        thumbnailStripView.onSelect = { [weak self] idx in
            guard let self else { return }
            guard idx >= 0, idx < self.assets.count, idx != self.currentIndex else { return }
            self.navigateToIndexFromThumbnailStrip(idx, animated: true)
        }
        thumbnailStripView.onCenteredIndexChanged = { [weak self] idx in
            guard let self else { return }
            guard idx >= 0, idx < self.assets.count, idx != self.currentIndex else { return }
            self.navigateToIndexFromThumbnailStrip(idx, animated: false)
        }
        thumbnailStripView.syncSelection(currentIndex, animated: false)
    }

    private func navigateToIndexFromThumbnailStrip(_ targetIndex: Int, animated: Bool) {
        isPagingDrivenByThumbnailStrip = true
        currentIndex = targetIndex
        updateTitleAndFavorite()
        scrollToIndex(targetIndex, animated: animated)
        if !animated {
            DispatchQueue.main.async { [weak self] in
                self?.updateActivePageState()
                self?.finishThumbnailDrivenPagingIfNeeded()
            }
        }
    }

    func setupTopBar() {
        titleButton.titleLabel?.numberOfLines = 2
        titleButton.titleLabel?.textAlignment = .center
        titleButton.setTitleColor(.label, for: .normal)
        titleButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        titleButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        titleButton.translatesAutoresizingMaskIntoConstraints = false

        if navigationController != nil {
            topBar.isHidden = true
            titleButton.setTitleColor(.white, for: .normal)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            let navBar = navigationController?.navigationBar
            navBar?.standardAppearance = appearance
            navBar?.scrollEdgeAppearance = appearance
            navBar?.compactAppearance = appearance
            navBar?.compactScrollEdgeAppearance = appearance
            navBar?.isTranslucent = true
            navBar?.tintColor = .white

            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(closeTapped)
            )
            navigationItem.titleView = titleButton
            return
        }

        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        closeButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        closeButton.tintColor = .label
        closeButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        closeButton.layer.cornerRadius = 18
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(closeButton)
        topBar.addSubview(titleButton)

        closeButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 36).isActive = true

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.heightAnchor.constraint(equalToConstant: 44),
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 4),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleButton.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleButton.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8)
        ])
    }

    func setupBottomBar() {
        bottomChromeContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomChromeContainer.backgroundColor = .clear
        view.addSubview(bottomChromeContainer)

        configureLiquidGlassToolButton(shareButton, systemName: "square.and.arrow.up")
        configureCapsuleInnerIconButton(favoriteButton, systemName: "heart")
        configureCapsuleInnerIconButton(infoButton, systemName: "info.circle")
        configureCapsuleInnerIconButton(editButton, systemName: "slider.horizontal.3")
        configureLiquidGlassToolButton(deleteButton, systemName: "trash")

        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        [shareButton, favoriteButton, infoButton, editButton, deleteButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        centerCapsule.translatesAutoresizingMaskIntoConstraints = false

        let capsuleStack = UIStackView(arrangedSubviews: [favoriteButton, infoButton, editButton])
        capsuleStack.axis = .horizontal
        capsuleStack.spacing = GalleryViewerChromeMetrics.capsuleIconSpacing
        capsuleStack.distribution = .equalSpacing
        capsuleStack.alignment = .fill
        capsuleStack.translatesAutoresizingMaskIntoConstraints = false
        centerCapsule.contentView.addSubview(capsuleStack)

        let leftSpacer = UIView()
        let rightSpacer = UIView()
        leftSpacer.isUserInteractionEnabled = false
        rightSpacer.isUserInteractionEnabled = false
        leftSpacer.translatesAutoresizingMaskIntoConstraints = false
        rightSpacer.translatesAutoresizingMaskIntoConstraints = false

        bottomChromeContainer.addSubview(shareButton)
        bottomChromeContainer.addSubview(leftSpacer)
        bottomChromeContainer.addSubview(centerCapsule)
        bottomChromeContainer.addSubview(rightSpacer)
        bottomChromeContainer.addSubview(deleteButton)

        let metrics = GalleryViewerChromeMetrics.self
        NSLayoutConstraint.activate([
            bottomChromeContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: metrics.horizontalInset),
            bottomChromeContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -metrics.horizontalInset),
            bottomChromeContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -metrics.bottomInset),
            bottomChromeContainer.heightAnchor.constraint(equalToConstant: metrics.sideControlSide),

            shareButton.leadingAnchor.constraint(equalTo: bottomChromeContainer.leadingAnchor),
            shareButton.centerYAnchor.constraint(equalTo: bottomChromeContainer.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: metrics.sideControlSide),
            shareButton.heightAnchor.constraint(equalToConstant: metrics.sideControlSide),

            leftSpacer.leadingAnchor.constraint(equalTo: shareButton.trailingAnchor),
            leftSpacer.topAnchor.constraint(equalTo: bottomChromeContainer.topAnchor),
            leftSpacer.bottomAnchor.constraint(equalTo: bottomChromeContainer.bottomAnchor),

            centerCapsule.leadingAnchor.constraint(equalTo: leftSpacer.trailingAnchor),
            centerCapsule.centerYAnchor.constraint(equalTo: bottomChromeContainer.centerYAnchor),
            centerCapsule.heightAnchor.constraint(equalToConstant: metrics.sideControlSide),

            rightSpacer.leadingAnchor.constraint(equalTo: centerCapsule.trailingAnchor),
            rightSpacer.topAnchor.constraint(equalTo: bottomChromeContainer.topAnchor),
            rightSpacer.bottomAnchor.constraint(equalTo: bottomChromeContainer.bottomAnchor),

            deleteButton.leadingAnchor.constraint(equalTo: rightSpacer.trailingAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: bottomChromeContainer.trailingAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: bottomChromeContainer.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: metrics.sideControlSide),
            deleteButton.heightAnchor.constraint(equalToConstant: metrics.sideControlSide),

            leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor),

            capsuleStack.leadingAnchor.constraint(equalTo: centerCapsule.contentView.leadingAnchor, constant: metrics.capsulePaddingH),
            capsuleStack.trailingAnchor.constraint(equalTo: centerCapsule.contentView.trailingAnchor, constant: -metrics.capsulePaddingH),
            capsuleStack.topAnchor.constraint(equalTo: centerCapsule.contentView.topAnchor),
            capsuleStack.bottomAnchor.constraint(equalTo: centerCapsule.contentView.bottomAnchor)
        ])
    }

    func configureLiquidGlassToolButton(_ button: UIButton, systemName: String) {
        let metrics = GalleryViewerChromeMetrics.self
        var config = UIButton.Configuration.glass()
        let symbol = UIImage.SymbolConfiguration(pointSize: metrics.sideGlassIconPointSize, weight: .medium)
        config.image = UIImage(systemName: systemName, withConfiguration: symbol)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        let inset = (metrics.sideControlSide - metrics.sideGlassIconPointSize) / 2
        config.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        button.configuration = config
    }

    func configureCapsuleInnerIconButton(_ button: UIButton, systemName: String) {
        let metrics = GalleryViewerChromeMetrics.self
        var config = UIButton.Configuration.borderless()
        let symbol = UIImage.SymbolConfiguration(pointSize: metrics.capsuleInnerIconPointSize, weight: metrics.capsuleIconWeight)
        config.image = UIImage(systemName: systemName, withConfiguration: symbol)
        config.baseForegroundColor = .white
        button.configuration = config
    }
}

extension GalleryViewerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let asset = assets[indexPath.item]
        guard let cellType = mediaCellTypes.first(where: { $0.supports(asset) }) else {
            fatalError("Unsupported asset media type: \(asset.mediaType.rawValue)")
        }
        let cell = cellType.dequeue(from: collectionView, for: indexPath)
        cell.preferredPlaceholderImage = indexPath.item == initialPlaceholderIndex ? initialPlaceholderImage : nil
        cell.configure(with: asset, at: indexPath.item)
        cell.onSingleTap = { [weak self] in
            self?.toggleChrome()
        }
        cell.isPageActive = indexPath.item == currentIndex
        cell.setInlineControlsVisible(!isChromeHidden, animated: false)
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        syncCurrentIndexWithVisiblePage()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        syncCurrentIndexWithVisiblePage()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        updateVisiblePageActivationDuringScroll()
    }

    private func updateVisiblePageActivationDuringScroll() {
        let targetIndex = centeredIndex()
        for case let cell as PhotoCellBase in collectionView.visibleCells {
            if let indexPath = collectionView.indexPath(for: cell) {
                cell.isPageActive = indexPath.item == targetIndex
            }
        }
    }

    private func syncCurrentIndexWithVisiblePage() {
        let index = centeredIndex()
        guard index >= 0, index < assets.count else {
            finishThumbnailDrivenPagingIfNeeded()
            return
        }
        currentIndex = index
        updateTitleAndFavorite()
        updateActivePageState()
        if isPagingDrivenByThumbnailStrip {
            finishThumbnailDrivenPagingIfNeeded()
        } else {
            thumbnailStripView.syncSelection(currentIndex, animated: true)
        }
    }

    private func centeredIndex() -> Int {
        guard collectionView.bounds.width > 0 else { return currentIndex }
        let rawIndex = Int(round(collectionView.contentOffset.x / collectionView.bounds.width))
        return min(max(0, rawIndex), max(0, assets.count - 1))
    }
}
