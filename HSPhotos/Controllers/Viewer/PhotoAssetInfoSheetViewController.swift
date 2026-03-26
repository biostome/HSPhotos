import CoreLocation
import ImageIO
import MapKit
import Photos
import UIKit
import UniformTypeIdentifiers

private let assetOriginalCreationDateKeyPrefix = "asset_original_creation_date_"

private struct AssetMetadataSummary {
    var deviceModel: String?
    var lensDescription: String?
    var fileFormat: String?
    var fileSizeText: String?
    var resolutionText: String?
    var isoText: String?
    var focalLengthText: String?
    var exposureBiasText: String?
    var apertureText: String?
    var shutterText: String?
}

private final class AssetInfoCardView: UIView {
    let stackView = UIStackView()

    init(cornerRadius: CGFloat = 18) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.secondarySystemGroupedBackground
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous

        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AssetInfoRowView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let leadingImageView = UIImageView()
    private let trailingLabel = UILabel()
    private let separator = UIView()

    init(
        title: String? = nil,
        value: String? = nil,
        leadingSymbol: String? = nil,
        trailingText: String? = nil,
        titleFont: UIFont = .systemFont(ofSize: 16, weight: .regular),
        valueFont: UIFont = .systemFont(ofSize: 16, weight: .regular),
        valueColor: UIColor = .label,
        showsSeparator: Bool = true
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = titleFont
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = valueFont
        valueLabel.textColor = valueColor
        valueLabel.text = value
        valueLabel.numberOfLines = 0

        leadingImageView.translatesAutoresizingMaskIntoConstraints = false
        leadingImageView.tintColor = .secondaryLabel
        leadingImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        leadingImageView.image = leadingSymbol.flatMap { UIImage(systemName: $0) }
        leadingImageView.isHidden = leadingSymbol == nil

        trailingLabel.translatesAutoresizingMaskIntoConstraints = false
        trailingLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        trailingLabel.textColor = .systemBlue
        trailingLabel.text = trailingText
        trailingLabel.isHidden = trailingText == nil

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        separator.isHidden = !showsSeparator

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(leadingImageView)
        addSubview(trailingLabel)
        addSubview(separator)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            leadingImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            leadingImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leadingImageView.widthAnchor.constraint(equalToConstant: 18),
            leadingImageView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            valueLabel.leadingAnchor.constraint(equalTo: leadingImageView.trailingAnchor, constant: leadingSymbol == nil ? 0 : 8),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingLabel.leadingAnchor, constant: -12),
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            trailingLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            trailingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        if title == nil {
            titleLabel.isHidden = true
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: leadingImageView.trailingAnchor, constant: leadingSymbol == nil ? 16 : 8)
            ])
        } else {
            valueLabel.textAlignment = .right
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AssetMetricsStripView: UIView {
    init(items: [String]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 44)
        ])

        for (index, item) in items.enumerated() {
            let label = UILabel()
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.text = item

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])

            if index < items.count - 1 {
                let divider = UIView()
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
                container.addSubview(divider)
                NSLayoutConstraint.activate([
                    divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    divider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    divider.widthAnchor.constraint(equalToConstant: 0.5),
                    divider.heightAnchor.constraint(equalToConstant: 14)
                ])
            }

            stack.addArrangedSubview(container)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AssetLinkRowView: UIView {
    var onTapped: (() -> Void)?

    private let thumbnailImageView = UIImageView()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronImageView = UIImageView()
    private let separator = UIView()

    init(title: String, showsSeparator: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 10
        thumbnailImageView.layer.cornerCurve = .continuous
        thumbnailImageView.isHidden = true

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = UIColor.systemGray5
        iconContainer.layer.cornerRadius = 10
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.isHidden = true

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconContainer.addSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.text = title
        titleLabel.numberOfLines = 1

        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        separator.isHidden = !showsSeparator

        addSubview(thumbnailImageView)
        addSubview(iconContainer)
        addSubview(titleLabel)
        addSubview(chevronImageView)
        addSubview(separator)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 66),

            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            thumbnailImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 38),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 38),

            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 38),
            iconContainer.heightAnchor.constraint(equalToConstant: 38),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setThumbnail(_ image: UIImage?) {
        thumbnailImageView.image = image
        thumbnailImageView.isHidden = image == nil
        iconContainer.isHidden = image != nil
    }

    @objc private func handleTap() {
        onTapped?()
    }

    func setValue(_ text: String) {
        titleLabel.text = text
    }

    func setIcon(symbolName: String, backgroundColor: UIColor) {
        iconContainer.backgroundColor = backgroundColor
        iconImageView.image = UIImage(systemName: symbolName)
        iconContainer.isHidden = false
        thumbnailImageView.isHidden = true
    }
}

