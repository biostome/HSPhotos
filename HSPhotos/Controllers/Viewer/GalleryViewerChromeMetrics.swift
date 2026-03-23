//
//  GalleryViewerChromeMetrics.swift
//  HSPhotos
//

import UIKit

/// 大图浏览器底部控制栏尺寸与图标参数（贴 safeArea，无单独系统控件）
enum GalleryViewerChromeMetrics {
    static let horizontalInset: CGFloat = 20
    /// 与 safeArea 底边的间距（safeArea 已不含 Home 指示条区域）
    static let bottomInset: CGFloat = 18
    /// 缩略图条下缘与底栏（Liquid Glass）上缘的间距
    static let thumbnailStripAboveChromeGap: CGFloat = 40
    /// 两侧 Liquid Glass 外框边长
    static let sideControlSide: CGFloat = 48
    static let sideGlassIconPointSize: CGFloat = 17
    static let capsuleInnerIconPointSize: CGFloat = 18
    static let capsuleIconWeight: UIImage.SymbolWeight = .medium
    static let capsuleIconSpacing: CGFloat = 19
    static let capsulePaddingH: CGFloat = 11
}
