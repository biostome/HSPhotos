//
//  PhotoCollectionStore.swift
//  HSPhotos
//
//  Centralizes the album asset list and its first-level derived view state.
//

import Foundation
import Photos

struct PhotoCollectionSnapshot {
    let assets: [PHAsset]
    let assetIDs: [String]
    let assetByID: [String: PHAsset]
    let visibleAssets: [PHAsset]
    let visibleAssetIDs: [String]
    let filterState: TagFilterState
    let sortPreference: PhotoSortPreference
}

final class PhotoCollectionStore {
    private(set) var snapshot = PhotoCollectionSnapshot(
        assets: [],
        assetIDs: [],
        assetByID: [:],
        visibleAssets: [],
        visibleAssetIDs: [],
        filterState: TagFilterState(),
        sortPreference: .custom
    )

    var assets: [PHAsset] { snapshot.assets }
    var assetIDs: [String] { snapshot.assetIDs }
    var visibleAssets: [PHAsset] { snapshot.visibleAssets }
    var visibleAssetIDs: [String] { snapshot.visibleAssetIDs }
    var filterState: TagFilterState { snapshot.filterState }
    var sortPreference: PhotoSortPreference { snapshot.sortPreference }

    func load(collection: PHAssetCollection, options: PHFetchOptions) -> PhotoCollectionSnapshot {
        let result = PHAsset.fetchAssets(in: collection, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return replaceAssets(assets)
    }

    func replaceAssets(_ assets: [PHAsset]) -> PhotoCollectionSnapshot {
        update(assets: assets, filterState: snapshot.filterState, sortPreference: snapshot.sortPreference)
    }

    func replaceFilterState(_ filterState: TagFilterState) -> PhotoCollectionSnapshot {
        update(assets: snapshot.assets, filterState: filterState, sortPreference: snapshot.sortPreference)
    }

    func replaceSortPreference(_ sortPreference: PhotoSortPreference) -> PhotoCollectionSnapshot {
        update(assets: snapshot.assets, filterState: snapshot.filterState, sortPreference: sortPreference)
    }

    func asset(for id: String) -> PHAsset? {
        snapshot.assetByID[id]
    }

    func assets(for ids: some Sequence<String>) -> [PHAsset] {
        ids.compactMap { snapshot.assetByID[$0] }
    }

    func orderedAssets(for idSet: Set<String>) -> [PHAsset] {
        guard !idSet.isEmpty else { return [] }
        return snapshot.assets.filter { idSet.contains($0.localIdentifier) }
    }

    private func update(
        assets: [PHAsset],
        filterState: TagFilterState,
        sortPreference: PhotoSortPreference
    ) -> PhotoCollectionSnapshot {
        var assetIDs: [String] = []
        var assetByID: [String: PHAsset] = [:]
        assetIDs.reserveCapacity(assets.count)
        assetByID.reserveCapacity(assets.count)
        for asset in assets {
            let id = asset.localIdentifier
            assetIDs.append(id)
            assetByID[id] = asset
        }

        let visibleAssets: [PHAsset]
        if filterState.isActive {
            let matchedIDs = PhotoTagService.shared.filteredIdentifiers(by: filterState)
            visibleAssets = assets.filter { matchedIDs.contains($0.localIdentifier) }
        } else {
            visibleAssets = assets
        }
        let visibleAssetIDs = visibleAssets.map(\.localIdentifier)

        let next = PhotoCollectionSnapshot(
            assets: assets,
            assetIDs: assetIDs,
            assetByID: assetByID,
            visibleAssets: visibleAssets,
            visibleAssetIDs: visibleAssetIDs,
            filterState: filterState,
            sortPreference: sortPreference
        )
        snapshot = next
        return next
    }
}
