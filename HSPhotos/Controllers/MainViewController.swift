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
        setupBackgroundImage()
        checkPhotoPermission()
    }
    
    private func setupBackgroundImage() {
        let backgroundImage = UIImage(named: "Launch")
        let backgroundImageView = UIImageView(image: backgroundImage)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backgroundImageView, at: 0)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        let tabbarController = MainTabbarViewContoller()
        tabbarController.modalPresentationStyle = .fullScreen
        present(tabbarController, animated: false)
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

