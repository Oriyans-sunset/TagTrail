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


    override init() {
        super.init()
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
        }
        UNUserNotificationCenter.current().delegate = self

        
        //manager.allowsBackgroundLocationUpdates = true
        //manager.pausesLocationUpdatesAutomatically = true
    }
    
    func configureForActiveMap() {
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.stopMonitoringSignificantLocationChanges()
        manager.startUpdatingLocation()
    }

    func configureForPassiveMode() {
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.stopUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location.coordinate
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
    
    private let geofenceRadius: CLLocationDistance = 100   // metres

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
}
