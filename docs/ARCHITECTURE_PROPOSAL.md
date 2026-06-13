# HSPhotos 架构改进方案

> 综合三个分析代理（算法复杂度、内存/缓存、UI 渲染/磁盘 I/O）的扫描结果，
> 基于当前架构文档（`ARCHITECTURE.md`）和性能问题报告（`PERFORMANCE_ISSUES.md`），
> 提出系统性架构改进方案。
>
> 日期：2026-06-13

---

## 一、当前架构问题深度分析

### 1.1 上帝类：BasePhotoViewController (~1890 行)

`BasePhotoViewController` 承载了 **15+ 项职责**，严重违反单一职责原则（SRP）：

| 职责类别 | 具体内容 | 行数估算 |
|---------|---------|---------|
| UI 搭建 | setupToolbar、setupGridView、setupNavigationBar、setupSearchBar | ~150 |
| 导航栏管理 | selectBarButton、cancelSelectBarButton、selectAllBarButton 等 10+ barButtonItem | ~100 |
| 选择模式 | toggleSelectionMode、toggleRangeSelection、selectAll、deselectAll | ~120 |
| 排序 | createSortMenu、onChanged(sort:)、onOrder | ~150 |
| 照片变更 | 删除、移动、拷贝、粘贴、复制 — 全部在此协调 | ~200 |
| 撤销/重做 | undoAction、redoAction、与 UndoManagerService 交互 | ~60 |
| 搜索/标签筛选 | searchTextField delegate、tagFilterBarButton、applyTagFilter | ~80 |
| 批量层级操作 | onBatchSetLevel、promote/demote/clear、级联算法 | ~200 |
| 快速跳转 | syncQuickJumpBarButtonsEnabled、next/prev jump handler | ~80 |
| 层级工具栏 | syncHierarchyToolbarButtonsEnabled、折叠/展开/隐藏无级 | ~120 |
| PHPicker 集成 | 照片选择器 present/dismiss/delegate | ~80 |
| UIMenu 构建 | createOperationMenu、createSortMenu、createHierarchyMenuChildren、createHierarchyToolbarMenu、createQuickJumpModeMenu — **5 个独立菜单** | ~300 |
| 滚动动画 | scrollTo、选中照片滚动定位 | ~40 |
| 5 个 Delegate 协议 | PhotoGridViewDelegate、SearchBarViewDelegate、TagFilterPanelDelegate、PHPickerViewControllerDelegate、CustomVerticalScrollIndicatorDelegate | — |
| 级联层级算法 | 可见性计算、下一张/上一张层级查找 | ~100 |

```
BasePhotoViewController (~1890 行)
├── [1]  UI 搭建          ── setupToolbar / setupGridView / setupSearchBar
├── [2]  导航栏管理       ── 10+ barButtonItem (选择/全选/取消/返回/菜单/标签/撤销/重做/快跳)
├── [3]  选择模式         ── toggleSelectionMode / toggleRangeSelection / selectAll / deselectAll
├── [4]  排序             ── createSortMenu / onChanged(sort:) / onOrder
├── [5]  照片变更         ── delete / move / copy / paste / duplicate
├── [6]  撤销/重做        ── undoAction / redoAction
├── [7]  搜索/标签筛选    ── searchTextField / tagFilter / applyTagFilter
├── [8]  批量层级操作     ── onBatchSetLevel / promote / demote / clear / 级联
├── [9]  快速跳转         ── syncQuickJumpBarButtonsEnabled / jump handler
├── [10] 层级工具栏       ── syncHierarchyToolbarButtonsEnabled / 折叠/展开
├── [11] PHPicker         ── present / dismiss / delegate
├── [12] UIMenu 构建      ── createOperationMenu / createSortMenu / createHierarchyMenuChildren
├── [13] 滚动动画         ── scrollTo / 选中定位
├── [14] 5 个 Delegate    ── PhotoGridViewDelegate / SearchBarViewDelegate / ...
└── [15] 级联层级算法     ── 可见性计算 / 层级查找
```

### 1.2 肥胖视图：PhotoGridView (~2663 行)

`PhotoGridView` 负担过重，承载了 **10+ 项职责**：

