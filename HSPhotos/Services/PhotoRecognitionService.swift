//
//  PhotoRecognitionService.swift
//  HSPhotos
//
//  端侧场景分类（Vision VNClassifyImageRequest）。
//  返回英文标签，直接显示。
//

import UIKit
import Vision
import Photos

final class PhotoRecognitionService {
    static let shared = PhotoRecognitionService()
    private init() {}

    // MARK: - 缓存

    private final class CachedLabels {
        let labels: [String]
        init(_ labels: [String]) { self.labels = labels }
    }
    private let classificationCache = NSCache<NSString, CachedLabels>()

    func invalidateAllCache() {
        classificationCache.removeAllObjects()
    }

    // MARK: - 识别入口

    /// 对照片进行场景分类，返回英文标签。
    func classifyAsset(_ asset: PHAsset) async -> [String] {
        let key = asset.localIdentifier as NSString
        if let cached = classificationCache.object(forKey: key)?.labels { return cached }

        guard let data = await loadImageData(asset: asset) else { return [] }

        let request = VNClassifyImageRequest()

        do {
            let handler = VNImageRequestHandler(data: data, orientation: .up, options: [:])
            try handler.perform([request])

            guard let observations = request.results else { return [] }

            let labels = observations
                .filter { $0.confidence > 0.35 }
                .sorted  { $0.confidence > $1.confidence }
                .prefix(4)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

            guard !labels.isEmpty else { return [] }

            classificationCache.setObject(CachedLabels(labels), forKey: key)
            return labels
        } catch {
            return []
        }
    }

    // MARK: - 格式化

    static func formattedSceneText(from labels: [String]) -> String {
        labels.joined(separator: ", ")
    }

    // MARK: - 图片加载

    private func loadImageData(asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
