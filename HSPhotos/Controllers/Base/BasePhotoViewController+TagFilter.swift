//
//  BasePhotoViewController+TagFilter.swift
//  HSPhotos
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController: TagFilterPanelDelegate {
    func tagFilterPanel(_ panel: TagFilterPanelViewController, didApply state: TagFilterState) {
        filterState = state
    }
}

extension BasePhotoViewController {
        // MARK: - Search Methods

        internal func performSearch(with text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            if let index = Int(trimmed), index > 0 {
                // 数字：跳转到第 N 张照片
                gridView.scrollTo(index: index - 1)
                return
            }

            if trimmed.isEmpty {
                // 清空搜索：移除标签过滤
                filterState = TagFilterState()
                return
            }

            // 文本：按标签名匹配并过滤
            let matchedTagIDs = PhotoTagOperations.shared.tagIDs(matchingName: trimmed)
            filterState = TagFilterState(selectedTagIDs: matchedTagIDs, matchRule: .any)
        }

        // MARK: - 网格刷新

        internal func refreshGridFromSession() {
            gridView.reloadFromSession()
            updateTagFilterButtonAppearance()
            syncSearchBarVisibility()
        }

        /// 弹出标签筛选面板
        @objc internal func didTapTagFilter() {
            let panel = TagFilterPanelViewController(currentState: filterState)
            panel.candidateIdentifiers = assets.map { $0.localIdentifier }
            panel.delegate = self
            gridRouter.presentTagFilterPanel(panel)
        }

        /// 将 filterState 中的标签同步为搜索框 Token
        internal func syncSearchTokens() {
            let tags = PhotoTagOperations.shared.loadTags()
            let activeTags = tags.filter { filterState.selectedTagIDs.contains($0.id) }
            searchTextField.setFilterTokens(from: activeTags)
            searchTextField.markTokensSynced()
        }

        /// 有激活过滤时搜索栏始终可见
        private func syncSearchBarVisibility() {
            if filterState.isActive {
                searchTextField.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.searchTextField.transform = .identity
                    self.searchTextField.alpha = 1.0
                }
                isSearchBarVisible = true
            }
        }

        /// 标签过滤状态变化后刷新操作菜单
        private func updateTagFilterButtonAppearance() {
            searchTextField.isFilterActive = filterState.isActive
            updateOperationMenu()
        }

}