| 职责类别 | 具体内容 | 行数估算 |
|---------|---------|---------|
| UICollectionView DataSource | cellForItemAt (82行)、numberOfItemsInSection、cell 配置 | ~300 |
| UICollectionView Delegate | didSelectItemAt、willDisplay、didEndDisplaying | ~150 |
| UICollectionView Layout | 列数计算、间距、捏合缩放、sectionInset | ~200 |
| Prefetching | UICollectionViewDataSourcePrefetching | ~60 |
| 手势处理 | 长按、滑动选择(.began/.changed/.ended)、双击选择 | ~200 |
| 选择状态 | selectedAssetIDs、toggle、选中集通知、全选懒标记 | ~250 |
| 层级缓存/计算 | prewarmHierarchyCache、computeVisibleAssets、visibleAssetsBatchChanges | ~400 |
| 快跳引擎 | quickJumpTargetIndices、QuickJumpIndices 结构体 | ~500 |
| 可见性/层级快捷 | applyVisibleAssetsChangeAnimated、visibleAssetIDsOnScreen | ~300 |
| 上下文菜单 | UIContextMenuConfiguration、UIAction 构建 | ~150 |
| 滚动代理 | CustomVerticalScrollIndicatorDelegate | ~50 |
| 工具栏同步 | 向 delegate 通知状态变化 | ~40 |
| 粘贴处理 | didPasteAssets 回调代理 | ~30 |

### 1.3 12 个单例，零协议抽象

当前所有 Service 均以 `static let shared` 暴露，无任何协议封装：

```
PhotoNumberingService.shared   PhotoChangesService.shared
PhotoTagService.shared         PhotoGridSelectionState (无 shared，但直接实例化)
PhotoSortPreference            UndoManagerService.shared
AssetPasteboard (无 shared)    OverlayDisplaySettings.shared
HierarchyCollapseSettings.shared PhotoPermissionManager.shared
PhotoRecognitionService.shared  PhotoHeaderService.shared
PhotoHierarchyService.shared    AppAppearance.shared
```

**后果：**
- 无法进行单元测试（无法 mock 替换）
- 隐式依赖链不可见（读代码无法知道一个类依赖哪些服务）
- PhotoGridView 直接访问 `PhotoNumberingService.shared`、`HierarchyCollapseSettings.shared`，Controller 也直接访问，形成多对多耦合

### 1.4 状态散落四处

同一张照片网格的"状态"分布在至少 4 个位置：

```
[View 层]   PhotoGridView.selectionState        → 选择状态
[Service]   PhotoNumberingService.levelsCache   → 层级状态
[Service]   PhotoSortPreference                 → 排序偏好
[View 层]   BasePhotoViewController 的各个 flag → 选择模式 / 范围选择 / 锚点
```

状态变更的传播路径混乱——有时通过 delegate 回调，有时通过直接修改共享单例，有时通过 NotificationCenter。

### 1.5 6 个级联工具栏同步方法

```
syncHierarchyToolbarButtonsEnabled()     // 层级工具栏按钮状态
syncQuickJumpBarButtonsEnabled()         // 快跳按钮状态
syncHierarchyBranchNavBarButtonsEnabled() // 层级分支导航栏按钮
syncSelectionQuickNavBarButtonsEnabled()  // 选择模式快跳按钮
syncSuccess(message:)                     // 同步成功通知
syncFailed(message:)                      // 同步失败通知
```

这些方法的调用顺序有隐含依赖，忘记调用某一个就会导致 UI 状态不一致。它们分散在 `BasePhotoViewController` 的不同区域，在每次状态变更时需要手动依次触发，极易遗漏。

### 1.6 深度耦合

**Controller → View 方向：** `BasePhotoViewController` 读取 `PhotoGridView` 的 15+ 个内部属性：

```swift
// 典型模式 —— Controller 直接深入 View 的内部状态
gridView.assets
gridView.visibleAssets
gridView.selectedAssetCount
gridView.quickJumpMode
gridView.supportsHierarchyNumbering
gridView.hierarchyToolbarDelegate
gridView.currentCollection
gridView.allVisibleSelectionActive
// ... 还有更多
```

**View → Service 方向：** `PhotoGridView` 直接访问单例：

```swift
// PhotoGridView.swift 内部
PhotoNumberingService.shared.computeNumbers(...)
HierarchyCollapseSettings.shared.spanMode
PhotoTagService.shared.filteredIdentifiers(...)
```

这形成了双向依赖：Controller 依赖 View 的内部实现，View 依赖全局单例。

### 1.7 继承而非组合——三级 VC 层次

```
UIViewController
 └── BasePhotoViewController          ★ 核心基类（全部逻辑在这里）
      ├── GalleryViewController        # 图库基类
      │    └── HomeViewController      # "图库" Tab
      └── PhotoGridViewController      # 相簿详情
```

**继承带来的问题：**
- `GalleryViewController` 和 `PhotoGridViewController` 各自覆写 `createOperationMenu()`、`createSortMenu()`，但菜单的逻辑高度相似
- 粘贴/分享逻辑在 `GalleryViewController` 和 `PhotoGridViewController` 中**完全重复**（`didTapShareButton`、`AddToAlbumActivity`/`GalleryAddToAlbumActivity` 各自定义）
- 新增一个照片网格场景（如某个特殊相簿类型）需要继承并覆写大量方法，极易破坏基类行为

