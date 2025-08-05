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

    func deleteTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.deleteTag(tag)
            
            LocationManager.shared.stopMonitoring(tag: tag)  
            
            fetchTags()
        } catch {
            print("Delete failed: \(error)")
        }
    }
}
