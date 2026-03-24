//
//  PhotoAssetInfoSheetViewController.swift
//  HSPhotos
//
//  大图浏览器内展示单张资产元数据：布局参考系统「照片」信息面板（分组列表 + 地图）。
//

import CoreLocation
import MapKit
import Photos
import UIKit

// MARK: - 数据模型

fileprivate struct PhotoInfoSection {
    let title: String
    let rows: [PhotoInfoRow]
}

fileprivate struct PhotoInfoRow {
    let name: String
    let value: String
    var monospaceValue: Bool = false
}

// MARK: - 顶部地图（HIG：静音地图 + 系统材质底栏，与 inset 分组圆角一致）

private final class AssetLocationMapHeaderView: UIView, MKMapViewDelegate {

    private let mapContainer = UIView()
    private let mapView = MKMapView()
    private let bottomMaterial = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let placeRow = UIStackView()
    private let geocodeSpinner = UIActivityIndicatorView(style: .medium)
    private let placeLabel = UILabel()
    private let mapsButton = UIButton(type: .system)
    private let coordinate: CLLocationCoordinate2D
    private let location: CLLocation
    private var geocodeToken = UUID()
    private var reverseGeocodeRequest: MKReverseGeocodingRequest?

    init(location: CLLocation) {
        self.location = location
        self.coordinate = location.coordinate
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false

        mapContainer.translatesAutoresizingMaskIntoConstraints = false
        mapContainer.backgroundColor = .secondarySystemGroupedBackground
        mapContainer.layer.cornerCurve = .continuous
        mapContainer.layer.cornerRadius = 10
        mapContainer.clipsToBounds = true

        bottomMaterial.translatesAutoresizingMaskIntoConstraints = false

        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
        mapView.setRegion(region, animated: false)
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        mapView.addAnnotation(pin)

        placeRow.axis = .horizontal
        placeRow.alignment = .center
        placeRow.spacing = 8
        placeRow.isUserInteractionEnabled = false
        placeRow.translatesAutoresizingMaskIntoConstraints = false

        geocodeSpinner.translatesAutoresizingMaskIntoConstraints = false
        geocodeSpinner.hidesWhenStopped = true
        geocodeSpinner.startAnimating()

        placeLabel.translatesAutoresizingMaskIntoConstraints = false
        placeLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        placeLabel.adjustsFontForContentSizeCategory = true
        placeLabel.textColor = .label
        placeLabel.numberOfLines = 2
        placeLabel.textAlignment = .natural
        placeLabel.text = "正在解析地点…"

        placeRow.addArrangedSubview(geocodeSpinner)
        placeRow.addArrangedSubview(placeLabel)

        var btnCfg = UIButton.Configuration.plain()
        btnCfg.title = "在地图中打开"
        btnCfg.image = UIImage(systemName: "arrow.up.right.square")
        btnCfg.imagePlacement = .trailing
        btnCfg.imagePadding = 5
        let sub = UIFont.preferredFont(forTextStyle: .subheadline)
        btnCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: UIFont.systemFont(ofSize: sub.pointSize, weight: .regular))
            return out
        }
        btnCfg.baseForegroundColor = .tintColor
        mapsButton.configuration = btnCfg
        mapsButton.translatesAutoresizingMaskIntoConstraints = false
        mapsButton.addAction(UIAction { [weak self] _ in self?.openInMaps() }, for: .touchUpInside)

        let mapTap = UITapGestureRecognizer(target: self, action: #selector(mapTapped))
        mapTap.numberOfTapsRequired = 1
        mapView.addGestureRecognizer(mapTap)

        addSubview(mapContainer)
        mapContainer.addSubview(mapView)
        mapContainer.addSubview(bottomMaterial)
        bottomMaterial.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        bottomMaterial.contentView.addSubview(placeRow)
        addSubview(mapsButton)

        let inset: CGFloat = 20
        NSLayoutConstraint.activate([
            mapContainer.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            mapContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            mapContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),

            mapView.topAnchor.constraint(equalTo: mapContainer.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapContainer.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapContainer.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapContainer.bottomAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 192),

            bottomMaterial.leadingAnchor.constraint(equalTo: mapContainer.leadingAnchor),
            bottomMaterial.trailingAnchor.constraint(equalTo: mapContainer.trailingAnchor),
            bottomMaterial.bottomAnchor.constraint(equalTo: mapContainer.bottomAnchor),
            bottomMaterial.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            placeRow.leadingAnchor.constraint(equalTo: bottomMaterial.contentView.layoutMarginsGuide.leadingAnchor, constant: 4),
            placeRow.trailingAnchor.constraint(equalTo: bottomMaterial.contentView.layoutMarginsGuide.trailingAnchor, constant: -4),
            placeRow.topAnchor.constraint(equalTo: bottomMaterial.contentView.layoutMarginsGuide.topAnchor, constant: 6),
            placeRow.bottomAnchor.constraint(equalTo: bottomMaterial.contentView.layoutMarginsGuide.bottomAnchor, constant: -6),

            mapsButton.topAnchor.constraint(equalTo: mapContainer.bottomAnchor, constant: 10),
            mapsButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            mapsButton.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: inset),
            mapsButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -inset),
            mapsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        startReverseGeocode()
    }

    deinit {
        reverseGeocodeRequest?.cancel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func mapTapped() {
        openInMaps()
    }

    private func startReverseGeocode() {
        let token = UUID()
        geocodeToken = token
        guard let request = MKReverseGeocodingRequest(location: location) else {
            geocodeSpinner.stopAnimating()
            placeLabel.text = "无法解析地点名称"
            return
        }
        reverseGeocodeRequest = request
        request.getMapItems { [weak self] mapItems, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.geocodeToken == token else { return }
                self.geocodeSpinner.stopAnimating()
                guard let item = mapItems?.first else {
                    self.placeLabel.text = "无法解析地点名称"
                    return
                }
                self.placeLabel.text = Self.formatMapItem(item)
            }
        }
    }

    private static func formatMapItem(_ item: MKMapItem) -> String {
        var parts: [String] = []
        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            parts.append(name)
        }
        if let address = item.address?.shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            parts.append(address)
        } else if let fullAddress = item.address?.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines), !fullAddress.isEmpty {
            parts.append(fullAddress)
        }
        return parts.isEmpty ? "未知地点" : parts.joined(separator: " · ")
    }

    private func openInMaps() {
        let item = MKMapItem(location: location, address: nil)
        let t = (placeLabel.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let generic = t.isEmpty || t == "正在解析地点…" || t == "无法解析地点名称"
        item.name = generic ? "拍摄位置" : t
        item.openInMaps(launchOptions: nil)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil }
        let id = "pin"
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        v.annotation = annotation
        v.markerTintColor = .systemRed
        v.glyphImage = nil
        v.displayPriority = .required
        return v
    }
}