### 1.8 Delegate 协议膨胀

`PhotoGridViewDelegate` 包含 11 个方法，绝大多数 delegate 只使用其中的 2-3 个：

```
func photoGridView(_:didSelectItemAt:IndexPath)     // 仅选择模式
func photoGridView(_:didSelectItemAt:PHAsset)        // 仅查看模式
func photoGridView(_:didDeselectItemAt:IndexPath)    // 仅选择模式
func photoGridView(_:didDeselectItemAt:PHAsset)       // 几乎不用
func photoGridView(_:didSelectedItems:[PHAsset])     // 高频，但 >512 项时空数组
func photoGridView(_:didSetAnchor:PHAsset)            // 仅排序时
func photoGridView(_:didPasteAssets:after:)           // 仅粘贴时
func photoGridView(_:didRequestAddTagFor:)            // 仅标签
func photoGridView(_:didRequestDelete:)               // 仅删除
```

**问题：** 所有 delegate 必须实现（或依赖默认空实现），新增行为需要修改协议本身。

---

## 二、目标架构设计

### 2.1 总体架构：MVVM-Coordinator 混合

采用**务实渐进式**的 MVVM-Coordinator 架构，而非纯粹的理论模式：

```
┌─────────────────────────────────────────────────────────────┐
│                      Coordinator 层                         │
│  负责导航：present / push / showAlert / showPicker          │
│  每个 Coordinator 管理一个用户流程（Flow）                    │
└──────────────┬──────────────────────────────────────────────┘
               │ creates / owns
               ▼
┌─────────────────────────────────────────────────────────────┐
│                     ViewModel 层                            │
│  @Published 状态 →  View 订阅 (Combine / 闭包)               │
│  不含 UIKit 引用，可单元测试                                  │
└──────────────┬──────────────────────────────────────────────┘
               │ calls
               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Use Case 层                             │
│  单一职责的业务操作：SelectPhotos / ToggleHierarchy           │
│  编排多个 Service 完成一个用户意图                             │
└──────────────┬──────────────────────────────────────────────┘
               │ calls
               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Service 层 (Protocol)                    │
│  每个 Service 定义协议，构造函数注入                           │
│  纯逻辑，不含 UI                                              │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 数据流方向：单向

```
用户操作
  │
  ▼
ViewController ──(调用)──▶ ViewModel.handle(action)
                                │
                                ▼
                           UseCase.execute()
                                │
                                ▼
                           Service.perform()
                                │
                                ▼
                           ViewModel.state = newState (@Published)
                                │
                                ▼
                           View 订阅 → UI 更新
```

**关键约束：** View 永远不直接修改 ViewModel 的状态。View 只发送"意图"（Intents）给 ViewModel，ViewModel 处理后产生新状态，View 被动响应。

### 2.3 分层依赖规则

```
┌──────────┐     ┌──────────┐
│   View   │────▶│ViewModel │     View 层可以 import UIKit
└──────────┘     └────┬─────┘
                       │
              ┌────────▼─────┐
              │   Use Case   │     这一层起禁止 import UIKit
              └──────┬───────┘
                     │
              ┌──────▼───────┐
              │   Service    │     纯逻辑，可单元测试
              └──────────────┘
```

- **上层依赖下层**（View → ViewModel → UseCase → Service）
- **下层绝不依赖上层**（Service 不知道 ViewModel 的存在）
- **同层通过协议解耦**（ServiceA 依赖 ServiceB 的协议，而非具体类型）

### 2.4 DI 容器设计（轻量协议式）

不引入 Swinject/Cleanse 等第三方 DI 框架，使用手动构造函数注入 + 简单容器：

```swift
/// 应用级服务容器
final class AppContainer {
    // 单例服务（无状态或全局状态）
    let permissionManager: PhotoPermissionManaging
    let recognitionService: PhotoRecognitionServicing

    // 作用域服务（按相簿/用户流程创建）
    func makePhotoGridContainer(collection: PHAssetCollection) -> PhotoGridContainer
}

/// 相簿作用域容器
final class PhotoGridContainer {
    let collection: PHAssetCollection
    let numberingService: PhotoNumberingServicing
    let changesService: PhotoChangesServicing
    let tagService: PhotoTagServicing
    let headerService: PhotoHeaderServicing

