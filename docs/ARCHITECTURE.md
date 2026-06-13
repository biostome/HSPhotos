# HSPhotos 技术架构文档

> 面向 AI 与工程师的技术参考，涵盖模块划分、数据流、关键系统设计与性能优化记录。
> 产品定义见 `README.md`，变更记录见 `CHANGELOG.md`。

---

## 一、项目概览

| 维度 | 说明 |
|------|------|
| **平台** | iOS (iPhone)，Swift 5 + UIKit |
| **最低版本** | iOS 17+ |
| **数据源** | 系统 `PHPhotoLibrary`，照片实体归属于系统 |
| **元数据层** | UserDefaults（编号、折叠、标签、排序偏好、覆盖层设置） |
| **架构模式** | MVC + Service 层，无第三方依赖 |

---

## 二、模块地图

```
HSPhotos/
├── AppDelegate.swift / SceneDelegate.swift   # 应用入口
├── Controllers/
│   ├── MainViewController.swift              # 启动屏 & 权限检查
│   ├── MainTabbarViewContoller.swift         # TabBar: 图库 + 相册
│   ├── RootNavigationViewController.swift    # 自定义 NavigationController
│   ├── Base/
│   │   └── BasePhotoViewController.swift     # 照片网格基类（核心）
│   ├── Gallery/
│   │   ├── GalleryViewController.swift       # 图库网格基类
│   │   └── HomeViewController.swift          # "图库" Tab（全部照片）
│   ├── Detail/
│   │   ├── PhotoGridViewController.swift     # 相簿详情网格
│   │   └── OverlaySettingsViewController.swift # 覆盖层设置页
│   ├── Album/
│   │   └── AlbumListViewController.swift     # 相簿/文件夹列表
│   ├── Tags/
│   │   ├── TagFilterPanelViewController.swift # 标签筛选面板
│   │   └── TagAssignViewController.swift     # 标签分配面板
│   ├── Viewer/
│   │   ├── GalleryViewerViewController.swift  # 全屏查看器
│   │   ├── GalleryViewerThumbnailStripView.swift
│   │   ├── HeroPhotoTransitionAnimator.swift
│   │   └── PhotoAssetInfoSheetViewController.swift
│   └── Permission/
│       └── PermissionViewController.swift
├── Views/
│   ├── Detail/
│   │   ├── PhotoGridView.swift               # 照片网格视图（核心）
│   │   ├── PhotoCell.swift                   # 照片单元格
│   │   └── SearchBarView.swift               # 搜索栏
│   ├── Home/                                 # 相册列表视图
│   └── Tags/                                 # 标签 UI 组件
├── Services/
│   ├── PhotoCollectionStore.swift            # 资产列表内存存储
│   ├── PhotoNumberingService.swift           # 多级编号运行时服务
│   ├── PhotoNumberingLogic.swift             # 编号纯函数（无 UIKit 依赖）
│   ├── PhotoChangesService.swift             # PHPhotoLibrary 变更封装
│   ├── PhotoTagService.swift                 # 标签 CRUD
│   ├── PhotoGridSelectionState.swift         # 选择状态（无 UI）
│   ├── PhotoSortPreference.swift             # 排序偏好枚举
│   ├── AssetPasteboard.swift                 # 剪贴板服务
│   ├── UndoManager.swift                     # 撤销/重做
│   ├── OverlayDisplaySettings.swift          # 覆盖层显示设置
│   ├── HierarchyCollapseSettings.swift       # 层级折叠模式设置
│   ├── PhotoPermissionManager.swift          # 权限管理
│   └── PhotoRecognitionService.swift         # Vision 场景识别
├── Models/
│   ├── AlbumListItem.swift                   # 相簿/文件夹列表项
│   └── PhotoTag.swift                        # 标签模型
├── Calculators/                              # (预留) 计算逻辑
├── Coordinators/                             # (预留) 协调器
├── Managers/                                 # (预留) 管理器
├── Types/                                    # (预留) 类型定义
├── Utils/                                    # (预留) 工具函数
└── Tests/
    ├── HSPhotosTests.swift
    ├── PhotoGridSelectionStateTests.swift
    └── PhotoNumberingLogicTests.swift
```

