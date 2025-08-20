## 相册（UIKit + Photos）

**目标**: 仿苹果相册的基础 UI 与交互，先实现相册列表与相册内资源网格浏览；提供高性能图片加载；支持排序（标准：创建时间，自定义：用户拖拽顺序并在原生相册生效）。

### 环境要求
- Xcode 15+，iOS 15+（最低 iOS 14 也可，需小改动）
- Swift 5.9+
- UIKit，Photos.framework

### 快速开始（将本仓库文件加入你的 Xcode 工程）
1. 在 Xcode 中新建 iOS App（Storyboard/SwiftUI 均可；本示例使用 UIKit 代码式 UI）。
2. 将 `Sources` 目录下所有 `.swift` 文件拖入工程（勾选 “Copy items if needed”）。
3. 在 `Info.plist` 加入隐私权限：
   - `NSPhotoLibraryUsageDescription` = 访问相册用于展示与管理照片
   - `NSPhotoLibraryAddUsageDescription` = 写入自定义排序到用户相册
4. 在 `Signing & Capabilities` 中确保勾选 `Photos` 权限（只读/读写）。
5. 运行到真机（建议）或模拟器。

### 目前完成的功能
- 相册列表（尽量贴近苹果相册样式）：
  - 展示系统“智能相册”和“用户相册”（按 Apple Photos 的分组习惯，去重及隐藏空相册）
  - 每个相册显示封面与资源数量
- 相册资源网格：
  - 展示所有资源：照片、视频、Live Photo（缩略图显示；视频显示时长，Live 显示标识）
  - 高性能加载：PHCachingImageManager 预热 + 滚动时缓存窗口更新 + 预取
  - 排序：
    - 标准排序：按 `creationDate`（新到旧/旧到新，可扩展）
    - 自定义排序（仅限“用户相册”）：支持拖拽改序，持久化到系统相册（Photos 可见）

### 关键技术与实现原理
- 资源访问：`Photos` 框架
  - 相册：`PHAssetCollection.fetchAssetCollections(...)`
  - 资源：`PHAsset.fetchAssets(in:options:)` 或 `PHAsset.fetchAssets(with:)`
- 授权：`PHPhotoLibrary.requestAuthorization(for: .readWrite)`，读写权限用于提交排序到相册
- 高性能缩略图：
  - 使用 `PHCachingImageManager` 请求固定目标尺寸（等比裁切，缩略图）
  - 维护“预热区域”（preheat rect），根据滚动方向批量 `startCachingImages` / `stopCachingImages`
  - `UICollectionViewDataSourcePrefetching` 预取 indexPaths 的缩略图
- 排序：
  - 标准：通过 `PHFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ...)]`
  - 自定义：仅用户相册可修改顺序（系统智能相册不允许更改顺序）。使用 `PHPhotoLibrary.shared().performChanges` 与 `PHAssetCollectionChangeRequest` 的 `moveAssets(at:to:)` 或 `insertAssets(_:at:)` 将用户拖拽后的顺序写回。该变更会在原生“照片”App 中生效。

> 限制说明：Apple 不允许修改智能相册（如“所有照片/最近项目/人物”等）的内部排序；自定义排序仅对“用户创建的相册”有效。

### 目录结构
```
PhotoAlbumApp/
  README.md
  Sources/
    AppDelegate.swift
    SceneDelegate.swift
    Managers/
      PhotosDataSource.swift
      ImageCachingController.swift
    Views/
      AlbumListViewController.swift
      AssetsGridViewController.swift
      AlbumCell.swift
      AssetCell.swift
    Utilities/
      Extensions.swift
```

### 设计要点
- UIKit 纯代码布局，尽量还原苹果相册：
  - 相册列表：方形封面 + 标题 + 数量，网格布局
  - 资源网格：四列（iPhone 竖屏），动态间距
- 解耦：
  - `PhotosDataSource` 负责相册/资源的抓取与变更监听
  - `ImageCachingController` 负责缩略图请求与缓存
  - VC 专注 UI 和交互

### 后续可拓展
- 搜索与筛选（媒体类型、人脸、地点）
- 动图/实况动态播放
- iCloud 同步状态/下载进度展示
- 编辑入口（滤镜/标注/裁剪）

### 常见问题
- 模拟器无照片：在模拟器“照片”App 导入媒体，或用真机调试
- 自定义排序按钮不可用：该相册可能是智能相册，或没有写入权限