private final class AssetLocationCardView: UIView {
    private let mapView = MKMapView()
    private let addressLabel = UILabel()
    private let adjustLabel = UILabel()
    private let location: CLLocation
    private var reverseGeocodeRequest: MKReverseGeocodingRequest?
    private var geocodeToken = UUID()
    var onAdjustTapped: (() -> Void)?

    init(location: CLLocation) {
        self.location = location
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let card = AssetInfoCardView()
        addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 700, longitudinalMeters: 700)
        mapView.setRegion(region, animated: false)
        let pin = MKPointAnnotation()
        pin.coordinate = location.coordinate
        mapView.addAnnotation(pin)

        let mapContainer = UIView()
        mapContainer.translatesAutoresizingMaskIntoConstraints = false
        mapContainer.clipsToBounds = true
        mapContainer.layer.cornerRadius = 16
        mapContainer.layer.cornerCurve = .continuous
        mapContainer.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: mapContainer.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapContainer.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: mapContainer.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapContainer.bottomAnchor),
            mapContainer.heightAnchor.constraint(equalToConstant: 168)
        ])

        let bottomRow = UIView()
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addressLabel.font = .systemFont(ofSize: 16, weight: .regular)
        addressLabel.textColor = .systemBlue
        addressLabel.numberOfLines = 0
        addressLabel.text = "正在解析地点…"

        adjustLabel.translatesAutoresizingMaskIntoConstraints = false
        adjustLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        adjustLabel.textColor = .systemBlue
        adjustLabel.text = "调整"
        adjustLabel.setContentHuggingPriority(.required, for: .horizontal)
        adjustLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        adjustLabel.isUserInteractionEnabled = true
        adjustLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleAdjustTap)))

        bottomRow.addSubview(addressLabel)
        bottomRow.addSubview(adjustLabel)
        NSLayoutConstraint.activate([
            bottomRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            addressLabel.leadingAnchor.constraint(equalTo: bottomRow.leadingAnchor, constant: 12),
            addressLabel.topAnchor.constraint(equalTo: bottomRow.topAnchor, constant: 10),
            addressLabel.bottomAnchor.constraint(equalTo: bottomRow.bottomAnchor, constant: -10),
            addressLabel.trailingAnchor.constraint(lessThanOrEqualTo: adjustLabel.leadingAnchor, constant: -12),
            adjustLabel.trailingAnchor.constraint(equalTo: bottomRow.trailingAnchor, constant: -12),
            adjustLabel.centerYAnchor.constraint(equalTo: bottomRow.centerYAnchor)
        ])

        card.stackView.addArrangedSubview(mapContainer)
        card.stackView.addArrangedSubview(bottomRow)
        startReverseGeocode()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        reverseGeocodeRequest?.cancel()
    }

    private func startReverseGeocode() {
        let token = UUID()
        geocodeToken = token
        guard let request = MKReverseGeocodingRequest(location: location) else {
            addressLabel.text = "未知地点"
            return
        }
        reverseGeocodeRequest = request
        request.getMapItems { [weak self] items, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.geocodeToken == token else { return }
                if let item = items?.first {
                    self.addressLabel.text = Self.format(item: item)
                } else {
                    self.addressLabel.text = "未知地点"
                }
            }
        }
    }

    private static func format(item: MKMapItem) -> String {
        var parts: [String] = []
        if let address = item.address?.fullAddress, !address.isEmpty {
            parts.append(address)
        }
        if let name = item.name, !name.isEmpty, parts.isEmpty {
            parts.append(name)
        }
        return parts.isEmpty ? "未知地点" : parts.joined(separator: " ")
    }
    
    @objc private func handleAdjustTap() {
        onAdjustTapped?()
    }
}

private final class AssetLocationPlaceholderCardView: UIView {
    var onAddLocationTapped: (() -> Void)?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let card = AssetInfoCardView()
        addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.text = "添加位置…"

        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleAddLocationTap)))
        row.addSubview(label)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 62),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        card.stackView.addArrangedSubview(row)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleAddLocationTap() {
        onAddLocationTapped?()
    }
}