---

## 三、控制器继承体系

```
UIViewController
├── MainViewController              # 启动屏
├── MainTabbarViewContoller         # UITabBarController
├── RootNavigationViewController    # UINavigationController
├── BasePhotoViewController         # 照片网格基类 ★
│   ├── GalleryViewController       # 图库网格基类
│   │   └── HomeViewController      # "图库" Tab
│   └── PhotoGridViewController     # 相簿详情网格 ★
├── AlbumListViewController         # 相簿列表
├── OverlaySettingsViewController   # 覆盖层设置
├── TagFilterPanelViewController    # 标签筛选
├── TagAssignViewController         # 标签分配
├── GalleryViewerViewController     # 全屏查看器
└── PermissionViewController        # 权限提示
```

**关键基类 `BasePhotoViewController`**：包含搜索栏、照片网格、选择模式、工具栏（快跳、层级折叠/展开）、操作菜单、撤销/重做、范围选择等全部通用逻辑。图库和相簿详情通过覆写属性/方法进行差异化。

---

## 四、数据流

### 4.1 相簿页生命周期

```
进入相簿
  │
  ├─ init(collection: PHAssetCollection)
  ├─ loadPhoto()
  │   ├─ PhotoNumberingService.loadForCollection()  ← UserDefaults → 内存缓存
  │   ├─ PHFetchOptions(sortDescriptors: sortPreference)
  │   ├─ PHAsset.fetchAssets(in:collection, options:)
  │   └─ gridView.assets = fetchedAssets
  │
  └─ viewDidLoad()
      ├─ setupToolbar()
      ├─ setupGridView()
      └─ updateVisibleAssets()           ← 应用层级折叠过滤
            │
            └─ PhotoNumberingLogic.visibleAssetIDs()
               → gridView.visibleAssets
               → collectionView.reloadData()

离开相簿
  └─ PhotoNumberingService.saveForCollection()        ← 内存缓存 → UserDefaults (后台线程)
```

### 4.2 选择与操作流

```
用户操作 → BasePhotoViewController
  ├─ 单选/多选/范围选择 → PhotoGridSelectionState (rankByID, orderedIDs)
  ├─ 全选 → allVisibleSelectionActive (懒实例化)
  ├─ 操作菜单 (更多 → 操作选项) → createOperationMenu()
  │   ├─ 撤销/重做 → UndoManagerService
  │   ├─ 剪切/拷贝/粘贴/复制 → AssetPasteboard / PhotoChangesService
  │   ├─ 添加到相簿 → AlbumListViewController (picker 模式)
  │   ├─ 添加标签 → TagAssignViewController
  │   ├─ 删除 → PhotoChangesService.delete()
  │   ├─ 排序 → PhotoChangesService.sync()       ← 写回系统
  │   └─ 层级操作 → onBatchSetLevel / Promote / Demote / Clear
  ├─ 层级操作 (底栏按钮) → applyVisibleHierarchyStep / applyAllItemsHierarchyStep
  └─ 快跳 (底栏按钮) → quickJumpTargetIndices → scrollTo
```

### 4.3 标签筛选数据流

```
TagFilterPanelViewController
  └─ 用户选择标签 + 匹配规则 (any/all)
      └─ delegate.applyTagFilter(TagFilterState)
          └─ PhotoCollectionStore.replaceFilterState()
              └─ PhotoTagService.filteredIdentifiers(by:)
                  └─ snapshot.visibleAssets 缩小为匹配子集
                      └─ gridView.apply(snapshot)
```

---

## 五、关键系统设计

### 5.1 多级编号系统

#### 概念
- 每张照片可有 **层级** (`level`: 0=无编号, 1=主级 "1", 2=子级 "1.1", 3="1.1.1"...)
- **编号字符串**不存储，由 `PhotoNumberingLogic.computeNumbers()` 在运行时从 (顺序, 层级) 计算
- 层级自动校正：若某照片 level=3 但前一个编号照片为 level=1，则自动校正为 level=2（避免"空洞"）

