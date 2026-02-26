//
//  AppAppearance.swift
//  HSPhotos
//
//  Created by Qwen on 2026/2/25.
//

import UIKit

/// 应用全局外观配置
class AppAppearance {
    static let shared = AppAppearance()
    
    private init() {}
    
    /// 配置应用全局外观
    func configure() {
        configureNavigationBar()
    }
    
    /// 配置导航栏外观，包括穿透效果
    private func configureNavigationBar() {
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithTransparentBackground()
        navigationBarAppearance.backgroundColor = UIColor.clear
        navigationBarAppearance.shadowColor = UIColor.clear
        navigationBarAppearance.backgroundImage = UIImage()
        
        // 配置大标题样式
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        
        // 配置普通标题样式
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        
        // 应用配置到所有导航栏
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarAppearance
        
        // 设置导航栏半透明
        UINavigationBar.appearance().isTranslucent = true
    }
}
