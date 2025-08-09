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

    init() {
        fetchTags()
    }

    func fetchTags() {
        do {
            tags = try DatabaseManager.shared.fetchAllTags()
            
            for tag in tags {
                LocationManager.shared.startMonitoring(tag: tag)
            }
        } catch {
            print("Fetch failed: \(error)")
        }
    }

    func addTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.saveTag(tag)
            
            LocationManager.shared.startMonitoring(tag: tag)
            
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