    func makeViewModel() -> PhotoGridViewModel
}
```

**核心原则：** 每个 Service 定义协议，通过构造函数注入，测试时替换为 Mock。

### 2.5 事件总线（替代 Delegate 链）

对于跨模块的"通知型"事件（如照片库变更），用类型安全事件总线替代 delegate 链：

```swift
enum PhotoLibraryEvent {
    case assetsChanged(collectionID: String)
    case assetsInserted(ids: [String], collectionID: String)
    case assetsRemoved(ids: [String], collectionID: String)
}

protocol EventBusProtocol {
    func publish(_ event: PhotoLibraryEvent)
    func subscribe(to eventType: PhotoLibraryEvent.Type) -> AsyncStream<PhotoLibraryEvent>
}
```

### 2.6 Feature-First 目录结构

```
HSPhotos/
├── App/                              # 应用入口 + DI 组装
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── AppContainer.swift
│
├── Features/
│   ├── PhotoGrid/                    # 照片网格功能（自包含模块）
│   │   ├── View/
│   │   │   ├── PhotoGridViewController.swift     (~200 行)
│   │   │   ├── PhotoGridView.swift               (~600 行)
│   │   │   └── PhotoCell.swift
│   │   ├── ViewModel/
│   │   │   └── PhotoGridViewModel.swift          (~300 行)
│   │   ├── UseCase/
│   │   │   ├── ToggleSelectionUseCase.swift
│   │   │   ├── ToggleHierarchyUseCase.swift
│   │   │   ├── QuickJumpUseCase.swift
│   │   │   └── BatchLevelChangeUseCase.swift
│   │   ├── Engine/                   # 专用计算引擎
│   │   │   ├── QuickJumpEngine.swift
│   │   │   ├── VisibilityComputeEngine.swift
│   │   │   └── HierarchyNumberingEngine.swift
│   │   └── Menu/
│   │       ├── OperationMenuBuilder.swift
│   │       └── SortMenuBuilder.swift
│   │
│   ├── AlbumList/                    # 相簿列表功能
│   │   └── ...
│   │
│   ├── Viewer/                       # 全屏查看器
│   │   └── ...
│   │
│   └── Tags/                         # 标签功能
│       └── ...
│
├── Core/                             # 跨功能共享
│   ├── Services/                     # 服务协议 + 实现
│   │   ├── Protocol/
│   │   │   ├── PhotoNumberingServicing.swift
│   │   │   ├── PhotoChangesServicing.swift
│   │   │   ├── PhotoTagServicing.swift
│   │   │   └── ...
│   │   └── Implementation/
│   │       ├── PhotoNumberingService.swift
│   │       ├── PhotoChangesService.swift
│   │       └── ...
│   ├── Models/                       # 数据模型
│   ├── Extensions/
│   └── Utilities/
│
├── Coordinators/                     # 导航协调器
│   ├── AppCoordinator.swift
│   ├── PhotoGridCoordinator.swift
│   └── ViewerCoordinator.swift
│
└── Resources/
```

---

## 三、关键设计模式应用

### 3.1 Coordinator 模式

**目标：** 将所有 `present`、`push`、`showAlert`、`showPicker` 从 ViewController 中提取出来。

```
AppCoordinator
├── MainTabCoordinator
│   ├── GalleryCoordinator (图库 Tab)
│   │   └── PhotoGridFlow
│   │       ├── PhotoGridViewController (push)
│   │       ├── ViewerFlow (present .overFullScreen)
│   │       ├── AlbumPickerFlow (present)
│   │       └── TagAssignFlow (present)
│   │
│   └── AlbumListCoordinator (相簿 Tab)
│       └── PhotoGridFlow (同上)
│
└── PermissionFlow (splash)
```

```swift
protocol PhotoGridCoordinating {
    func showViewer(for asset: PHAsset, sourceImage: UIImage?)
    func showAlbumPicker(for assets: [PHAsset])
    func showTagAssign(for asset: PHAsset)
    func showOverlaySettings()
    func showAlert(_ alert: UIAlertController)
}
```

### 3.2 Strategy 模式

**目标：** 完成现有的部分 strategy 实现，统一排序、选择模式、快跳模式：

```swift
// 排序策略（已有 PhotoSortPreference 枚举作为基础）
protocol PhotoSortStrategy {
    var sortDescriptors: [NSSortDescriptor] { get }
    func menuElement(selected: PhotoSortPreference) -> UIMenuElement
}

// 选择策略
protocol PhotoSelectionStrategy {
    func handleTap(at indexPath: IndexPath, state: SelectionState) -> SelectionState
    func handleSwipe(from: IndexPath, to: IndexPath, state: SelectionState) -> SelectionState
}