#### 存储
```
UserDefaults:
  photo_numbering_levels_{collectionID}    → [assetID: Int]       // 层级
  photo_numbering_collapse_{collectionID} → [assetID: Bool]      // 折叠状态

内存缓存:
  PhotoNumberingService.levelsCache       → [collectionKey: [assetID: Int]]
  PhotoNumberingService.collapsedCache    → [collectionKey: [assetID: Bool]]
```

#### 可见性计算
```
PhotoNumberingLogic.visibleAssetIDs()
  ├─ 遍历全量 orderedAssetIDs
  ├─ 用 collapsingLevel 栈追踪当前折叠状态
  ├─ 尊重 HierarchyCollapseSpanMode:
  │   ├─ .breakAtUnnumbered: level=0 的照片会打断折叠链
  │   └─ .includeGaps: 若间隙后下一编号项仍比折叠根更深，则间隙也隐藏
  └─ 返回可见 ID 列表
```

#### 编号计算（栈式算法 O(n)）
```
computeNumbers(orderedAssetIDs, levels) → [assetID: "1.2.3"]
  ├─ counters: [Int]  各层当前计数
  ├─ prefixAtLevel: [String]  各层编号前缀（增量构建，O(1) 追加）
  ├─ 遍历全量，跳过 level=0
  ├─ 层级回退时清零更深层计数器
  └─ 当前编号 = prefixAtLevel[level-1] + "." + counters[level]
```

#### 批量层级操作
```
onBatchDemoteLevel() — 下降
  ├─ 本地 levels 字典 + 循环内直接修改（零拷贝）
  ├─ 级联：shiftLevelCascadingInDict 带动后续子节点平移
  └─ replaceAllLevels 一次性写回缓存

onBatchPromoteLevel() — 提升
onBatchSetLevel(to:) — 设为主级/同级/子级
onBatchClearLevel() — 取消编号（级联清除子节点）
```

### 5.2 折叠/展开系统

#### 底栏按钮（非选择模式）
| 按钮 | 行为 | 判断条件 |
|------|------|----------|
| 折叠可见层级 | 折叠当前可见的最深未折叠层级 | `canApplyVisibleHierarchyStep(expand: false)` |
| 展开可见层级 | 展开当前可见的最浅已折叠层级 | `canApplyVisibleHierarchyStep(expand: true)` |
| 隐藏无级照片 | 切换 level=0 照片的可见性 | 切换 `hideUnleveledAssets` |

#### 按钮可用状态
- 非选择模式：基于当前可见集中的层级分布动态判断
- 选择模式：若选中集包含层级照片 → 基于选中集判断；否则 → 基于全量判断
- 缓存失效：折叠/展开执行后调用 `invalidateHierarchyEnablementCache()`

#### 链式操作
- 全部已折叠时按"折叠" → 自动触发"隐藏无级照片"
- 无级已隐藏时按"展开" → 先恢复无级照片，再展开层级

### 5.3 选择系统

#### 选择模式
```
enum PhotoSelectionMode {
  case none       // 点击打开查看器
  case multiple   // 点击切换选中
  case range      // 滑动连续选中
}
```

#### 选择状态 (`PhotoGridSelectionState`)
- `rankByID: [String: Int]` — assetID → 选中序号 (1-based)，**按选中顺序排序**
- 取消选中时自动压缩剩余序号
- 选区顺序在排序操作中至关重要

#### 全选优化
- `allVisibleSelectionActive: Bool` — 懒标记，避免为全部可见照片分配选择状态
- 实战例化发生在需要具体选中集时（如执行操作）

#### 锚点系统
- 长按任意照片 → "设为锚点"，标记排序时的插入位置
- 全选、取消锚点照片选中、退出选择模式时清除锚点

### 5.4 排序系统

