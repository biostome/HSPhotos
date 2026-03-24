import AVFoundation
import Photos
import UIKit

enum GalleryViewerShareItem {
    case image(UIImage)
    case videoURL(URL)
}

enum GalleryViewerMediaActionError: LocalizedError {
    case unsupportedMediaType
    case failedToLoadImage
    case failedToLoadVideo
    case unsupportedVideoAsset

    var errorDescription: String? {
        switch self {
        case .unsupportedMediaType:
            return "不支持的媒体类型"
        case .failedToLoadImage:
            return "无法获取图片"
        case .failedToLoadVideo:
            return "无法获取视频"
        case .unsupportedVideoAsset:
            return "无法处理视频资产"
        }
    }
}

protocol GalleryViewerMediaActionHandling {
    func loadShareItem(for asset: PHAsset, completion: @escaping (Result<GalleryViewerShareItem, GalleryViewerMediaActionError>) -> Void)
    func delete(asset: PHAsset, completion: @escaping (Result<Void, Error>) -> Void)
    func toggleFavorite(asset: PHAsset, completion: @escaping (Result<PHAsset, Error>) -> Void)
}

final class GalleryViewerMediaActionService: GalleryViewerMediaActionHandling {
    func loadShareItem(for asset: PHAsset, completion: @escaping (Result<GalleryViewerShareItem, GalleryViewerMediaActionError>) -> Void) {
        switch asset.mediaType {
        case .image:
            loadShareImage(asset: asset, completion: completion)
        case .video:
            loadShareVideo(asset: asset, completion: completion)
        default:
            completion(.failure(.unsupportedMediaType))
        }
    }

    func delete(asset: PHAsset, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? NSError(domain: "GalleryViewerMediaActionService", code: -1)))
                }
            }
        })
    }

    func toggleFavorite(asset: PHAsset, completion: @escaping (Result<PHAsset, Error>) -> Void) {
        PhotoChangesService.toggleFavorite(asset: asset) { success, error in
            DispatchQueue.main.async {
                guard success else {
                    completion(.failure(NSError(
                        domain: "GalleryViewerMediaActionService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: error ?? "无法更新收藏状态"]
                    )))
                    return
                }

                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
                guard let updatedAsset = fetchResult.firstObject else {
                    completion(.failure(NSError(
                        domain: "GalleryViewerMediaActionService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "收藏状态更新后无法读取最新资产"]
                    )))
                    return
                }
                completion(.success(updatedAsset))
            }
        }
    }

    private func loadShareImage(asset: PHAsset, completion: @escaping (Result<GalleryViewerShareItem, GalleryViewerMediaActionError>) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
            DispatchQueue.main.async {
                guard let image else {
                    completion(.failure(.failedToLoadImage))
                    return
                }
                completion(.success(.image(image)))
            }
        }
    }

    private func loadShareVideo(asset: PHAsset, completion: @escaping (Result<GalleryViewerShareItem, GalleryViewerMediaActionError>) -> Void) {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                guard let avAsset else {
                    completion(.failure(.failedToLoadVideo))
                    return
                }
                guard let urlAsset = avAsset as? AVURLAsset else {
                    completion(.failure(.unsupportedVideoAsset))
                    return
                }
                completion(.success(.videoURL(urlAsset.url)))
            }
        }
    }
}