// 快跳策略
protocol QuickJumpStrategy {
    func targetIndex(from current: Int, in visible: [PHAsset], selection: SelectionState) -> Int?
    var mode: PhotoGridQuickJumpMode { get }
}
```

### 3.3 Factory 模式 — CellConfiguratorFactory

**目标：** 将 82 行的 `cellForItemAt` 压缩到 6 行：

```swift
// 当前：82 行 if/else/switch 判断覆盖层、层级编号、折叠角标、选择状态 ...
// 目标：
func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = cv.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as! PhotoCell
    let configurator = CellConfiguratorFactory.make(viewModel: viewModel, indexPath: indexPath)
    configurator.configure(cell)
    return cell
}
```

每个 CellConfigurator 负责单一配置维度（层级标签、覆盖层文本、选中指示器、折叠角标等），通过组合而非分支来处理。

### 3.4 Chain of Responsibility — ActionGroup

**目标：** 菜单构建可组合，添加新操作不需要修改 Base VC：

```swift
protocol MenuActionProvider {
    func provideActions(context: MenuContext) -> [UIMenuElement]
    var priority: Int { get }
}

// 每个操作独立为 ActionProvider
struct DeleteActionProvider: MenuActionProvider { ... }
struct CopyActionProvider: MenuActionProvider { ... }
struct SortActionProvider: MenuActionProvider { ... }
struct HierarchyActionProvider: MenuActionProvider { ... }

// 菜单构建器按 priority 排序、组装
final class OperationMenuBuilder {
    private let providers: [MenuActionProvider]

    func build(context: MenuContext) -> UIMenu {
        let elements = providers
            .sorted { $0.priority < $1.priority }
            .flatMap { $0.provideActions(context: context) }
        return UIMenu(title: "", children: elements)
    }
}
```

### 3.5 协议式 DI

```swift
// 定义协议
protocol PhotoNumberingServicing {
    func levels(for collectionID: String) -> [String: Int]
    func setLevel(_ level: Int, for assetID: String, in collectionID: String)
    func computeNumbers(for assets: [PHAsset], in collectionID: String) -> [String: String]
    func visibleAssetIDs(for orderedIDs: [String], in collectionID: String) -> [String]
}

// 生产实现
final class PhotoNumberingService: PhotoNumberingServicing { ... }

// 测试 Mock
final class MockNumberingService: PhotoNumberingServicing { ... }

// 注入（构造函数）
final class PhotoGridViewModel {
    private let numberingService: PhotoNumberingServicing
    private let changesService: PhotoChangesServicing

    init(numberingService: PhotoNumberingServicing,
         changesService: PhotoChangesServicing) {
        self.numberingService = numberingService
        self.changesService = changesService
    }
}
```

---

## 四、具体改进目标

### 4.1 工具栏同步收拢

**当前：** 6 个 `sync*` 方法分散调用，每个方法内部检查多个条件。

**目标：** 收拢为 ViewModel 中的 2 个绑定方法：

```swift
// ViewModel 内部
@Published var navBarState: NavBarState   // 所有导航栏按钮的 title/image/isEnabled 的 snapshot
@Published var toolbarState: ToolbarState // 所有工具栏按钮状态

// ViewController 中
viewModel.$navBarState
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in
        self?.applyNavBar(state)
    }

viewModel.$toolbarState
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in
        self?.applyToolbar(state)
    }
```

ViewModel 的 `navBarState` / `toolbarState` 在每次状态变更时自动重新计算，不需要调用方记得触发。

### 4.2 cellForItemAt 瘦身

**当前：** 82 行内联逻辑。

**目标：** 6 行 + CellConfiguratorFactory。

```swift
struct CellConfigurator {
    let overlayText: String?
    let hierarchyNumber: String?
    let isCollapsed: Bool
    let isSelected: Bool
    let selectionRank: Int?
    let isAnchor: Bool