// MARK: - Sheet 主控制器

final class PhotoAssetInfoSheetViewController: UIViewController {

    private let asset: PHAsset
    private var sections: [PhotoInfoSection] = []

    private lazy var handleBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        view.layer.cornerRadius = 2.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        let ref = UIFont.preferredFont(forTextStyle: .title3)
        label.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: UIFont.systemFont(ofSize: ref.pointSize, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        var cfg = UIButton.Configuration.plain()
        cfg.title = "完成"
        let ref = UIFont.preferredFont(forTextStyle: .body)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.systemFont(ofSize: ref.pointSize, weight: .semibold))
            return out
        }
        button.configuration = cfg
        button.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .clear
        tv.keyboardDismissMode = .onDrag
        tv.sectionFooterHeight = 0.01
        tv.estimatedRowHeight = 44
        tv.estimatedSectionHeaderHeight = 28
        tv.rowHeight = UITableView.automaticDimension
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 6
        }
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "kv")
        return tv
    }()

    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        titleLabel.text = Self.sheetTitle(for: asset)
        sections = Self.buildInfoSections(for: asset)
        setupUI()
        applyTableHeaderIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeTableHeaderToFit()
    }

    private func setupUI() {
        view.addSubview(handleBar)
        view.addSubview(titleLabel)
        view.addSubview(doneButton)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),

            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func applyTableHeaderIfNeeded() {
        guard let loc = asset.location else {
            tableView.tableHeaderView = nil
            return
        }
        let header = AssetLocationMapHeaderView(location: loc)
        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 1)
        tableView.tableHeaderView = header
    }

    private func sizeTableHeaderToFit() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let target = header.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if abs(header.frame.height - target.height) > 0.5 || header.frame.width != width {
            header.frame = CGRect(x: 0, y: 0, width: width, height: target.height)
            tableView.tableHeaderView = header
        }
    }

    @objc private func didTapDone() {
        dismiss(animated: true)
    }

    // MARK: - 标题与数据构建

    static func sheetTitle(for asset: PHAsset) -> String {
        switch asset.mediaType {
        case .video: return "视频信息"
        case .audio: return "音频信息"
        case .image: return "照片信息"
        case .unknown: fallthrough
        @unknown default: return "媒体信息"
        }
    }

    /// 供列表展示的分组数据（位置详情与地图分离：地图在 tableHeaderView）。
    fileprivate static func buildInfoSections(for asset: PHAsset) -> [PhotoInfoSection] {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateStyle = .medium
        df.timeStyle = .short

        var result: [PhotoInfoSection] = []

        if let loc = asset.location {
            var locRows: [PhotoInfoRow] = [
                PhotoInfoRow(name: "纬度", value: String(format: "%.6f°", loc.coordinate.latitude)),
                PhotoInfoRow(name: "经度", value: String(format: "%.6f°", loc.coordinate.longitude))
            ]
            if loc.altitude != 0 || loc.verticalAccuracy >= 0 {
                locRows.append(PhotoInfoRow(name: "海拔", value: String(format: "%.1f m", loc.altitude)))
            }
            if loc.horizontalAccuracy >= 0 {
                locRows.append(PhotoInfoRow(name: "水平精度", value: String(format: "±%.0f m", loc.horizontalAccuracy)))
            }
            if loc.verticalAccuracy >= 0 {
                locRows.append(PhotoInfoRow(name: "垂直精度", value: String(format: "±%.0f m", loc.verticalAccuracy)))
            }
            locRows.append(PhotoInfoRow(name: "定位时间", value: df.string(from: loc.timestamp)))
            result.append(PhotoInfoSection(title: "位置", rows: locRows))
        } else {
            result.append(PhotoInfoSection(title: "位置", rows: [
                PhotoInfoRow(name: "GPS", value: "无嵌入位置信息")
            ]))
        }

        result.append(PhotoInfoSection(title: "标识", rows: [
            PhotoInfoRow(name: "本地标识符", value: asset.localIdentifier, monospaceValue: true)
        ]))

        let subtypes = mediaSubtypeLabels(asset.mediaSubtypes)
        let subtypeText = subtypes.isEmpty ? "无" : subtypes.joined(separator: "、")

        result.append(PhotoInfoSection(title: "媒体", rows: [
            PhotoInfoRow(name: "类型", value: mediaTypeLabel(asset.mediaType)),
            PhotoInfoRow(name: "播放样式", value: playbackStyleLabel(asset.playbackStyle)),
            PhotoInfoRow(name: "来源", value: sourceTypeLabel(asset.sourceType)),
            PhotoInfoRow(name: "子类型", value: subtypeText)
        ]))

        let mp = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000.0
        var dimRows: [PhotoInfoRow] = [
            PhotoInfoRow(name: "像素尺寸", value: "\(asset.pixelWidth) × \(asset.pixelHeight)"),
            PhotoInfoRow(name: "分辨率", value: String(format: "约 %.2f MP", mp))
        ]
        if asset.mediaType == .video || asset.mediaType == .audio {
            let sec = max(0, Int(round(asset.duration)))
            dimRows.append(PhotoInfoRow(
                name: "时长",
                value: "\(formatDuration(seconds: sec))（\(String(format: "%.3f", asset.duration)) 秒）"
            ))
        }
        result.append(PhotoInfoSection(title: "尺寸与时间轴", rows: dimRows))

        let created = asset.creationDate.map { df.string(from: $0) } ?? "无"
        let modified = asset.modificationDate.map { df.string(from: $0) } ?? "无"
        result.append(PhotoInfoSection(title: "时间", rows: [
            PhotoInfoRow(name: "拍摄 / 创建", value: created),
            PhotoInfoRow(name: "修改", value: modified)
        ]))

        if asset.burstIdentifier != nil || asset.representsBurst || !asset.burstSelectionTypes.isEmpty {
            var burstRows: [PhotoInfoRow] = []
            if let id = asset.burstIdentifier {
                burstRows.append(PhotoInfoRow(name: "连拍标识", value: id, monospaceValue: true))
            }
            burstRows.append(PhotoInfoRow(name: "代表连拍集", value: asset.representsBurst ? "是" : "否"))
            let sel = burstSelectionLabels(asset.burstSelectionTypes)
            burstRows.append(PhotoInfoRow(name: "连拍选中", value: sel.isEmpty ? "无" : sel.joined(separator: "、")))
            result.append(PhotoInfoSection(title: "连拍", rows: burstRows))
        }

        var edits: [String] = []
        if asset.canPerform(.delete) { edits.append("可删除") }
        if asset.canPerform(.content) { edits.append("可内容编辑") }
        result.append(PhotoInfoSection(title: "图库状态", rows: [
            PhotoInfoRow(name: "收藏", value: asset.isFavorite ? "是" : "否"),
            PhotoInfoRow(name: "隐藏", value: asset.isHidden ? "是" : "否"),
            PhotoInfoRow(name: "含编辑 / 调整", value: asset.hasAdjustments ? "是" : "否"),
            PhotoInfoRow(name: "编辑能力", value: edits.isEmpty ? "无或未授权" : edits.joined(separator: "、"))
        ]))

        let resources = PHAssetResource.assetResources(for: asset)
        if resources.isEmpty {
            result.append(PhotoInfoSection(title: "底层资源", rows: [
                PhotoInfoRow(name: "资源", value: "无 PHAssetResource 条目")
            ]))
        } else {
            var resRows: [PhotoInfoRow] = [
                PhotoInfoRow(name: "文件数", value: "\(resources.count)")
            ]
            for (i, r) in resources.enumerated() {
                let name = r.originalFilename.isEmpty ? "（无文件名）" : r.originalFilename
                let uti = r.uniformTypeIdentifier.isEmpty ? "—" : r.uniformTypeIdentifier
                resRows.append(PhotoInfoRow(
                    name: "资源 \(i + 1)",
                    value: "\(resourceTypeLabel(r.type))\n\(name)\n\(uti)",
                    monospaceValue: false
                ))
            }
            result.append(PhotoInfoSection(title: "底层资源", rows: resRows))
        }

        return result
    }

    // MARK: - 格式化辅助

    private static func formatDuration(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func mediaTypeLabel(_ t: PHAssetMediaType) -> String {
        switch t {
        case .image: return "图像"
        case .video: return "视频"
        case .audio: return "音频"
        case .unknown: return "未知"
        @unknown default: return "其他 (\(t.rawValue))"
        }
    }

    private static func sourceTypeLabel(_ t: PHAssetSourceType) -> String {
        switch t {
        case .typeUserLibrary: return "本机相册"
        case .typeCloudShared: return "共享相簿"
        case .typeiTunesSynced: return "通过 iTunes / 访达同步"
        default: return "其他来源 (\(t.rawValue))"
        }
    }

    private static func playbackStyleLabel(_ s: PHAsset.PlaybackStyle) -> String {
        switch s {
        case .unsupported: return "不支持 / 未知"
        case .image: return "静态图像"
        case .imageAnimated: return "动图（如 GIF）"
        case .livePhoto: return "实况照片"
        case .video: return "视频"
        case .videoLooping: return "循环视频"
        default: return "其他 (\(s.rawValue))"
        }
    }

    private static func mediaSubtypeLabels(_ sub: PHAssetMediaSubtype) -> [String] {
        let pairs: [(PHAssetMediaSubtype, String)] = [
            (.photoHDR, "HDR"),
            (.photoPanorama, "全景"),
            (.photoDepthEffect, "人像 / 景深"),
            (.photoScreenshot, "截屏"),
            (.photoLive, "实况照片"),
            (.videoHighFrameRate, "高帧率视频"),
            (.videoStreamed, "流媒体视频"),
            (.videoTimelapse, "延时摄影"),
            (.videoCinematic, "电影效果")
        ]
        return pairs.filter { sub.contains($0.0) }.map(\.1)
    }

    private static func burstSelectionLabels(_ t: PHAssetBurstSelectionType) -> [String] {
        let pairs: [(PHAssetBurstSelectionType, String)] = [
            (.autoPick, "系统自动挑选"),
            (.userPick, "用户挑选")
        ]
        return pairs.filter { t.contains($0.0) }.map(\.1)
    }

    private static func resourceTypeLabel(_ type: PHAssetResourceType) -> String {
        switch type {
        case .photo: return "照片"
        case .video: return "视频"
        case .pairedVideo: return "配对视频（实况）"
        case .fullSizePhoto: return "全尺寸照片"
        case .fullSizeVideo: return "全尺寸视频"
        case .adjustmentData: return "调整数据"
        case .alternatePhoto: return "备用照片"
        case .fullSizePairedVideo: return "全尺寸配对视频"
        case .adjustmentBasePhoto: return "调整基准照片"
        case .adjustmentBaseVideo: return "调整基准视频"
        case .adjustmentBasePairedVideo: return "调整基准配对视频"
        case .photoProxy: return "照片代理"
        default: return "资源类型 (\(type.rawValue))"
        }
    }

}

