# HSPhotos 性能问题扫描报告

> 由三个子代理并行扫描生成：算法复杂度、内存/缓存、UI 渲染/磁盘 I/O
> 扫描日期：2026-06-13

---

## 🔴 高优先级（HIGH）

### H1. 滑动选择手势每项触发 O(k) 重新编号

**文件：** `PhotoGridView.swift:677-687`
**分类：** 算法 — 滑动选择循环内逐项 toggle 导致 O(range × selectedCount)

```swift
// 当前代码：每次 .changed 事件内
for i in rangeStart...rangeEnd {
    rankChangedAccumulator.formUnion(toggle(photo: asset))  // ← 每项调用 toggle
}
// toggle → PhotoGridSelectionState.toggle(id:) → 移除后全量重新编号 (O(k))
```

**根因：** `toggle(photo:)` 内部调用 `PhotoGridSelectionState.toggle(id:)`，该方法在取消选中时遍历全部 `orderedIDCache` 重新分配 rank。滑动选择跨越数百项时，每项都执行一次 O(k) 的重新编号，总复杂度 O(range × selectedCount)。

**建议修复：** 借鉴 `selectRange(from:to:reverse:)` 的做法——按顺序批量收集要 toggle 的 ID，一次性追加/移除，避免逐项重新编号。或者将 rank 改为惰性计算（`enumerated()`），不维护 `rankByID` 字典。

**影响：** 滑动选择时帧率下降，在选中数千张照片后尤其明显。

---

### H2. `selectedPhotos` 计算属性每次访问分配新数组

**文件：** `PhotoGridView.swift:272-290`
**分类：** 内存 — 滑动选择期间每秒分配数十次完整选中数组

```swift
private var selectedPhotos: [PHAsset] {
    // ...每次访问都新建 [PHAsset] 数组并填充
    var result: [PHAsset] = []
    result.reserveCapacity(selectionState.count)
    for id in selectionState.orderedIDs { result.append(asset) }
    return result
}
```

**根因：** 每次 `.changed` 事件（60fps）都调用 `delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)`，而 `selectedAssetsForDelegateNotification` 内部访问 `selectedPhotos`，每次分配新数组。数组立即被丢弃（>512 项时返回空）。

**建议修复：** 先检查 `selectedAssetCount > maxSelectedAssetsInDelegatePayload`，若超过则直接返回 `[]`，完全跳过 `selectedPhotos` 计算。对于 ≤512 的情况，缓存结果并在 selection state 变化时失效。

**影响：** 滑动选择期间 GC 压力；选中数千张照片时每帧分配 ~80KB 的临时数组。

---

### H3. 三重冗余图片缓存消耗 150-200MB 重复数据

**文件：** `PhotoCell.swift:200-227` + `BaseAlbumCell.swift:12-52`
**分类：** 内存 — 三个独立缓存存储相同的缩略图数据

| 缓存层 | 容量限制 | 用途 |
|--------|---------|------|
| `PHCachingImageManager`（系统） | 自动 LRU | 所有 PHAsset 缩略图 |
| `PhotoCell.imageCache`（NSCache） | 200MB / 500 条 | 照片网格缩略图 |
| `ImageCache.shared`（NSCache） | 100MB / 200 条 | 相簿封面缩略图 |

**根因：** PHCachingImageManager 已经是 iOS 为照片缩略图优化的系统级 LRU 缓存，集成了内存压力响应。应用层额外维护的两个 NSCache 存储的是完全相同的图片数据，造成 ~150-200MB 的重复内存占用。

**建议修复：**
- 移除 `PhotoCell.imageCache`（第 222-227 行），仅依赖 `PHCachingImageManager`
- 移除 `ImageCache.shared`（`BaseAlbumCell.swift` 第 12-52 行），相簿缩略图也用 `PHCachingImageManager`
- 若需要离线/自定义场景的应用层缓存，用一个 50MB/100 条的统一 NSCache 代替

**影响：** 重度滚动浏览照片后峰值内存多占用 ~150-200MB，可能触发 jetsam。

