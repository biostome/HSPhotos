//
//  AlbumListRouter.swift
//  HSPhotos
//
//  相册列表页导航：进入相簿网格、子文件夹、Picker 完成与取消。
//

import Photos
import UIKit

struct AlbumListRouter {

    let isPickerMode: Bool
    let onAlbumPicked: ((PHAssetCollection) -> Void)?

    func openAlbum(_ collection: PHAssetCollection, from host: UIViewController) {
        if isPickerMode {
            onAlbumPicked?(collection)
            dismissPicker(from: host)
            return
        }
        let photoVC = PhotoGridViewController(collection: collection)
        host.navigationController?.pushViewController(photoVC, animated: true)
    }

    func openFolder(_ list: PHCollectionList, from host: UIViewController) {
        let folderVC = AlbumListViewController(
            collectionList: list,
            isPickerMode: isPickerMode,
            onAlbumPicked: onAlbumPicked
        )
        host.navigationController?.pushViewController(folderVC, animated: true)
    }

    func dismissPicker(from host: UIViewController) {
        if let navigationController = host.navigationController,
           navigationController.presentingViewController != nil {
            navigationController.dismiss(animated: true)
        } else {
            host.dismiss(animated: true)
        }
    }
}