```
enum PhotoSortPreference {
  case custom           // 自定义（系统相簿顺序），仅相簿可用
  case oldest           // 最旧优先
  case newest           // 最新优先
  case creationDate     // 拍摄日期
  case modificationDate // 修改日期
  case recentDate       // 最近添加（图库默认）
}
```

**排序写回**：
1. 用户选择锚点 + 要排序的照片
2. `PhotoChangesService.sync()`:
   - 验证：排序后的数量、集合与原始一致
   - `PHPhotoLibrary.performChanges`: 移除全部 → 按新顺序重新插入
3. 成功后偏好自动切换为 `.custom`

### 5.5 撤销/重做系统

```
UndoManagerService
  ├─ undoStack: [UndoAction]
  ├─ redoStack: [UndoAction]
  └─ UndoActionType: sort | delete | move | copy | paste | favorite
```

- 每次 `PhotoChangesService` 的变更操作自动记录 UndoAction
- 撤销操作本身不产生新的 UndoAction（`isUndoOperation: true`）
- 工具栏按钮 `isEnabled` 取决于 `canUndo` / `canRedo`

### 5.6 标签系统

```
PhotoTagService
  ├─ tags: [PhotoTag] (内存 + UserDefaults JSON)
  │   └─ PhotoTag { id, name, assetIdentifiers, lastUsedAt, createdAt }
  └─ filteredIdentifiers(by: TagFilterState) → Set<String>
      ├─ matchRule: .any → 匹配任一标签
      └─ matchRule: .all → 匹配全部标签
```

标签完全在应用内管理，不写入系统照片的关键词。

### 5.7 快跳系统

```
enum PhotoGridQuickJumpMode {
  case selection          // 跳转到上一个/下一个选中照片
  case hierarchyBranch    // 跳转到上一个/下一个同级编号分支
  case unleveled          // 跳转到上一个/下一个无编号 (level=0) 照片
}
```

- 层级分支模式额外提供父级/子级跳转
- 跳转目标通过 `quickJumpTargetIndices(for:)` 预计算并缓存

### 5.8 搜索栏

- 纯数字输入 → 解析为序号，跳到第 N 张照片
- 文字输入 → 模糊匹配标签名称，应用标签筛选
- 清空 → 移除标签筛选

---

## 六、性能优化记录

### 6.1 全选卡顿修复

**问题**：全选 25000 张照片时 `visibleHierarchyStepPlan` 内部多次 O(n) 扫描。
**修复**（`PhotoNumberingLogic`）：预计算 `nextNumberedIdx[i]` 和 `parentIdx[i]` 数组，将 O(n²) 降为 O(n)。

### 6.2 可见性计算优化

**问题**：`visibleAssetIDs` 对 level=0 项重复扫描寻找下一个编号层级。
**修复**（`PhotoNumberingLogic`）：预计算 `nextNumberedLv[i]` 数组，O(1) 查找。

### 6.3 批量下降层级卡顿修复（本次分支核心）

**瓶颈 1** — 字符串拼接 O(d²)：
`computeNumbers()` 内 `parts.map{String}.joined(separator:)` 对深度为 d 的链每项重建完整编号字符串。
**修复**：增量构建，`prefixAtLevel[k] = "\(prefixAtLevel[k-1]).\(counters[k])"`，O(d) 分配。

**瓶颈 2** — 字典 Copy-on-Write：
`setLevel()` 每次调用触发全局 levels 字典拷贝（`dict = cache[key]; dict[id] = v; cache[key] = dict` 导致 CoW）。
**修复**：`cache.removeValue(forKey:)` 先移除引用再修改。

**瓶颈 3** — 逐条写回缓存：
批处理循环内每条 `setLevel` 都有 `removeValue→modify→storeBack` 三次字典哈希操作。
**修复**：本地 `var levels: [String:Int]` 直接修改 + `replaceAllLevels()` 一次性写回。