---

### H4. 5 份并行的 ID 索引字典

**文件：** `PhotoGridView.swift:110-174`
**分类：** 内存 — 大规模字符串重复存储

```swift
private var assets: [PHAsset] = []          // PHAsset 对象数组
private var visibleAssets: [PHAsset] = []   // 可见子集（通常 === assets）
private var assetIDs: [String] = []         // 全部 ID（从 PHAsset 中已含 localIdentifier）
private var visibleAssetIDs: [String] = []  // 可见 ID
private var assetByID: [String: PHAsset] = [:]         // ID → asset
private var assetIndexByID: [String: Int] = [:]        // ID → 全部索引
private var visibleAssetIndexByID: [String: Int] = [:] // ID → 可见索引
```

**根因：** 50,000 张照片时，每个 String 键在每份字典中重复存储（每个 ~250 字节），5 份字典共占用 ~60-80MB 字符串冗余。

**建议修复：**
- `assetIDs` 和 `visibleAssetIDs` 改为惰性计算（需要时 `map(\.localIdentifier)`）
- `visibleAssetIndexByID` 可以从 `assetIndexByID` + 可见性偏移表推导，不必独立存储
- 考虑用 `[PHAsset]` + 单个 `[Int]` 偏移映射代替多个字典

**影响：** 大相簿（50K+）内存占用多 60-80MB。

---

### H5. 全量资产的急切日期格式化

**文件：** `PhotoGridView.swift:1187-1196`
**分类：** 内存 + 主线程 — 对所有资产预格式化日期字符串

```swift
private func preloadDateTextCache() {
    for asset in assets {  // ← 遍历全部 assets（非 visible），5 万项
        let creation = Self.displayDateFormatter.string(from: ...)
        let modification = Self.displayDateFormatter.string(from: ...)
        dict[asset.localIdentifier] = (creation, modification)
    }
    dateTextCache = dict
}
```

**根因：** 创建 100K 个日期字符串（每 asset 两个），`DateFormatter.string(from:)` 本身开销也不低。对 5 万项大约阻塞主线程 200-500ms。

**建议修复：** 移除整表预加载，改为惰性格式化——`cellForItemAt` 中仅在覆盖层设置启用日期显示时才格式化。或用 `updateVisibleCells` 类似方式批量预计算可见 cells 的日期。

**影响：** 进入大相簿时主线程卡顿 200-500ms。

---

### H6. 层级缓存预热忽略 visible 参数，总是处理全部资产

**文件：** `PhotoGridView.swift:1199-1214`
**分类：** 内存 + CPU — 方法接受 `visible` 参数但不使用

```swift
private func prewarmHierarchyCache(for visible: [PHAsset]) {
    // visible 参数被忽略！始终用 self.assets（全部）
    let (numbers, collapsed) = numberingService.computeNumbersAndCollapsed(for: assets, in: collection)
    for asset in assets { ... }
}
```

**根因：** 方法签名暗示只预热可见部分，但实际用 `self.assets`（全量）。`computeNumbersAndCollapsed` 是 O(n) 的字符串操作，5 万项输出 5 万个编号字符串的字典（~5-10MB）。

**建议修复：** 尊重 `visible` 参数，只计算可见资产的层级信息。非可见资产的编号在它们变为可见时惰性填入。

**影响：** 每次可见集变化都重新计算全部资产的编号，时间和内存双重浪费。

---

### H7. 打开查看器时同步 PHImageRequest 阻塞主线程

**文件：** `BasePhotoViewController.swift:1718-1724` + `GalleryViewController.swift:147-154`
**分类：** UI 渲染 — 主线程阻塞

```swift
let options = PHImageRequestOptions()
options.isSynchronous = true          // ← 主线程同步等待！
options.deliveryMode = .highQualityFormat
PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), ...) { image, _ in
    sourceImage = image
}
// 紧接着 present(viewerNav, animated: true)
```

**根因：** 同步 + `.highQualityFormat` 组合。iCloud 照片需要网络下载时，主线程阻塞数秒。

