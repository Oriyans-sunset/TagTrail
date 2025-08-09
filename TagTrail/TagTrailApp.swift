//
//  TagTrailApp.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-25.
//

import SwiftUI
import UIKit

// MARK: - AppDelegate for background location relaunch
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // If iOS relaunched us for a location event (region/SLC), rehydrate and refresh monitored set
        if launchOptions?[.location] != nil {
            let tags = (try? DatabaseManager.shared.fetchAllTags()) ?? []
            LocationManager.shared.updateAllTags(tags, force: true)
        }
        return true
    }
}

@main
struct TagTrailApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