**瓶颈 4** — 不必要的全量重载：
`refreshParagraphDisplay()` → `computeVisibleAssets` (O(n)) → `elementsEqual` (O(n)) → `reloadData()` → 每 cell `configure()` 触发 PHImageManager 请求。
**修复**：新增 `refreshHierarchyNumbersOnly()` — 重算缓存后直接遍历 `visibleCells`，调用 `PhotoCell.updateHierarchyDisplay()` 就地更新标签，完全绕过 reloadData。

### 6.4 快跳目标索引缓存

`quickJumpTargetIndices` 结果被缓存，在可见集变化时失效，避免每次按钮状态更新都重新扫描。

---

## 七、文件清单与职责

### Services（服务层）

| 文件 | 职责 | 依赖 |
|------|------|------|
| `PhotoCollectionStore` | 相簿资产列表内存存储，管理 snapshot | PHPhotoLibrary |
| `PhotoNumberingService` | 层级缓存读写、折叠/展开、可见集过滤 | UserDefaults, PhotoNumberingLogic |
| `PhotoNumberingLogic` | 编号计算、可见性判断、层级操作（纯函数） | 无 |
| `PhotoChangesService` | 系统照片库变更（排序/删除/移动/复制/粘贴） | PHPhotoLibrary, UndoManager |
| `PhotoTagService` | 标签 CRUD、筛选 | UserDefaults |
| `PhotoGridSelectionState` | 选择序号维护（纯数据，无 UI） | 无 |
| `PhotoSortPreference` | 排序枚举 + NSSortDescriptor 映射 | 无 |
| `AssetPasteboard` | 系统剪贴板读写选中的照片 ID | UIPasteboard |
| `UndoManagerService` | 撤销/重做栈 | 无 |
| `OverlayDisplaySettings` | 覆盖层偏好 (UserDefaults + Notification) | UserDefaults |
| `HierarchyCollapseSettings` | 折叠间隙模式 (UserDefaults + Notification) | UserDefaults |
| `PhotoPermissionManager` | PHPhotoLibrary 授权状态管理 | Photos |
| `PhotoRecognitionService` | Vision 场景分类（NSCache 缓存） | Vision |

### Views（视图层）

| 文件 | 职责 |
|------|------|
| `PhotoGridView` | UICollectionView 封装，管理 assets/visibleAssets，处理选择手势、折叠动画 |
| `PhotoCell` | 照片缩略图单元格，覆盖层标签（序号/编号/日期），层级折叠角标 |
| `SearchBarView` | 搜索栏，纯数字跳转 + 标签名搜索 |
| `AlbumListView` / `AlbumListCell` 等 | 相簿列表 UI |
| `TagChipView` / `TagChipWrapView` | 标签选择芯片组件 |

### Controllers（控制器层）

见第三章继承体系。核心文件：
- `BasePhotoViewController` (~1600 行) — 全部网格通用逻辑
- `PhotoGridViewController` — 相簿特有逻辑（层级菜单、排序写回、覆盖层设置入口）

---

## 八、编码约定

- **Swift 5 + UIKit**，不使用 SwiftUI
- **无第三方依赖**，所有功能基于系统框架
- **数据与 UI 分离**：`PhotoGridSelectionState`、`PhotoNumberingLogic` 是纯数据/纯函数，不含 UIKit 引用
- **UserDefaults 持久化**：按相簿 localIdentifier 分键存储，加载/保存成对出现
- **批量持久化**：`beginBatchUpdates` / `endBatchUpdates` 合并写入，避免多次序列化整表
- **defer 模式**：批处理入口用 `beginBatchUpdates; defer { endBatchUpdates }` 确保成对调用
- **弱引用**：闭包中使用 `[weak self]` 避免循环引用

---

## 附录 A：UserDefaults 使用红线

### 核心原则

**UserDefaults.set(_:forKey:) 会序列化整个值并写入磁盘。** 对于 `[String: Int]` 这类字典，开销随字典大小线性增长（数万条目时约数十毫秒/次）。

### 禁止模式