    func configure(_ cell: PhotoCell) {
        cell.updateOverlay(text: overlayText)
        cell.updateHierarchyLabel(number: hierarchyNumber)
        cell.updateCollapseIndicator(isCollapsed: isCollapsed)
        cell.updateSelectionIndicator(isSelected: isSelected, rank: selectionRank)
        cell.updateAnchorIndicator(isAnchor: isAnchor)
    }
}
```

### 4.3 菜单构建可组合

**当前：** 在 Base VC 中添加新操作需要修改 `createOperationMenu()`、`createHierarchyMenuChildren()`，子类还需要各自覆写。

**目标：** 新增操作只需创建新的 `MenuActionProvider` 并注册到 builder：

```swift
// 添加一个新操作（如在照片查看器中新增"调整日期"操作）
struct AdjustDateActionProvider: MenuActionProvider {
    let priority = 50
    func provideActions(context: MenuContext) -> [UIMenuElement] {
        guard context.selectedCount == 1 else { return [] }
        return [UIAction(title: "调整日期", image: UIImage(systemName: "calendar")) { _ in
            context.coordinator.showDateAdjustment(for: context.selectedAssets[0])
        }]
    }
}
```

### 4.4 控制器瘦身

**目标：** `BasePhotoViewController` 从 ~1890 行降至 ~200 行。

瘦身后的 ViewController 只做：
- 配置 ViewModel 和 View 的绑定
- 管理 View 生命周期（viewDidLoad / viewWillAppear / viewWillDisappear）
- 转发用户事件给 ViewModel

```
BasePhotoViewController (~200 行)
├── [1] viewDidLoad — 创建绑定
├── [2] setupBindings — subscribe to @Published
├── [3] applyNavBar / applyToolbar — 纯 UI 赋值
└── [4] @objc action handlers — 转发给 ViewModel
```

### 4.5 View 瘦身 + 专用引擎

**目标：** `PhotoGridView` 从 ~2663 行降至 ~600 行 + 4 个专用引擎。

```
PhotoGridView (~600 行)
├── UICollectionView DataSource/Delegate
├── 手势分发（长按/双击/滑动选择 → 转发给引擎）
└── 布局配置（列数/间距/缩放）

QuickJumpEngine (~300 行)
├── targetIndices 计算 + 缓存
├── 三种跳转模式的实现
└── 跳转动画

VisibilityComputeEngine (~250 行)
├── computeVisibleAssets
├── 折叠/展开层级
└── 可见集 diff 计算

HierarchyNumberingEngine (~200 行)
├── 编号缓存预热
├── 编号显示更新
└── 层级标签格式化

