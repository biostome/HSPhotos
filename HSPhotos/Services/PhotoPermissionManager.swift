import UIKit
import Photos

class PhotoPermissionManager {
    static let shared = PhotoPermissionManager()
    
    private init() {}
    
    enum PermissionStatus {
        case notDetermined
        case denied
        case authorized
        case limited
    }
    
    func requestPhotoPermission(completion: @escaping (PermissionStatus) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(self.mapAuthorizationStatus(newStatus))
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(.denied)
            }
        case .authorized:
            DispatchQueue.main.async {
                completion(.authorized)
            }
        case .limited:
            DispatchQueue.main.async {
                completion(.limited)
            }
        @unknown default:
            DispatchQueue.main.async {
                completion(.denied)
            }
        }
    }
    
    func getCurrentPermissionStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return mapAuthorizationStatus(status)
    }
    
    private func mapAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .denied
        }
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