final class PhotoAssetInfoSheetViewController: UIViewController {
    
    var onAlbumSelected: ((PHAssetCollection?) -> Void)?
    
    private var asset: PHAsset
    private var metadataSummary = AssetMetadataSummary()
    private var metadataRequestID: PHImageRequestID = PHInvalidImageRequestID
    private var thumbnailRequestID: PHImageRequestID = PHInvalidImageRequestID

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let noteTextField = UITextField()
    private let dateLabel = UILabel()
    private let dateAdjustLabel = UILabel()
    private let identifierLabel = UILabel()
    private let deviceCard = AssetInfoCardView()
    private let metricsStripContainer = AssetInfoCardView(cornerRadius: 14)
    private let locationCardContainer = UIStackView()
    private let collectionsCard = AssetInfoCardView()
    private var dynamicCollectionRows: [AssetLinkRowView] = []
    private let showAllButton = UIButton(type: .system)

    private var hasCameraMetadata: Bool {
        metadataSummary.deviceModel != nil || metadataSummary.lensDescription != nil
    }

    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        setupLayout()
        populateStaticContent()
        loadMetadata()
    }

    deinit {
        if metadataRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(metadataRequestID)
        }
        if thumbnailRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(thumbnailRequestID)
        }
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -18),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        noteTextField.translatesAutoresizingMaskIntoConstraints = false
        noteTextField.font = .systemFont(ofSize: 16, weight: .regular)
        noteTextField.textColor = .label
        noteTextField.attributedPlaceholder = NSAttributedString(
            string: "添加说明",
            attributes: [.foregroundColor: UIColor.tertiaryLabel]
        )
        noteTextField.borderStyle = .none
        noteTextField.clearButtonMode = .whileEditing
        contentStack.addArrangedSubview(noteTextField)
        noteTextField.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let headerRow = UIView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        dateLabel.textColor = .label
        dateLabel.numberOfLines = 1

        dateAdjustLabel.translatesAutoresizingMaskIntoConstraints = false
        dateAdjustLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        dateAdjustLabel.textColor = .systemBlue
        dateAdjustLabel.text = "调整"
        dateAdjustLabel.isUserInteractionEnabled = true
        dateAdjustLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAdjustDate)))

        headerRow.addSubview(dateLabel)
        headerRow.addSubview(dateAdjustLabel)
        NSLayoutConstraint.activate([
            headerRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            dateLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: headerRow.topAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateAdjustLabel.leadingAnchor, constant: -12),
            dateAdjustLabel.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            dateAdjustLabel.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor)
        ])
        contentStack.addArrangedSubview(headerRow)

        let idRow = UIView()
        idRow.translatesAutoresizingMaskIntoConstraints = false
        let cloudIcon = UIImageView(image: UIImage(systemName: "icloud"))
        cloudIcon.translatesAutoresizingMaskIntoConstraints = false
        cloudIcon.tintColor = .secondaryLabel
        cloudIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)

        identifierLabel.translatesAutoresizingMaskIntoConstraints = false
        identifierLabel.font = .systemFont(ofSize: 14, weight: .medium)
        identifierLabel.textColor = .secondaryLabel

        idRow.addSubview(cloudIcon)
        idRow.addSubview(identifierLabel)
        NSLayoutConstraint.activate([
            idRow.heightAnchor.constraint(equalToConstant: 22),
            cloudIcon.leadingAnchor.constraint(equalTo: idRow.leadingAnchor, constant: 2),
            cloudIcon.centerYAnchor.constraint(equalTo: idRow.centerYAnchor),
            cloudIcon.widthAnchor.constraint(equalToConstant: 16),
            cloudIcon.heightAnchor.constraint(equalToConstant: 16),
            identifierLabel.leadingAnchor.constraint(equalTo: cloudIcon.trailingAnchor, constant: 8),
            identifierLabel.trailingAnchor.constraint(equalTo: idRow.trailingAnchor),
            identifierLabel.centerYAnchor.constraint(equalTo: idRow.centerYAnchor)
        ])
        contentStack.addArrangedSubview(idRow)

        contentStack.addArrangedSubview(deviceCard)
        contentStack.addArrangedSubview(metricsStripContainer)

        locationCardContainer.axis = .vertical
        locationCardContainer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(locationCardContainer)

        contentStack.addArrangedSubview(collectionsCard)

        var config = UIButton.Configuration.filled()
        config.title = "在所有照片中显示"
        config.baseBackgroundColor = UIColor.secondarySystemGroupedBackground
        config.baseForegroundColor = .systemBlue
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        showAllButton.configuration = config
        showAllButton.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(showAllButton)
    }

    private func populateStaticContent() {
        dateLabel.text = Self.formattedDateText(for: asset)
        identifierLabel.text = Self.primaryResourceFilename(for: asset)
        rebuildDeviceCard()
        rebuildMetricsStrip()
        rebuildLocationCard()
        rebuildCollectionsCard()
        loadThumbnailRows()
    }

    @objc
    private func didTapAdjustDate() {
        let adjustmentController = AssetDateAdjustmentViewController(asset: asset)
        adjustmentController.onAssetDateUpdated = { [weak self] updatedAsset in
            guard let self else { return }
            self.asset = updatedAsset
            self.populateStaticContent()
        }
        present(adjustmentController, animated: true)
    }

    @objc
    private func didTapAdjustLocation() {
        let locationController = AssetLocationAdjustmentViewController(asset: asset)
        locationController.onAssetLocationUpdated = { [weak self] updatedAsset in
            guard let self else { return }
            self.asset = updatedAsset
            self.populateStaticContent()
        }
        present(locationController, animated: true)
    }

    private func rebuildLocationCard() {
        locationCardContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if let location = asset.location {
            let card = AssetLocationCardView(location: location)
            card.onAdjustTapped = { [weak self] in
                self?.didTapAdjustLocation()
            }
            locationCardContainer.addArrangedSubview(card)
        } else {
            let card = AssetLocationPlaceholderCardView()
            card.onAddLocationTapped = { [weak self] in
                self?.didTapAdjustLocation()
            }
            locationCardContainer.addArrangedSubview(card)
        }
    }

    private func loadMetadata() {
        guard asset.mediaType == .image else { return }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        metadataRequestID = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] data, dataUTI, _, info in
            guard let self else { return }
            let degraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            guard !degraded, let data else { return }
            let summary = Self.extractMetadataSummary(data: data, utiString: dataUTI, asset: self.asset)
            DispatchQueue.main.async {
                self.metadataSummary = summary
                self.rebuildDeviceCard()
                self.rebuildMetricsStrip()
            }
        }
    }

    private func rebuildDeviceCard() {
        deviceCard.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let titleRow = UIView()
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .label
        title.text = hasCameraMetadata ? (metadataSummary.deviceModel ?? "Apple iPhone") : "无相机信息"
        title.numberOfLines = 0

        let formatBadge = UILabel()
        formatBadge.translatesAutoresizingMaskIntoConstraints = false
        formatBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        formatBadge.textColor = .white
        formatBadge.backgroundColor = UIColor.systemGray3
        formatBadge.layer.cornerRadius = 6
        formatBadge.clipsToBounds = true
        formatBadge.textAlignment = .center
        formatBadge.text = " \(resolvedFormatBadgeText()) "

        let iconName = resolvedFormatIndicatorSymbolName()
        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .secondaryLabel

        titleRow.addSubview(title)
        titleRow.addSubview(formatBadge)
        titleRow.addSubview(icon)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: titleRow.topAnchor, constant: 10),
            title.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: -10),
            formatBadge.trailingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -8),
            formatBadge.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
            icon.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor, constant: -12),
            icon.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: formatBadge.leadingAnchor, constant: -8)
        ])
        deviceCard.stackView.addArrangedSubview(titleRow)

        deviceCard.stackView.addArrangedSubview(AssetInfoRowView(
            title: nil,
            value: hasCameraMetadata ? (metadataSummary.lensDescription ?? "主摄像头") : "无镜头信息",
            trailingText: nil,
            titleFont: .systemFont(ofSize: 16, weight: .regular),
            valueFont: .systemFont(ofSize: 16, weight: .regular),
            valueColor: .secondaryLabel
        ))

        let summaryText = [metadataSummary.resolutionText, metadataSummary.fileSizeText]
            .compactMap { $0 }
            .joined(separator: " • ")
        deviceCard.stackView.addArrangedSubview(AssetInfoRowView(
            title: nil,
            value: summaryText.isEmpty ? "\(asset.pixelWidth) × \(asset.pixelHeight)" : summaryText,
            trailingText: nil,
            titleFont: .systemFont(ofSize: 16, weight: .regular),
            valueFont: .systemFont(ofSize: 16, weight: .regular),
            valueColor: .secondaryLabel,
            showsSeparator: false
        ))
    }

    private func rebuildMetricsStrip() {
        metricsStripContainer.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let items: [String]
        let placeholderItems: [String]
        if asset.mediaType == .video {
            items = [
                metadataSummary.isoText,
                PhotoAssetInfoSheetViewController.formatDuration(seconds: Int(round(asset.duration)))
            ].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            placeholderItems = ["-", "-"]
        } else {
            items = [
                metadataSummary.isoText,
                metadataSummary.focalLengthText,
                metadataSummary.exposureBiasText,
                metadataSummary.apertureText,
                metadataSummary.shutterText
            ].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            placeholderItems = ["-", "-", "-", "-", "-"]
        }

        metricsStripContainer.isHidden = false
        let displayItems = items.isEmpty ? placeholderItems : items
        metricsStripContainer.stackView.addArrangedSubview(AssetMetricsStripView(items: displayItems))
    }

    struct AlbumRowData {
        let title: String
        let collection: PHAssetCollection?
    }

    private func rebuildCollectionsCard() {
        collectionsCard.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        dynamicCollectionRows.removeAll()
        let rows = Self.collectionMembershipRows(for: asset)
        
        for (index, rowData) in rows.enumerated() {
            let isLast = index == rows.count - 1
            let rowView = AssetLinkRowView(title: rowData.title, showsSeparator: !isLast)
            
            if rowData.collection == nil {
                if index == 0 && rows.count == 2 {
                    rowView.setIcon(symbolName: "photo", backgroundColor: .systemGray5)
                } else {
                    rowView.setIcon(symbolName: "photo.fill", backgroundColor: UIColor(red: 0.88, green: 0.19, blue: 0.27, alpha: 1))
                }
            } else {
                rowView.setIcon(symbolName: "rectangle.stack", backgroundColor: .systemGray5)
            }
            
            rowView.onTapped = { [weak self] in
                self?.onAlbumSelected?(rowData.collection)
            }
            
            dynamicCollectionRows.append(rowView)
            collectionsCard.stackView.addArrangedSubview(rowView)
        }
    }

    private func loadThumbnailRows() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let size = CGSize(width: 120, height: 120)
        thumbnailRequestID = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { [weak self] image, info in
            guard let self else { return }
            let degraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            guard let image else { return }
            DispatchQueue.main.async {
                self.dynamicCollectionRows.first?.setThumbnail(image)
                if !degraded {
                    self.thumbnailRequestID = PHInvalidImageRequestID
                }
            }
        }
    }

    private static func formattedDateText(for asset: PHAsset) -> String {
        // 使用 creationDate（当通过系统或我们自己的修改页面调整了时间后，creationDate 内就是调整后的新时间）
        let date = asset.creationDate ?? asset.modificationDate ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return formatter.string(from: date)
    }

    private static func primaryResourceFilename(for asset: PHAsset) -> String {
        PHAssetResource.assetResources(for: asset).first?.originalFilename ?? asset.localIdentifier
    }

    private static func collectionMembershipRows(for asset: PHAsset) -> [AlbumRowData] {
        let fetch = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
        var rows: [AlbumRowData] = []
        fetch.enumerateObjects { collection, _, _ in
            if let title = collection.localizedTitle, !title.isEmpty {
                rows.append(AlbumRowData(title: "包含在\(title)中", collection: collection))
            }
        }
        if rows.isEmpty {
            rows.append(AlbumRowData(title: "包含在所有照片中", collection: nil))
            rows.append(AlbumRowData(title: "来自本机照片图库", collection: nil))
        } else {
            rows.append(AlbumRowData(title: "来自本机照片图库", collection: nil))
        }
        return rows
    }

    private func resolvedFormatBadgeText() -> String {
        if asset.playbackStyle == .livePhoto || asset.mediaSubtypes.contains(.photoLive) {
            return "LIVE"
        }

        let contentType = asset.contentType
        if let mapped = Self.badgeLabel(for: contentType) {
            return mapped
        }

        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            if let mapped = Self.badgeLabel(forUTIString: resource.uniformTypeIdentifier) {
                return mapped
            }
        }

        if let fileFormat = metadataSummary.fileFormat, !fileFormat.isEmpty {
            return fileFormat
        }
        if asset.mediaType == .video {
            return "H.264"
        }
        return "HEIF"
    }

    private func resolvedFormatIndicatorSymbolName() -> String {
        if asset.playbackStyle == .livePhoto || asset.mediaSubtypes.contains(.photoLive) {
            return "livephoto"
        }
        if asset.mediaType == .video {
            return "video"
        }

        let label = resolvedFormatBadgeText()
        switch label {
        case "GIF":
            return "sparkles.tv"
        case "RAW":
            return "r.square"
        case "PNG", "JPEG", "HEIF":
            return "photo"
        default:
            return "photo"
        }
    }

    private static func formatDuration(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func badgeLabel(for type: UTType) -> String? {
        if type.conforms(to: .heic) || type.conforms(to: .heif) {
            return "HEIF"
        }
        if type.conforms(to: .jpeg) {
            return "JPEG"
        }
        if type.conforms(to: .png) {
            return "PNG"
        }
        if type.conforms(to: .gif) {
            return "GIF"
        }
        if type.conforms(to: .rawImage) {
            return "RAW"
        }
        if type.conforms(to: .mpeg4Movie) {
            return "MP4"
        }
        if type.conforms(to: .quickTimeMovie) {
            return "MOV"
        }
        if type.conforms(to: .movie) {
            return "VIDEO"
        }
        return nil
    }

    private static func badgeLabel(forUTIString utiString: String) -> String? {
        guard let type = UTType(utiString) else { return nil }
        return badgeLabel(for: type)
    }

    private static func extractMetadataSummary(data: Data, utiString: String?, asset: PHAsset) -> AssetMetadataSummary {
        var summary = AssetMetadataSummary()
        if let utiString {
            summary.fileFormat = UTType(utiString)?.preferredFilenameExtension?.uppercased() ?? utiString.uppercased()
        }
        summary.fileSizeText = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        let megapixels = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000.0
        summary.resolutionText = "\(String(format: "%.0f", megapixels)) MP • \(asset.pixelWidth) x \(asset.pixelHeight)"

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return summary
        }

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]

        let trimmedModel = (tiff?[kCGImagePropertyTIFFModel] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedModel, !trimmedModel.isEmpty {
            summary.deviceModel = trimmedModel
        }

        let lensModel = exif?[kCGImagePropertyExifLensModel] as? String
        let focalLength35 = exif?[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double
        let fNumber = exif?[kCGImagePropertyExifFNumber] as? Double
        if let lensModel, !lensModel.isEmpty {
            summary.lensDescription = lensModel
        } else if let focalLength35, let fNumber {
            summary.lensDescription = "主摄像头 — \(Int(round(focalLength35))) mm ƒ\(Self.formattedNumber(fNumber))"
        }

        if let isoArray = exif?[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber], let iso = isoArray.first {
            summary.isoText = "ISO \(iso.intValue)"
        }
        if let focalLength35 {
            summary.focalLengthText = "\(Int(round(focalLength35))) mm"
        }
        if let exposureBias = exif?[kCGImagePropertyExifExposureBiasValue] as? Double {
            let bias = exposureBias == floor(exposureBias) ? String(Int(exposureBias)) : String(format: "%.1f", exposureBias)
            summary.exposureBiasText = "\(bias) ev"
        }
        if let fNumber {
            summary.apertureText = "ƒ\(Self.formattedNumber(fNumber))"
        }
        if let exposureTime = exif?[kCGImagePropertyExifExposureTime] as? Double {
            summary.shutterText = Self.formattedShutter(exposureTime)
        }
        if asset.mediaType == .video {
            summary.isoText = "30 FPS"
        }

        return summary
    }

    private static func formattedNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private static func formattedShutter(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        if value >= 1 {
            return String(format: "%.1fs", value)
        }
        let reciprocal = Int(round(1.0 / value))
        return "1/\(reciprocal)s"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let placeholderAsset = PHAsset()
    return PhotoAssetInfoSheetViewController(asset: placeholderAsset)
}
#endif

#if DEBUG
extension AssetDateAdjustmentViewController {
    static func createPreviewController() -> AssetDateAdjustmentViewController {
        let placeholderAsset = PHAsset()
        return AssetDateAdjustmentViewController(asset: placeholderAsset)
    }
}
#endif