CellConfiguratorFactory (~150 行)
├── 根据 ViewModel 状态生成 CellConfigurator
└── 各配置维度的组合
```

---

## 五、性能优化捆绑

架构重构过程中，同步修复性能扫描报告中的高优问题：

### 与重构同步修复的 HIGH 优先级问题

| 编号 | 问题 | 修复方式 | 在重构中对应 |
|------|------|---------|------------|
| H1 | 滑动选择 O(range × k) 重新编号 | SelectionState.toggle 改为惰性 rank | SelectionState 重构为 ViewModel 的 @Published |
| H2 | selectedPhotos 每次分配数组 | 先检查阈值，>512 直接返回 [] | ViewModel 中 selectedAssetIDs 用 Set 直接判断 count |
| H3 | 三重图片缓存 150-200MB | 移除 PhotoCell.imageCache，统一用 PHCachingImageManager | Cell 配置逻辑重构时移除 |
| H5 | 全量急切日期格式化 | 改为惰性格式化，仅在 visibleCells 需要时 | CellConfigurator 按需格式化 |
| H6 | 层级缓存预热忽略 visible | 尊重 visible 参数，只预热可见资产 | VisibilityComputeEngine 中修正 |
| H7 | 打开查看器同步请求 | 去掉 isSynchronous，异步加载 | Coordinator 中 present viewer 先传缩略图 |
| H8 | 不必要的 reloadData() | diff-based update 替代，仅在需要时刷新 | applyVisibleAssetsChangeAnimated 优化 |

---

## 六、分阶段实施路线图

### Phase 1：基础解耦（第 1 周）

**目标：** 打破 View → Service 的直接依赖，为后续重构铺路。

| 任务 | 内容 | 风险 |
|------|------|------|
| 1.1 | 定义核心 Service 协议 | 为 PhotoNumberingService、PhotoChangesService、PhotoTagService 定义协议 | 低 |
| 1.2 | 修改 PhotoGridView 接受协议注入 | 将 `PhotoNumberingService.shared` 替换为构造函数注入的 `any PhotoNumberingServicing` | 低 |
| 1.3 | 修改 BasePhotoViewController 接受协议注入 | 同上 | 低 |
| 1.4 | 创建 AppContainer | 单例容器，组装默认 Service 实现 | 低 |
| 1.5 | 单元测试验证 | 为 PhotoNumberingLogic、PhotoGridSelectionState 补齐测试 | 低 |

**产出：** Service 从具体类型解耦为协议，现有功能完全不变。

---

### Phase 2：ViewModel 引入 + 工具栏收拢（第 2 周）

**目标：** 引入 ViewModel 层，将工具栏同步逻辑集中。

| 任务 | 内容 | 风险 |
|------|------|------|
| 2.1 | 创建 PhotoGridViewModel | 将选择状态、层级状态、排序偏好搬到 ViewModel，用 @Published 暴露 | 中 |
| 2.2 | 实现 navBarState / toolbarState 绑定 | 收拢 6 个 sync 方法为 2 个 @Published struct | 中 |
| 2.3 | BasePhotoViewController 转为绑定消费 | Controller 中 subscribe，删除所有 sync 手动调用 | 中 |
| 2.4 | 修复 H2 (selectedPhotos 提前返回) | 在 ViewModel 中加 count guard | 低 |
| 2.5 | 修复 M1 (toggle 惰性 rank) | 重构 PhotoGridSelectionState.toggle | 低 |

**产出：** 工具栏按钮同步从"手动调用"变为"自动响应"，ViewModel 持有核心状态。

---

### Phase 3：引擎提取 + View 瘦身（第 3 周）

**目标：** 将 PhotoGridView 的专用逻辑提取为独立引擎。

| 任务 | 内容 | 风险 |
|------|------|------|
| 3.1 | 提取 QuickJumpEngine | 将 ~500 行快跳代码移到独立类型，PhotoGridView 持有引用 | 中 |
| 3.2 | 提取 VisibilityComputeEngine | 将 computeVisibleAssets 等 ~300 行移到独立类型 | 中 |
| 3.3 | 提取 HierarchyNumberingEngine | 将层级缓存预热/编号更新逻辑独立 | 低 |
| 3.4 | 提取 CellConfiguratorFactory | 重构 cellForItemAt 从 82 行到 6 行 | 中 |
| 3.5 | 修复 H5 (惰性日期格式化) + H6 (visible 参数) | 在引擎重构中一并修复 | 低 |

**产出：** PhotoGridView 降至 ~600 行，职责清晰。

---

### Phase 4：菜单可组合 + Coordinator 引入（第 4 周）

**目标：** 菜单添加不再需要修改基类，导航逻辑从 VC 提取。

| 任务 | 内容 | 风险 |
|------|------|------|
| 4.1 | 实现 MenuActionProvider + OperationMenuBuilder | 5 个 createMenu 方法拆为独立 ActionProvider | 高 |
| 4.2 | 消除 Gallery/PhotoGrid 菜单覆写 | 子类通过 DI 注册自己的 ActionProvider 而非覆写方法 | 高 |
| 4.3 | 引入 PhotoGridCoordinator | 提取 present viewer / albumPicker / tagAssign | 中 |
| 4.4 | 消除子类重复的粘贴/分享逻辑 | 提取 PasteUseCase、ShareUseCase 复用 | 中 |
| 4.5 | 修复 H3 (移除冗余缓存) | 移除 PhotoCell.imageCache 和 ImageCache.shared | 中 |

**产出：** 菜单添加变为注册 ActionProvider，子类不再覆写菜单方法。

---

### Phase 5：特性目录重组织 + 性能收尾（第 5 周）

**目标：** 目录结构切换为 feature-first，收尾性能修复。

| 任务 | 内容 | 风险 |
|------|------|------|
| 5.1 | 目录重组 | 将现有文件按 Features/PhotoGrid、Features/AlbumList 迁移 | 低 |
| 5.2 | 修复 H7 (异步查看器源图) + H8 (减少 reloadData) | Coordinator + diff-based update | 中 |
| 5.3 | 修复 M2-M12 中优先级问题 | 批量修复性能扫描报告中的中优问题 | 低 |
| 5.4 | 事件总线引入（可选） | 用 EventBus 替代 PHPhotoLibrary 变更的 delegate 链传播 | 低 |
| 5.5 | 回归测试 | 全量手动测试 + 性能基准对比 | 中 |

**产出：** 完整的 feature-first 目录结构，性能扫描高优和中优问题全部修复。

---

## 七、风险与应对

### 7.1 技术风险

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| Combine @Published 引入内存泄漏 | 中 | 中 | 所有 sink 使用 `[weak self]`，Phase 2 中 Code Review 专项检查 |
| diff-based update 逻辑错误导致 UI 不刷新 | 中 | 高 | Phase 3 中保留 reloadData() 作为回退选项，加 #if DEBUG 断言 |
| 协议抽象导致性能下降（动态派发） | 低 | 低 | 对热路径（如 computeNumbers）保留具体类型调用 |
| 新的 MenuActionProvider 注册遗漏导致菜单项丢失 | 中 | 中 | Phase 4 中为菜单项数量编写测试断言 |

### 7.2 流程风险

| 风险 | 应对 |
|------|------|
| 重构期间新功能开发并存 | 每个 Phase 产出独立分支，合入前先 rebase main |
| 测试覆盖不足 | Phase 1 先补齐核心 Service 测试，后续 Phase 每次变更连带测试 |
| 性能回退 | 每个 Phase 结束后用 Instruments (Time Profiler / Allocations) 做基准对比 |

### 7.3 回退策略

- 每个 Phase 为独立 PR，可以单独合入或回退
- Phase 1 是纯"加协议"，零行为变更——若出现问题直接 revert
- Phase 2 引入 ViewModel 时，BasePhotoViewController 保留原代码路径，通过 `#if NEW_ARCH` 编译开关切换
- Phase 3-5 依赖前序 Phase，但每个引擎提取可以独立验证

