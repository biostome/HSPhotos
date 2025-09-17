//
//  ViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/21.
//

import UIKit

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .orange
        checkPhotoPermission()
    }
    
    private func checkPhotoPermission() {
        PhotoPermissionManager.shared.requestPhotoPermission { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.showAlbumList()
                case .denied:
                    self?.showPermissionViewController()
                case .notDetermined:
                    // 这种情况不应该发生，因为requestPhotoPermission会处理
                    break
                }
            }
        }
    }
    
    private func showAlbumList() {
        let albumListVC = AlbumListViewController()
        let navigationController = UINavigationController(rootViewController: albumListVC)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: false)
    }
    
    private func showPermissionViewController() {
        let permissionVC = PermissionViewController()
        permissionVC.modalPresentationStyle = .fullScreen
        present(permissionVC, animated: false)
    }
    
}


#Preview {
    MainViewController()
}