**建议修复：** 去掉 `isSynchronous = true`，在 completion 闭包中执行 `present(viewerNav)`. 降级方案：先传 cell 的已显示缩略图作为转场占位图，查看器内部异步加载全尺寸。

**影响：** 点击照片打开查看器时有可感知的延迟（10-200ms+），iCloud 照片更严重。

---

### H8. 不必要的 `reloadData()` 替代针对性更新

**文件：** `PhotoGridView.swift:160, 452, 1033, 1057, 1183`
**分类：** UI 渲染 — 全量重载触发新 PHImageRequest

```swift
// 场景 1: 覆盖层设置变化 → 只需要刷新文本 → 但用了 reloadData()
// Line 452 附近
collectionView.reloadData()

// 场景 2: 层级编号不变但可见集相同 → 本可以跳过 → 却 reloadData()
// Line 1033
UIView.performWithoutAnimation {
    collectionView.reloadData()
}

// 场景 3: 可见集变了 → 应 diff → 却 reloadData()
// Line 1057
collectionView.reloadData()
```

**根因：** `reloadData()` 触发所有可见 cell 的 `configure()`，每个 cell 重新发起 `PHImageManager.requestImage`。一次不必要的 `reloadData()` 触发数百个图片请求。

**建议修复：**
- Line 452：遍历 `visibleCells` 就地更新覆盖层文本（类似 `refreshHierarchyNumbersOnly()` 的模式）
- Line 1033：当 visibleAssets 相同时，如果只需要刷新层级编号，直接跳过 `reloadData()`
- Line 1057：对可见集变化应用 diff-based batch update（`performBatchUpdates`）

**影响：** 每次触发时大量无意义的图片请求，滚动帧率下降。

---

## 🟡 中优先级（MEDIUM）

### M1. `PhotoGridSelectionState.toggle(id:)` 每次取消选中都全部重新编号

**文件：** `PhotoGridSelectionState.swift:64-83`
**分类：** 算法 — O(k) 每次取消选中

```swift
} else {
    rankByID.removeValue(forKey: id)
    orderedIDCache.removeAll { $0 == id }
    for (index, other) in orderedIDCache.enumerated() {
        let newRank = index + 1
        rankByID[other] = newRank       // ← 所有后续项重新编号
    }
}
```

**建议修复：** 改为惰性 rank 计算。`rankByID` 仅作为 `Dictionary(uniqueKeysWithValues: orderedIDCache.enumerated().map { ($1, $0+1) })` 在需要时构建。

**影响：** 与 H1（滑动选择 toggle 循环）叠加时加剧卡顿。

---

### M2. `PhotoHeaderService` 循环内 `contains(where:)` — O(n×h)

**文件：** `PhotoHeaderService.swift:138-139, 184-185`
**分类：** 算法 — 段落计算中的 O(n×h) 查找

```swift
for asset in assets {
    if headerAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
```

**建议修复：** 预先构建 `Set(headerAssets.map(\.localIdentifier))` 实现 O(1) 查找。

**影响：** 段落首图较多时（>10 个），滚动或重新计算时有可感知延迟。

---

### M3. `PhotoHierarchyService.saveNodes()` 主线程编码并写入整个树

**文件：** `PhotoHeaderService.swift:1249-1260`
**分类：** 磁盘 I/O — 主线程序列化 + UserDefaults 写入

```swift
let data = try JSONEncoder().encode(nodes)     // 主线程编码
UserDefaults.standard.set(data, forKey: key)    // 主线程写入
```

**建议修复：** 仿照 `PhotoNumberingService.saveForCollection()` 的做法，dispatch 到 `.utility` 队列。

**影响：** 大量节点的编码耗时 10-50ms，每次修改段落层级时主线程卡顿。

---

### M4. `PhotoRecognitionService` NSCache 无限增长

**文件：** `PhotoRecognitionService.swift:23`
**分类：** 内存 — 未设 countLimit/totalCostLimit

