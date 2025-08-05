//
//  DatabaseManager.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-26.
//

import GRDB
import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()
    var dbQueue: DatabaseQueue!

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let databaseURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("tagtrail.sqlite")

            dbQueue = try DatabaseQueue(path: databaseURL.path)

            try createTables()
        } catch {
            fatalError("Database setup error: \(error)")
        }
    }

    private func createTables() throws {
        try dbQueue.write { db in
            try db.create(table: "tag", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("type", .text).notNull()
                t.column("content", .text).notNull()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("timestamp", .datetime).notNull()
            }
        }
    }
    
    func saveTag(_ tag: Tag) throws {
        try dbQueue.write { db in
            try tag.insert(db)
        }
    }
    
    func fetchAllTags() throws -> [Tag] {
        try dbQueue.read { db in
            try Tag.fetchAll(db)
        }
    }
    
    func deleteTag(_ tag: Tag) throws {
        try dbQueue.write { db in
            try tag.delete(db)
        }
    }
    
    func updateTag(_ tag: Tag) throws {
        try dbQueue.write { db in
            try tag.update(db)
        }
    }
}
