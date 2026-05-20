# HSPhotos 架构约定（UIKit / Apple MVC）

本项目是 **iOS + UIKit** 应用，架构以 [Apple 的 Model-View-Controller](https://developer.apple.com/documentation/uikit/view_controllers) 为主线，而不是 Web 或后端常用的 Domain / UseCase / Infrastructure 分层。

核心原则（与 Apple 文档一致）：

- **Model**：数据与业务规则，不依赖 UIKit。
- **View**：展示与用户输入（`UIView` / `UICollectionView` 等），尽量不写业务规则。
- **Controller（`UIViewController`）**：协调 Model 与 View，处理生命周期、导航、弹窗、菜单；保持「协调者」角色，避免把 Photos 写库散落在各个 VC 里。

系统能力（`Photos`、`UserDefaults`）由 **Service / Manager** 封装——命名与 Apple Sample Code 习惯一致，不叫 Infrastructure / Repository。

---

## 推荐结构（Apple 视角）

```
┌─────────────────────────────────────────────────────────┐
│  Controller（UIViewController + 可选 Coordinator）       │
│  生命周期、导航、UIMenu、绑定 View、响应用户操作              │
└───────────────┬─────────────────────┬───────────────────┘
                │                     │
        ┌───────▼────────┐    ┌───────▼────────┐
        │  View          │    │  Model 状态     │
        │  纯 UI / 手势   │    │  + Services    │
        └────────────────┘    └───────┬────────┘
                                      │
                              Photos.framework 等
```

### Model

| 类型 | 职责 | 本项目中的类型 |
|------|------|----------------|
| 值类型 / 模型 | 列表项、标签、排序枚举 | `AlbumListItem`、`PhotoTag`、`PhotoSortPreference` |
| 编辑状态（相簿页） | 成员顺序、筛选、层级编号、可见行 | `AlbumSession`（**不是** DDD 的 Domain 层，而是 **相簿页的 Model 状态对象**） |
| 列表数据准备 | `PHFetch`、展开树、排序 | `AlbumListQuery`（由 `AlbumListViewModel` 封装） |

`AlbumSession` 只持有数据与计算，**禁止** `UIKit`、`performChanges`。

### View

- `PhotoGridView`、`AlbumListView`、各类 `Cell`：布局、手势、根据 Controller 提供的快照渲染。
- **禁止** 写 `memberAssets`、**禁止** `performChanges`。

### Controller

- `BasePhotoViewController` / `AlbumListViewController`：协调 Session、Service、View。
- 菜单结构由 `AlbumGridMenuBuilder` 生成（纯 `UIMenu`，无业务副作用），VC 提供 `state` 与 `actions`——符合「View 相关展示逻辑外置、VC 只接线」。
- 导航：`AlbumListRouter`（Coordinator 的一种轻量实现），避免 VC 里堆满 `push`/`dismiss` 细节。

### Services（系统与持久化）

| Service | 职责 |
|---------|------|
| `PhotoChangesService`（+Collections / +AssetMetadata） | **唯一** `PHPhotoLibrary.performChanges` 入口 |
| `PhotoNumberingService` | 层级编号持久化 |
| `PhotoTagService` | 标签持久化（UserDefaults） |
| `PhotoPermissionManager` | 权限 |
| `PhotoAlbumOperations`（别名 `PhotoAlbumEditingService`） | 相簿内写库门面 |
| `AlbumCollectionOperations`（别名 `AlbumCollectionEditingService`） | 列表写库门面 |
| `PhotoTagOperations`（别名 `PhotoTagFacade`） | 标签门面，内部用 `PhotoTagService` |

新代码优先：**Controller → ViewModel → Service 门面 → PhotoChangesService**。

### Coordinator（导航）

| Router | 屏幕 |
|--------|------|
| `AlbumListRouter` | 相册列表 → 网格 / 子文件夹 / Picker |
| `PhotoGridRouter` | 网格 → 大图、标签、加图 Picker、添加到相簿、分享 |

---

## 相簿网格页数据流（MVC）

1. 加载 / 写库成功 → 更新 `AlbumSession.memberAssets` → `refreshGridFromSession()`。
2. 改筛选 / 排序 → 只改 `session` → `refreshGridFromSession()`。
3. 改层级 → `session` 层级 API → `gridView.refreshParagraphDisplay()`。

Controller 不维护第二份全量 `memberAssets`（见 R3）。

---

## 相册列表页（MVC）

| 角色 | 类型 |
|------|------|
| ViewModel | `AlbumListViewModel`（读模型 + 展开状态，`onDidUpdate` 通知 VC） |
| Model / 数据 | `AlbumListQuery`（内部）、`AlbumCollectionOperations`（写） |
| View | `AlbumListView` |
| Controller | `AlbumListViewController`（绑定 ViewModel、Router、写库结果） |
| 导航 | `AlbumListRouter` |

---

## 与「Web 式分层」的对照（仅供迁移理解）

| 曾用说法 | Apple / UIKit 说法 |
|----------|-------------------|
| Domain | **Model**（`AlbumSession`） |
| UseCase | **Service 门面**（`*Operations`） |
| Infrastructure | **Service**（`PhotoChangesService` 等） |
| Query / Presenter | **Model 侧数据准备**（`AlbumListQuery`，或未来的 ViewModel） |
| Router | **Coordinator**（`AlbumListRouter`） |

后续重构优先用 **Model / View / Controller / Service**，不再引入 Domain、UseCase、Infrastructure 目录名。

---

## 禁止清单（PR / CI）

| 规则 | 说明 |
|------|------|
| R1 | `Controllers/`、`Views/` 中不得 `performChanges` |
| R2 | UI 不得直连 `PhotoNumberingService.shared`（经 `AlbumSession`） |
| R3 | 除 `session.memberAssets` 外不得维护全份成员列表 |
| R4 | `PhotoGridView` 不得写入 `memberAssets` |
| R5 | 新写库：`PhotoChangesService` → Service 门面 → Controller |
| R6 | UI 不得直连 `PhotoTagService.shared`（经 `PhotoTagOperations`） |

仅 `PhotoChangesService` 及其 extension 可调用 `performChanges`。

---

## 子类 override（Swift 限制）

以下保留在 `BasePhotoViewController.swift` 主类（extension 内不能 `override`）：

- `sortDescriptors(for:)`
- `createSortMenu()` / `createOperationMenu()`
- `onChanged(sort:)`
- `updateNavigationBar()` / `updateSelectAllButton()`
- `refreshSortUIAfterPasteIfNeeded()`

---

## 目录（按 Apple 角色，非 Web 分层）

| 路径 | 角色 |
|------|------|
| `HSPhotos/Models/` | Model 类型、`AlbumSession`（相簿网格页状态） |
| `HSPhotos/ViewModels/` | `AlbumListViewModel`、`PhotoGridViewModel` |
| `HSPhotos/Services/` | Service、Photos 写库、`AlbumListQuery`、菜单构建 |
| `HSPhotos/Controllers/` | Controller、`AlbumListRouter`、`PhotoGridRouter` |
| `HSPhotos/Views/` | View |

---

## 迁移路线（已排期）

| 阶段 | 内容 | 状态 |
|------|------|------|
| 1 | `AlbumSession` 迁入 `Models/`，删除 `Domain/` | ✅ 已完成 |
| 2 | 列表页 `AlbumListViewModel` + VC 只绑定 | ✅ 已完成 |
| 3 | 相簿网格 `PhotoGridViewModel`（包装 `AlbumSession`，VC 变薄） | ✅ 已完成 |
| 4 | Service 门面类型别名（`*EditingService` / `PhotoTagFacade`） | ✅ 已完成 |
| 5 | `PhotoGridRouter`（网格页 present / push） | ✅ 已完成 |

本地检查：`./scripts/check-architecture.sh`

---

## 相簿网格页（MVVM）

| 角色 | 类型 |
|------|------|
| Model | `AlbumSession`（`Models/`） |
| ViewModel | `PhotoGridViewModel`（成员/筛选变更 → `onGridNeedsRefresh`） |
| Controller | `BasePhotoViewController` / `PhotoGridViewController` |
| View | `PhotoGridView`（`bind(to: session)`，只读展示） |

`BasePhotoViewController` 通过 `viewModel` 改数据；`session` 保留为只读访问 Model（层级 API、网格绑定）。
