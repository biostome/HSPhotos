//
//  PhotoGridView+ContextMenu.swift
//  HSPhotos
//

import UIKit
import Photos

// MARK: - UICollectionView Context Menu
extension PhotoGridView {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < visibleAssets.count, let session = albumSession else { return nil }
        let asset = visibleAssets[indexPath.item]
        let isCurrentAnchor = anchorPhoto?.localIdentifier == asset.localIdentifier
        let isCurrentHierarchyCollapsed = session.isCollapsed(asset)
        let hasHierarchyDescendants = session.hasDescendants(asset, in: assets)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [self] _ in
            var anchorGroup: [UIMenuElement] = []
            var hierarchyGroup: [UIMenuElement] = []
            var tailGroup: [UIMenuElement] = []

            if isCurrentAnchor {
                let removeAnchorAction = UIAction(title: "取消锚点", image: UIImage(systemName: "anchor.slash")) { [weak self] _ in
                    self?.anchorPhoto = nil
                    self?.collectionView.reloadData()
                }
                anchorGroup.append(removeAnchorAction)
            } else {
                let setAnchorAction = UIAction(title: "设为锚点", image: UIImage(systemName: "anchor")) { [weak self] _ in
                    self?.anchorPhoto = asset
                    self?.collectionView.reloadData()
                    self?.delegate?.photoGridView(self!, didSetAnchor: asset)
                }
                anchorGroup.append(setAnchorAction)
            }

            if sortPreference == .custom, supportsHierarchyNumbering {
                let currLv = session.level(for: asset)
                let prevLv = session.previousNumberedLevel(before: asset, in: visibleAssets)

                if currLv == 0 {
                    let setMain = UIAction(title: "设为主级", image: UIImage(systemName: "list.number")) { [weak self] _ in
                        guard let self else { return }
                        session.setLevel(1, for: asset)
                        self.refreshParagraphDisplay()
                    }
                    hierarchyGroup.append(setMain)

                    if prevLv > 0 {
                        let setSame = UIAction(title: "设为同级", image: UIImage(systemName: "arrow.right.to.line")) { [weak self] _ in
                            guard let self else { return }
                            session.setLevel(prevLv, for: asset)
                            self.refreshParagraphDisplay()
                        }
                        let setSub = UIAction(title: "设为子级", image: UIImage(systemName: "list.bullet.indent")) { [weak self] _ in
                            guard let self else { return }
                            session.setLevel(prevLv + 1, for: asset)
                            self.refreshParagraphDisplay()
                        }
                        hierarchyGroup.append(setSame)
                        hierarchyGroup.append(setSub)
                    }
                } else {
                    if currLv > 1 {
                        let promote = UIAction(title: "提升层级", image: UIImage(systemName: "arrow.left")) { [weak self] _ in
                            guard let self else { return }
                            session.setLevel(currLv - 1, for: asset)
                            self.refreshParagraphDisplay()
                        }
                        hierarchyGroup.append(promote)
                    }

                    if currLv < prevLv + 1 {
                        let demote = UIAction(title: "下降层级", image: UIImage(systemName: "arrow.right")) { [weak self] _ in
                            guard let self else { return }
                            session.setLevel(currLv + 1, for: asset)
                            self.refreshParagraphDisplay()
                        }
                        hierarchyGroup.append(demote)
                    }

                    if currLv != prevLv && prevLv > 0 {
                        let setSame = UIAction(title: "设为同级", image: UIImage(systemName: "arrow.right.to.line")) { [weak self] _ in
                            guard let self else { return }
                            session.setLevel(prevLv, for: asset)
                            self.refreshParagraphDisplay()
                        }
                        hierarchyGroup.append(setSame)
                    }

                    let clearAction = UIAction(title: "取消编号", image: UIImage(systemName: "xmark.circle"), attributes: .destructive) { [weak self] _ in
                        guard let self else { return }
                        session.clearLevelCascading(anchor: asset, visibleSuccessors: self.visibleAssets)
                        self.refreshParagraphDisplay()
                    }
                    hierarchyGroup.append(clearAction)
                }

                if hasHierarchyDescendants || isCurrentHierarchyCollapsed {
                    let collapseAction = UIAction(
                        title: isCurrentHierarchyCollapsed ? "展开" : "折叠",
                        image: UIImage(systemName: isCurrentHierarchyCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    ) { [weak self] _ in
                        guard let self else { return }
                        session.toggleCollapse(asset)
                        self.refreshParagraphDisplay()
                    }
                    hierarchyGroup.append(collapseAction)
                }
            }

            let tagAction = UIAction(title: "添加标签", image: UIImage(systemName: "tag")) { [weak self] _ in
                guard let self else { return }
                self.delegate?.photoGridView(self, didRequestAddTagFor: asset)
            }
            tailGroup.append(tagAction)

            let pasteAction = UIAction(title: "粘贴到此后方", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
                if let pasteAssets = AssetPasteboard.assetsFromPasteboard(), !pasteAssets.isEmpty {
                    self?.handlePasteToAfter(asset: asset, assets: pasteAssets)
                }
            }
            tailGroup.append(pasteAction)

            let deleteAction = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                guard let self else { return }
                self.delegate?.photoGridView(self, didRequestDelete: asset)
            }
            tailGroup.append(deleteAction)

            var rootChildren: [UIMenuElement] = []
            if !anchorGroup.isEmpty {
                rootChildren.append(UIMenu(title: "锚点", image: UIImage(systemName: "anchor"), options: .displayInline, children: anchorGroup))
            }
            if !hierarchyGroup.isEmpty {
                rootChildren.append(UIMenu(title: "层级", options: .displayInline, children: hierarchyGroup))
            }
            if !tailGroup.isEmpty {
                rootChildren.append(UIMenu(title: "其他", options: .displayInline, children: tailGroup))
            }
            return UIMenu(title: "", children: rootChildren)
        }
    }

    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: identifier) else { return nil }

        return UITargetedPreview(view: cell)
    }
}