// MARK: - UITableView

extension PhotoAssetInfoSheetViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .preferredFont(forTextStyle: .footnote)
        header.textLabel?.textColor = .secondaryLabel
        header.textLabel?.text = sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "kv", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .secondarySystemGroupedBackground

        let row = sections[indexPath.section].rows[indexPath.row]
        var config = UIListContentConfiguration.valueCell()
        config.text = row.name
        let sub = UIFont.preferredFont(forTextStyle: .subheadline)
        config.textProperties.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: UIFont.systemFont(ofSize: sub.pointSize, weight: .regular))
        config.textProperties.color = .secondaryLabel
        config.secondaryText = row.value
        config.secondaryTextProperties.numberOfLines = 0
        let body = UIFont.preferredFont(forTextStyle: .body)
        if row.monospaceValue {
            config.secondaryTextProperties.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedSystemFont(ofSize: body.pointSize - 1, weight: .regular))
        } else {
            config.secondaryTextProperties.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.systemFont(ofSize: body.pointSize, weight: .regular))
        }
        config.secondaryTextProperties.color = .label
        config.secondaryTextProperties.alignment = .natural
        // 短值用系统「设置」式左右排列；长文 / 多行 / 等宽标识符纵向堆叠，避免挤压。
        let longValue = row.value.count > 36
        let stacked = row.value.contains("\n") || row.monospaceValue || longValue
        config.prefersSideBySideTextAndSecondaryText = !stacked
        cell.contentConfiguration = config
        return cell
    }
}
