//
//  LocationManager.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-28.
//

import Foundation
import CoreLocation
import UserNotifications

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Keep lightweight tag info so we can craft specific notifications
    private var tagIndex: [String: Tag] = [:] // key = tag.id.uuidString

    // Dynamic monitoring (Apple enforces ~20 monitored regions per app)
    private let monitoredLimit: Int = 20
    private let refreshDistanceMeters: CLLocationDistance = 150
    private var lastRefreshCoordinate: CLLocationCoordinate2D? = nil
    private var allTagsCache: [Tag] = []
    override init() {
        super.init()
        manager.delegate = self
        // Default to a low‑power passive configuration; we'll switch to active when the map is on screen
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 30                    // only deliver updates when moving > 30 m
        manager.activityType = .other                  // general usage
        manager.pausesLocationUpdatesAutomatically = true
        manager.allowsBackgroundLocationUpdates = false
        //manager.requestAlwaysAuthorization()
        // In passive mode, significant‑change + visits are extremely low power and good enough to refresh geofences
        manager.startMonitoringSignificantLocationChanges()
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            // Visits are coalesced entry/exit at places; very cheap background signal for reminders
            manager.startMonitoringVisits()
        }
        
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
        }
        UNUserNotificationCenter.current().delegate = self

        
        //manager.allowsBackgroundLocationUpdates = true
        //manager.pausesLocationUpdatesAutomatically = true
    }
    
    @MainActor
    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    @MainActor
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }
    
    func configureForActiveMap() {
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .otherNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.stopMonitoringSignificantLocationChanges()
        manager.startUpdatingLocation()
    }

    func configureForPassiveMode() {
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .other
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.stopUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    /// Update the complete list of tags; call this when tags are added/edited/deleted
    /// - Parameters:
    ///   - tags: all tags in the database
    ///   - force: set true to force an immediate refresh of monitored regions
    func updateAllTags(_ tags: [Tag], force: Bool = false) {
        allTagsCache = tags
        if force { refreshMonitoredRegions() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLocation = location.coordinate

            // Refresh the monitored set when we've moved enough (or first fix)
            if let last = self.lastRefreshCoordinate {
                let d = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                if d >= self.refreshDistanceMeters {
                    self.lastRefreshCoordinate = location.coordinate
                    self.refreshMonitoredRegions()
                }
            } else {
                self.lastRefreshCoordinate = location.coordinate
                self.refreshMonitoredRegions()
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                // Ensure passive mode is running by default; UI may switch to active map as needed
                self.configureForPassiveMode()
            default:
                break
            }
        }
    }
    
    private let geofenceRadius: CLLocationDistance = 100   // metres

    /// Select up to `monitoredLimit` tags (nearest to current location if available) and ensure only those are monitored
    private func refreshMonitoredRegions() {
        let desiredTags: [Tag]
        if let here = currentLocation {
            let me = CLLocation(latitude: here.latitude, longitude: here.longitude)
            desiredTags = Array(allTagsCache.sorted { a, b in
                let da = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude).distance(from: me)
                let db = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude).distance(from: me)
                return da < db
            }.prefix(monitoredLimit))
        } else {
            // No fix yet: fall back to most recent
            desiredTags = Array(allTagsCache.sorted { $0.timestamp > $1.timestamp }.prefix(monitoredLimit))
        }
        setMonitoredTags(desiredTags)
    }

    /// Start/stop regions so the monitored set exactly matches `tags`
    private func setMonitoredTags(_ tags: [Tag]) {
        let desiredIDs = Set(tags.map { $0.id.uuidString })
        let currentRegions = manager.monitoredRegions
        let currentIDs = Set(currentRegions.map { $0.identifier })

        // Stop any regions not desired
        for region in currentRegions where !desiredIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
            tagIndex.removeValue(forKey: region.identifier)
        }
        // Start any missing regions
        for tag in tags where !currentIDs.contains(tag.id.uuidString) {
            startMonitoring(tag: tag)
        }
    }

    /// Register a geofence for a tag
    func startMonitoring(tag: Tag) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        
        let region = CLCircularRegion(
            center: tag.coordinate,
            radius: geofenceRadius,
            identifier: tag.id.uuidString
        )
        
        region.notifyOnEntry = true
        
        stopMonitoring(tag: tag) // make sure we don't have a duplicate
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }
    
    /// Stop monitoring and remove the geofence for a tag
    func stopMonitoring(tag: Tag) {
        for region in manager.monitoredRegions {
            if region.identifier == tag.id.uuidString {
                manager.stopMonitoring(for: region)
                break
            }
        }
    }

    /// Notification when the user enters a tag region
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }

        let content = UNMutableNotificationContent()
        content.title = "You’re near a saved tag!"
        content.body  = "Open TagTrail to see what you left here."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: region.identifier,
            content: content,
            trigger: nil      // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { err in
        }
    }
    // Display notifications while app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // When the location is temporarily unavailable, avoid tight restart loops
        if let clErr = error as? CLError, clErr.code == .locationUnknown {
            return
        }
        // If denied/restricted, stop high‑power updates
        if let clErr = error as? CLError, clErr.code == .denied {
            manager.stopUpdatingLocation()
            manager.stopMonitoringSignificantLocationChanges()
        }
    }
}
