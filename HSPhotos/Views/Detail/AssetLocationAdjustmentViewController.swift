import UIKit
import MapKit
import Photos

final class AssetLocationAdjustmentViewController: UIViewController {
    var onAssetLocationUpdated: ((PHAsset) -> Void)?
    
    private let asset: PHAsset
    private let originalLocation: CLLocation?
    private var selectedCoordinate: CLLocationCoordinate2D? {
        didSet {
            updateActionButton()
        }
    }
    
    private let centerPinImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "mappin", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)))
        iv.tintColor = .systemRed
        iv.translatesAutoresizingMaskIntoConstraints = false
        // 阴影让悬浮感更强
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOpacity = 0.3
        iv.layer.shadowOffset = CGSize(width: 0, height: 2)
        iv.layer.shadowRadius = 4
        return iv
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(weight: .medium)), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.secondarySystemGroupedBackground
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        button.backgroundColor = UIColor.secondarySystemGroupedBackground
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.searchBarStyle = .minimal
        bar.placeholder = "搜索地点或地址"
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    private let mapView: MKMapView = {
        let map = MKMapView()
        map.mapType = .standard
        map.showsUserLocation = true
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()
    
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isHidden = true
        tv.backgroundColor = .systemGroupedBackground
        return tv
    }()
    
    private let completer = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
    
    init(asset: PHAsset, onAssetLocationUpdated: ((PHAsset) -> Void)? = nil) {
        self.asset = asset
        self.onAssetLocationUpdated = onAssetLocationUpdated
        self.originalLocation = asset.location
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupCompleter()
        configureMapAndInitialState()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        
        topBar.addSubview(closeButton)
        topBar.addSubview(titleLabel)
        topBar.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            actionButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            actionButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 32),
            
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        view.addSubview(searchBar)
        view.addSubview(mapView)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            
            mapView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.addSubview(centerPinImageView)
        NSLayoutConstraint.activate([
            centerPinImageView.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            centerPinImageView.bottomAnchor.constraint(equalTo: mapView.centerYAnchor)
        ])
        
        mapView.delegate = self
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    private func setupGestures() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }
    
    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    private func configureMapAndInitialState() {
        if let loc = originalLocation {
            titleLabel.text = "调整位置"
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
            mapView.setRegion(region, animated: false)
            selectedCoordinate = loc.coordinate
        } else {
            titleLabel.text = "添加位置"
        }
        updateActionButton()
    }
    
    private func updateActionButton() {
        guard let current = selectedCoordinate else {
            actionButton.isHidden = true
            return
        }
        
        let hasMoved: Bool
        if let orig = originalLocation {
            let dist = CLLocation(latitude: current.latitude, longitude: current.longitude)
                .distance(from: orig)
            hasMoved = dist > 10 // >10 meters is considered moved
        } else {
            hasMoved = true
        }
        
        if hasMoved {
            actionButton.setTitle("完成", for: .normal)
            actionButton.setTitleColor(.systemBlue, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.setTitle("移除", for: .normal)
            actionButton.setTitleColor(.systemRed, for: .normal)
            actionButton.isHidden = false
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func actionTapped() {
        if actionButton.title(for: .normal) == "移除" {
            applyLocation(nil)
        } else if let coordinate = selectedCoordinate {
            let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            applyLocation(loc)
        }
    }
    
    private func applyLocation(_ location: CLLocation?) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.asset)
            request.location = location
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [self.asset.localIdentifier], options: nil)
                    let updatedAsset = result.firstObject ?? self.asset
                    self.onAssetLocationUpdated?(updatedAsset)
                    self.dismiss(animated: true)
                } else {
                    let alert = UIAlertController(title: "操作失败", message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension AssetLocationAdjustmentViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults.removeAll()
            tableView.reloadData()
            tableView.isHidden = true
        } else {
            tableView.isHidden = false
            completer.queryFragment = searchText
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchResults.removeAll()
        tableView.reloadData()
        tableView.isHidden = true
    }
}

extension AssetLocationAdjustmentViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        tableView.reloadData()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Ignored
    }
}

extension AssetLocationAdjustmentViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let result = searchResults[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = result.title
        content.secondaryText = result.subtitle
        cell.contentConfiguration = content
        cell.backgroundColor = .systemGroupedBackground
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let completion = searchResults[indexPath.row]
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] response, error in
            guard let mapItem = response?.mapItems.first, let loc = mapItem.placemark.location else { return }
            // 搜索后移动地图中心，不直接应用
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            self?.mapView.setRegion(region, animated: true)
            self?.searchBar.text = ""
            self?.searchBar.resignFirstResponder()
            self?.searchResults.removeAll()
            self?.tableView.reloadData()
            self?.tableView.isHidden = true
        }
    }
}

extension AssetLocationAdjustmentViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        selectedCoordinate = mapView.centerCoordinate
    }
}