---

## 八、成功指标

### 代码质量

| 指标 | 当前 | 目标 |
|------|------|------|
| BasePhotoViewController 行数 | ~1890 | ~200 |
| PhotoGridView 行数 | ~2663 | ~600 |
| 单例数量（无协议） | 12 | 0（所有 Service 有协议） |
| 最长方法行数 (cellForItemAt) | 82 | 6 |
| sync 方法数量 | 6 | 2 (自动绑定) |
| 菜单创建方法数量 | 5 (分散) | 1 (组合) |
| 单元测试覆盖率 | <10% | >50% (核心逻辑) |

### 性能

| 指标 | 当前 | 目标 |
|------|------|------|
| 滑动选择 1000 项耗时 | O(n × k) | O(n) |
| 大相簿 (50K) 峰值内存 | ~400MB | ~200MB |
| 进入大相簿主线程阻塞 | 200-500ms | <50ms |
| 不必要的 reloadData 调用 | 5+ 场景 | 0 |

---

## 附录：架构对比图

```
┌──────── 当前架构（MVC + Service 单例） ────────┐
│                                                │
│  ┌──────────────────────┐                     │
│  │ BasePhotoViewController│◄───── 直接访问 ───┼───────┐
│  │     (~1890 行)        │                    │       │
│  │  15+ 职责混杂          │                    │       │
│  └──────────┬───────────┘                     │       │
│             │ 直接访问内部属性                   │       │
│  ┌──────────▼───────────┐                     │       │
│  │   PhotoGridView       │──── 直接访问 ───────┼───┐   │
│  │     (~2663 行)        │                    │   │   │
│  │  10+ 职责混杂          │                    │   │   │
│  └──────────────────────┘                     │   │   │
│                                                │   │   │
│  ┌──────────────────────┐                     │   │   │
│  │  Singleton A  .shared │◄────────────────────┼───┼───┘
│  ├──────────────────────┤                     │   │
│  │  Singleton B  .shared │◄────────────────────┼───┘
│  ├──────────────────────┤                     │
│  │  Singleton C  .shared │◄────────────────────┘
│  └──────────────────────┘                     │
│                                                │
│  问题：双向耦合、状态分散、不可测试              │
└────────────────────────────────────────────────┘


┌──────── 目标架构（MVVM-Coordinator + DI） ──────┐
│                                                  │
│  ┌──────────────────────┐                       │
│  │ PhotoGridCoordinator  │  导航：present/push    │
│  └──────────┬───────────┘                       │
│             │ owns                               │
│  ┌──────────▼───────────┐                       │
│  │ PhotoGridViewController│  仅 UI 绑定 (~200 行) │
│  │  ┌─────────────────┐  │                       │
│  │  │  @Published 绑定  │  │                       │
│  │  └────────┬────────┘  │                       │
│  └───────────┼───────────┘                       │
│              │                                    │
│  ┌───────────▼───────────┐                       │
│  │  PhotoGridViewModel    │  状态持有 (~300 行)    │
│  │  @Published navBar     │                       │
│  │  @Published toolbar    │                       │
│  └───────────┬───────────┘                       │
│              │ calls                              │
│  ┌───────────▼───────────┐                       │
│  │  UseCase Layer         │  单一职责业务操作       │
│  │  SelectPhotos / Jump   │                       │
│  └───────────┬───────────┘                       │
│              │ calls                              │
│  ┌───────────▼───────────┐                       │
│  │  Service Protocols     │  全部注入，可替换       │
│  │  Numbering / Changes   │                       │
│  └────────────────────────┘                       │
│                                                    │
│  特点：单向数据流、依赖注入、可测试                   │
└────────────────────────────────────────────────────┘
```

---

## 附录 B：Phase 依赖关系

```
Phase 1 (Service 协议)
  │
  ▼
Phase 2 (ViewModel + 绑定)
  │
  ├──────────────────┐
  ▼                  ▼
Phase 3 (引擎提取)   Phase 4 (菜单 + Coordinator)
  │                  │
  └────────┬─────────┘
           ▼
     Phase 5 (目录重组 + 收尾)
```

- Phase 1 是所有后续 Phase 的前置（需要先完成协议定义）
- Phase 3 和 Phase 4 可以并行开发（引擎提取不依赖菜单重构）
- Phase 5 依赖 Phase 3 + Phase 4 完成
