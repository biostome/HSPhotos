# HSPhotos 修改日志

## 2026-03-20

### 大图浏览器 · 底栏可点

- **`UIPageViewController` 布局**：分页容器底边在缩略条就绪后改为约束到 **`thumbnailStripView.topAnchor`**（留小间距），避免内部 `UIScrollView` 在几何上铺满屏底抢走底栏/胶囊按钮触摸；移除自定义根视图 `hitTest` 绕行。
- **`bottomChromeContainer` 高度**：为底栏容器增加与 **`sideControlSide`** 相等的固定高度；原先仅靠无固有高度的 spacer 撑满上下，容器可被压成 0pt，导致子按钮落在父 bounds 外、系统不向下命中。

### 大图浏览器 · 照片信息

- **Sheet 弹窗**：工具栏「信息」与顶栏标题入口改为与「添加标签」相同的 **`UISheetPresentationController`**（`.medium()` / `.large()`、`prefersGrabberVisible`），由 `PhotoAssetInfoSheetViewController` 展示。
- **完整元数据**：在同页按板块列出 Photos 可读信息——`localIdentifier`、媒体大类 / **`PHAsset.PlaybackStyle`** / 来源 / 全部适用的 **`PHAssetMediaSubtype`**、像素与 MP、音视频时长、创建与修改时间、嵌入 **GPS**（经纬度、海拔、精度、时间）、连拍相关、收藏 / 隐藏 / 调整 / **`canPerform`**，以及 **`PHAssetResource`** 逐条（类型、原始文件名、UTI）。
- **系统相册式界面**：**`UITableView` inset 分组** + **`UIListContentConfiguration.valueCell` 纵向堆叠**（小写标题 + 正文值、等宽字体用于标识符）；标题行使用较大 **`semibold` 20pt**；有 GPS 时在 **`tableHeaderView`** 展示 **`MKMapView`（`mutedStandard`）**、底部渐变叠字、**反向地理编码** 地点文案、**「在地图中查看」** 与 **点按地图** 跳转 **`MKMapItem.openInMaps`**。
- **信息面板 UI（对齐 HIG）**：去掉地图 **重阴影 / 渐变叠白字 / 字阴影**，改为 **`systemChromeMaterial` 底栏** + **`label` 色正文**；地图外框 **`secondarySystemGroupedBackground` + 10pt 连续圆角** 与 inset 分组一致；跳转改为 **plain + `arrow.up.right.square`**；**标题 Title3**、抓取条回到 **`separator`**；分组头恢复 **系统默认 footnote**（无每段 SF Symbol）；列表 **Subheadline + Body** 的 **valueCell**，短字段 **左右排列**、长文/多行/等宽 **自动纵向堆叠**；**layoutMargins** 统一约 **20**。

### 大图浏览器 · 单页媒体（`PhotoPageViewController`）

- **iCloud / 慢加载**：大图请求在需要云端拉取时显示加载指示与文案；视频在较慢时延迟显示「正在载入视频…」，避免本地秒开闪一下。
- **视频清晰度**：`PHVideoRequestOptions.deliveryMode` 使用 **`.highQualityFormat`**（`.fastFormat` 易得到低码率变体、全屏发糊）。

### 大图浏览器 · 底部缩略条（`GalleryViewerThumbnailStripView` 等）

- **点击缩略图**：条滚到居中；已选中再点同一格不再重复滚动（防竞态与重复 `syncSelection`）。
- **滑大图**：缩略条与当前页对齐；**程序滚动**与**用户拖条**分两路：`scrollViewDidScroll` 仅在用户 **拖动/减速** 时按视口中心改选中，避免程序 `scrollToItem` 后的 `didScroll` 把选中改错。
- **重构**：用 `isProgrammaticAlignmentActive` + **`alignmentGeneration`** 管理「程序对齐」生命周期；用户拖条时 `userInterruptedProgrammaticAlignment()` 作废未完成回调；去掉 `immediateScroll` 双路径，统一先 `reloadItems` 再 `scrollToItem`；程序带动画时用 **延迟 + gen 校验** 解锁（替代不可靠的连续 `scrollToItem` 与 `didEndScrollingAnimation` 一一对应）。

---

## 2026-03-19

### 📸 照片多级编号

- **主级 / 子级编号**：在相册内可为照片设置编号（如 1、1.1、2.1），类似 Word 多级列表
- **折叠**：主级照片可折叠，隐藏其下子级
- **操作**：设为主级、设为子级、取消编号、折叠 / 展开
- **使用范围**：层级功能仅在**相册内**可用，首页（图库）不显示编号和相关菜单

### 🗑️ 长按删除

- **长按照片**即可删除，无需先进入选择模式
- 菜单顺序优化：添加标签 → 粘贴到此后方 → 删除（危险操作放最后）

### 🎯 层级菜单优化

- 未设置层级编号的照片不再显示「取消编号」选项，菜单更简洁

### 🔧 删除与撤销

- **首页（图库）删除**：照片移至「最近删除」，可到系统相册中恢复
- **相册内删除**：从相册中移除（照片仍在库中），支持**撤销**恢复
- 删除失败时不再出现列表已更新但提示失败的情况

### ⚡ 性能与体验

- 滚动时不再卡顿，层级编号显示流畅
- 应用使用过程中减少磁盘读写，响应更快

---

*如有问题或建议，欢迎反馈。*