```swift
private let classificationCache = NSCache<NSString, CachedLabels>()
// 无 countLimit，无 totalCostLimit → 无限增长直到内存警告
```

**建议修复：** 设 `countLimit = 500`、`totalCostLimit = 5MB`。Vision 标签重新计算便宜，激进淘汰可接受。

---

### M5. 标签每次变更全量 JSON 序列化

**文件：** `PhotoTagService.swift:36-40`
**分类：** 磁盘 I/O — 主线程编码整个标签数组

```swift
private func saveTags(_ tags: [PhotoTag]) {
    guard let data = try? JSONEncoder().encode(tags) else { return }
    UserDefaults.standard.set(data, forKey: tagsKey)          // 主线程
}
```

**建议修复：** 防抖写入（1-2 秒延迟）+ 编码 dispatch 到后台队列。或改为每个标签独立 key 的增量存储。

**影响：** 100 个标签各含 1000 个 asset ID 时，JSON 体积 3-5MB。

---

### M6. 上下文菜单 closure 强引用 `[self]`

**文件：** `PhotoGridView.swift:1712`
**分类：** 内存 — 潜在循环引用链

```swift
return UIContextMenuConfiguration(...) { [self] _ in   // ← 强引用
    let action = UIAction(...) { [weak self] _ in ... } // ← 内层 weak, 外层 strong
```

**建议修复：** 外层也改为 `[weak self]`，加 `guard let self` 提前返回。

**影响：** 延迟菜单元素（`UIDeferredMenuElement`）延长了生命周期；若菜单未解析即离开页面，`PhotoGridView` 泄漏。

---

### M7. 热路径循环缺少 `autoreleasepool`

**文件：** `PhotoGridView.swift:677-687, 1187-1196, 1199-1214`
**分类：** 内存 — 大循环中临时对象不释放

**建议修复：** 处理数千项的循环内加 `autoreleasepool { }`。

**影响：** 滑动选择/预加载时临时对象堆积（5-10MB 暂态内存峰值）。

---

### M8. 每次可见集更新做 O(n) 全量相等性检查

**文件：** `PhotoGridView.swift:1022-1023`
**分类：** CPU — 每次调用都全量比较

```swift
let unchanged = newVisibleAssets.count == visibleAssets.count
    && newVisibleAssets.elementsEqual(visibleAssets, by: { $0.localIdentifier == $1.localIdentifier })
```

**建议修复：** 维护一个 generation counter 或 ID 集合的 hash。先 O(1) 比较 hash，仅匹配时才回退到 O(n) 逐项比较。

**影响：** 绝大多数调用时 visibleAssets 实际发生了变化，O(n) 检测是浪费。

---

### M9. `UIVisualEffectView` + `cornerRadius` 离屏渲染

**文件：** `SearchBarView.swift:33-38`
**分类：** UI 渲染 — 搜索栏始终离屏渲染

```swift
blurView.layer.cornerRadius = 10
blurView.clipsToBounds = true
```

**建议修复：** 将 `cornerRadius` 和 `clipsToBounds` 仅设在最外层 `backgroundView`，内层 `blurView` 不做裁剪。

---

### M10. Pinch 缩放手势每帧触发完整 layout 变更 + reloadData

**文件：** `PhotoGridView.swift:582-591`
**分类：** UI 渲染 — 连续手势期间多次全量重载

**建议修复：** 仅在 `.ended` 状态应用列数变更，或加 0.3s 冷却期。

---

### M11. BaseAlbumCell 阴影无 `shadowPath`

**文件：** `BaseAlbumCell.swift:85-89`
**分类：** UI 渲染 — 每帧触发离屏渲染

```swift
contentView.layer.shadowColor = UIColor.black.cgColor
contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
contentView.layer.shadowRadius = 6
contentView.layer.shadowOpacity = 0.12
// 缺少 shadowPath → Core Animation 每帧光栅化计算阴影形状
```

**建议修复：** 加 `shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath`，在 `layoutSubviews` 中更新。

