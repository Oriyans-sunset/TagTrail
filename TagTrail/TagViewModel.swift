//
//  TagViewModel.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-27.
//

import Foundation

@MainActor
class TagViewModel: ObservableObject {
    @Published var tags: [Tag] = []

    /// Flag the UI that a free user attempted to exceed the limit.
    @Published var didHitFreeLimit: Bool = false

    /// Convenience: whether the user can add another tag under the current plan.
    var canAddMore: Bool {
        ProAccessManager.shared.canAddTag(currentCount: tags.count)
    }

    init() {
        fetchTags()
    }

    func fetchTags() {
        do {
            tags = try DatabaseManager.shared.fetchAllTags()
            LocationManager.shared.updateAllTags(tags, force: true)
        } catch {
            print("Fetch failed: \(error)")
        }
    }

    func addTag(_ tag: Tag) {
        // Enforce free plan tag limit at the source of truth
        if !ProAccessManager.shared.canAddTag(currentCount: tags.count) {
            DispatchQueue.main.async {
                self.didHitFreeLimit = true
            }
            return
        }
        do {
            try DatabaseManager.shared.saveTag(tag)
            fetchTags()
        } catch {
            print("Save failed: \(error)")
        }
    }
    
    func updateTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.updateTag(tag)
            fetchTags()
        } catch {
            print("Update failed: \(error)")
        }
    }

    /// Remove image/audio files for non-text tags based on the stored relative content path.
    private func deleteMediaIfNeeded(for tag: Tag) {
        // Only image/voice tags have files on disk
        guard tag.type != .text else { return }
        let fm = FileManager.default
        // Documents/Media + (possibly nested) relative path stored in tag.content
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let mediaRoot = docs.appendingPathComponent("Media", isDirectory: true)
            let fileURL = mediaRoot.appendingPathComponent(tag.content)
            do {
                if fm.fileExists(atPath: fileURL.path) {
                    try fm.removeItem(at: fileURL)
                }
            } catch {
                print("⚠️ Failed to delete media: \(fileURL.path) — \(error)")
            }
        }
    }

    func deleteTag(_ tag: Tag) {
        do {
            // First delete any associated media from disk so we don't orphan files
            deleteMediaIfNeeded(for: tag)
            
            // Then remove the DB record
            try DatabaseManager.shared.deleteTag(tag)
            
            // Stop geofence/monitoring for this tag
            LocationManager.shared.stopMonitoring(tag: tag)
            
            // Refresh local list
            fetchTags()
        } catch {
            print("Delete failed: \(error)")
        }
    }
}
