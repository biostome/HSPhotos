//
//  BasePhotoViewController+Selection.swift
//  HSPhotos
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController {
        internal func setSelectionMode(_ mode: PhotoSelectionMode) {
            if mode == .none {
                gridView.clearSelected()
                gridView.selectedStart = nil
                gridView.selectedEnd = nil
            }
            selectionMode = mode
        }

        /// 切换选择模式：点击进入多选模式，再次点击退出选择模式
        @objc internal func toggleSelectionMode() {
            if selectionMode == .none {
                // 进入多选模式
                setSelectionMode(.multiple)
                // 关闭全屏侧滑返回
                navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            } else {
                // 退出选择模式
                setSelectionMode(.none)
                // 同时关闭范围选择
                toggleRangeSelection(forceOff: true)
                // 开启全屏侧滑返回
                navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            }
            updateNavigationBar()
        }

        /// 切换范围选择开关
        @objc internal func toggleRangeSelection(forceOff: Bool = false) {
            let isCurrentlyOn = rangeSwitchItem.tag == 1
            let shouldTurnOn = !isCurrentlyOn && !forceOff

            if shouldTurnOn {
                // 打开范围选择
                rangeSwitchItem.image = UIImage(systemName: "checkmark.seal.fill")
                rangeSwitchItem.tag = 1
                setSelectionMode(.range)
            } else {
                // 关闭范围选择
                rangeSwitchItem.image = UIImage(systemName: "checkmark.seal")
                rangeSwitchItem.tag = 0
                if selectionMode == .range {
                    setSelectionMode(.multiple)
                }
            }
        }

        /// 全选所有资产
        @objc internal func selectAllAssets() {
            gridView.selectAll()
            // 更新按钮状态
            updateSelectAllButton()
        }

        /// 取消全选所有资产
        @objc internal func deselectAllAssets() {
            gridView.clearSelected()
            // 更新按钮状态
            updateSelectAllButton()
        }

        /// 选择模式下在导航控制器底部工具条显示「上一处 / 下一处」。
        internal func updateSelectionQuickNavToolbar() {
            guard let nav = navigationController else { return }
            if selectionMode == .none {
                nav.setToolbarHidden(true, animated: true)
                toolbarItems = nil
                return
            }
            let flexLeading = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let flexTrailing = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbarItems = [flexLeading, selectionQuickNavPreviousBarButton, selectionQuickNavNextBarButton, flexTrailing]
            nav.setToolbarHidden(false, animated: true)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            updateSelectionQuickNavToolbar()
        }

        /// 检查是否所有可见资产都已被选中
        internal func isAllAssetsSelected() -> Bool {
            gridView.selectedAssetCount == gridView.allAssets.count && !gridView.allAssets.isEmpty
        }

}