---

### M12. `PhotoCell.layoutSubviews()` 每次都重新测量文本

**文件：** `PhotoCell.swift:561-566, 362-388`
**分类：** UI 渲染 — 每次 bounds 变化都调用 `sizeThatFits`

**建议修复：** 缓存上次的文本字符串，仅当文本实际变化时才重新测量。

---

## 🟢 低优先级（LOW）

| # | 文件 | 行号 | 问题 | 分类 |
|---|------|------|------|------|
| L1 | `PhotoNumberingService.swift` | 多处 | 链式调用中重复 `map(\.localIdentifier)` 分配 ID 数组 | 内存 |
| L2 | `BasePhotoViewController.swift:1707,1771` | — | `firstIndex(of:)` O(n) 查找（用户点击/open 时） | 算法 |
| L3 | `BasePhotoViewController.swift:1380` | — | `getPreviousLevel` 的 `firstIndex(of:)` 回退路径 | 算法 |
| L4 | `PhotoCollectionStore.swift:69-71` | — | `orderedAssets(for:)` 在批量操作中冗余调用 | 算法 |
| L5 | `PhotoTagService.swift:100-102` | — | `tags(forAsset:)` O(t×a) 无反向索引 | 算法 |
| L6 | `PhotoChangesService.swift:206-274` | — | `duplicate` 串行 semaphore 阻塞 | I/O |
| L7 | `PhotoHeaderService.swift:211-223` | — | 逐条 `PHAsset.fetchAssets` 而非批量取回 | I/O |
| L8 | `PhotoGridView.swift:527-553` | — | 急切的上下文菜单资源预热（静态缓存 13 个 SF Symbol） | 内存 |
| L9 | `PhotoCell.swift:434-439` | — | 取消图片请求后才检查是否是同一 asset | CPU |
| L10 | `PhotoCollectionStore.swift:74-109` | — | 仅排序变化也完全重建 snapshot | 内存 |
| L11 | `PhotoTagService+PhotoHeaderService` | 多处 | 每次调用新建 `JSONEncoder()`/`JSONDecoder()` 实例 | CPU |
| L12 | `PhotoNumberingService.swift:87-90` | — | 非批处理路径每次变更立即写 UserDefaults（设计注解） | I/O |
| L13 | `BaseAlbumCell.swift` | 85-89 | 阴影 + `cornerRadius` 缺少 `shadowPath` | UI |

---

## 已做好的模式

以下模式值得保留并推广：

1. **`refreshHierarchyNumbersOnly()`** — 就地更新 cell label 而非 reloadData
2. **Diff-based batch updates** — `applyVisibleAssetsChangeAnimated` 用 insert/delete/reload diff
3. **`PHCachingImageManager` + `prefetchDataSource`** — 标准 iOS 平滑滚动方案
4. **懒加载子视图** — `installOverlaysIfNeeded` / `installLabelsIfNeeded`
5. **compact 模式** — `columns >= 7` 时跳过 label 设置
6. **批量持久化** — `beginBatchUpdates`/`endBatchUpdates` 合并 UserDefaults 写入
7. **后台 dispatch** — `loadPhoto()` 和排序变更是后台执行

---

## 修复优先级建议

**第一轮（高收益/低风险）：**
1. H2 — `selectedPhotos` 提前返回（一行 guard）
2. M1 — `toggle(id:)` 惰性 rank（简化 PhotoGridSelectionState）
3. M6 — context menu `[weak self]`（改一个字符）

**第二轮（高收益/中风险）：**
4. H1 — 滑动选择批量 toggle（重构 `.changed` handler）
5. H7 — 异步查看器源图请求
6. H5 + H6 — 急切预加载改为惰性/按需

**第三轮（中收益/高收益但有回归风险）：**
7. H3 — 移除冗余图片缓存（回归风险：没有 PHCachingImageManager 未覆盖场景？）
8. H4 — 合并 ID 索引字典（涉及多处调用方）
9. H8 — 减少不必要的 `reloadData()` 调用