```
// ❌ 循环内逐条写 UserDefaults
for asset in selected {
    setLevel(level, for: asset)         // 每次都 set(dict, forKey:) → O(n) 序列化
}
// 10000 条 × 每条约 50ms = 总计 ~500 秒
```

### 正确模式

1. **读一次 → 本地改 → 写一次**：
```swift
// ✅ 批量操作只写一次
var levels = service.levels(in: collection)   // 读取一次
for asset in selected {
    levels[asset.localIdentifier] = level     // 纯内存修改 O(1)
}
service.replaceAllLevels(levels, for: collection) // 写入一次
```

2. **合并写入**（关键路径不能避免逐条写时）：
```swift
// ✅ beginBatchUpdates / endBatchUpdates 包裹
service.beginBatchUpdates(for: collection)
defer { service.endBatchUpdates(for: collection) }
for ... { service.setLevel(...) } // 期间不落盘，结束写一次
```

### 本次分支的教训

批量下降层级的卡顿根因链：

```
onBatchDemoteLevel
  └─ for asset in selected          ← 10000 项
       └─ setLevel()                ← 每项 UserDefaults.set 序列化 25000 条目
            └─ levelsCache[key] = dict   ← Swift CoW 拷贝 25000 条目
└─ refreshParagraphDisplay
     └─ computeNumbers              ← O(d²) 字符串拼接
     └─ reloadData → configure      ← 每 cell 触发 PHImageManager 请求
```

四个瓶颈叠加后，单次操作卡顿数十秒。修复后整体耗时在毫秒级。

---

## 附录 B：UserDefaults 键值规范

### 全局键（不区分相簿）

| 键 | 类型 | 默认值 | 说明 | 服务 |
|------|------|------|------|------|
| `custom_photo_tags` | `[PhotoTag]` (JSON) | `[]` | 标签列表 | `PhotoTagService` |
| `overlay_display_enabled` | `Bool` | `true` | 覆盖层总开关 | `OverlayDisplaySettings` |
| `overlay_show_creation_in_custom` | `Bool` | `true` | 自定义排序下显示拍摄日期 | `OverlayDisplaySettings` |
| `overlay_show_modification_in_custom` | `Bool` | `true` | 自定义排序下显示修改日期 | `OverlayDisplaySettings` |
| `overlay_show_custom_order_in_date_sort` | `Bool` | `true` | 日期排序下显示序号 | `OverlayDisplaySettings` |
| `overlay_show_field_prefixes` | `Bool` | `true` | 显示 "C:" / "M:" / "#" 前缀 | `OverlayDisplaySettings` |
| `hierarchy_collapse_span_mode` | `Int` (rawValue) | `0` | 0=断无编号, 1=含间隙 | `HierarchyCollapseSettings` |

### 按相簿分键（`{id}` = PHAssetCollection.localIdentifier）

| 键模板 | 类型 | 说明 | 服务 |
|------|------|------|------|
| `photo_numbering_levels_{id}` | `[String: Int]` | assetID → 层级 | `PhotoNumberingService` |
| `photo_numbering_collapse_{id}` | `[String: Bool]` | assetID → 折叠状态 | `PhotoNumberingService` |
| `system_sort_preference_{id}` | `String` (rawValue) | 排序偏好 | `PhotoSortPreference` |
| `photo_hierarchy_nodes_{id}` | Codable Data | 段落/首图层级节点 | `PhotoHeaderService` |
| `header_photos_{id}` | `[String]` | 首图 assetID 列表 | `PhotoHeaderService` |
| `paragraph_collapse_{id}` | `[String: Bool]` | 段落折叠状态 | `PhotoHeaderService` |

### 按资源分键（`{assetID}` = PHAsset.localIdentifier）

| 键模板 | 类型 | 说明 | 位置 |
|------|------|------|------|
| `asset_original_loc_lat_{assetID}` | `Double` | 原始 GPS 纬度 | `AssetLocationAdjustmentViewController` |
| `asset_original_loc_lon_{assetID}` | `Double` | 原始 GPS 经度 | `AssetLocationAdjustmentViewController` |
