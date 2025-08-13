//
//  ContentView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-25.
//

import AVFoundation
import MapKit
import PhotosUI
import SwiftUI
import UIKit
import RevenueCat
import UserNotifications

// MARK: - Pro Access Manager
final class ProAccessManager: ObservableObject {
    static let shared = ProAccessManager()
    @Published var isPro: Bool = false
    let freeTagLimit: Int = 10

    func canAddTag(currentCount: Int) -> Bool {
        return isPro || currentCount < freeTagLimit
    }

    /// Refresh entitlement from RevenueCat and publish the result
    func refresh() {
        Purchases.shared.getCustomerInfo { info, _ in
            let active = info?.entitlements["pro"]?.isActive == true
            DispatchQueue.main.async {
                self.isPro = active
            }
        }
    }
}

enum Route: Hashable {
    case settings
}

enum TagSortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case titleAZ = "Title A–Z"
    case titleZA = "Title Z–A"
    case type = "Type"
}

struct ContentView: View {
    @State private var selectedTag: Tag? = nil
    @State private var isShowingBottomSheet = false
    @State private var isShowingAddTagView = false
    @StateObject private var viewModel = TagViewModel()

    @StateObject private var locationManager = LocationManager.shared
    @AppStorage("alwaysBannerDismissed") private var alwaysBannerDismissed: Bool = false
    @State private var showAlwaysBanner = false
    @State private var currentAuth: CLAuthorizationStatus = .notDetermined
    @State private var previousAuth: CLAuthorizationStatus = .notDetermined
    
    @State private var path = NavigationPath()
    @State private var isShowingSettings = false
    
    @Environment(\.scenePhase) private var scenePhase

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var headerOpacity = 0.0
    @State private var followUser = true
    // MARK: - Map Recenter Throttle
    @State private var lastCenterUpdate: Date = .distantPast
    @State private var lastCenterCoord: CLLocationCoordinate2D? = nil

    @AppStorage("locationOnboardingDeferred") private var locationOnboardingDeferred: Bool = false
    @State private var showLocationNotice: Bool = false
    @State private var locationLimited: Bool = false
    
    @AppStorage("tagSortOption") private var tagSortRaw: String = TagSortOption.newest.rawValue

    // --- Paywall state for free limit ---
    @State private var showPaywallFromLimit = false
    @State private var isProActiveForSheet = ProAccessManager.shared.isPro

    @State private var notificationsAllOff: Bool = false
    @State private var showNotificationsNotice: Bool = false

    private var sortOption: TagSortOption {
        get { TagSortOption(rawValue: tagSortRaw) ?? .newest }
        set { tagSortRaw = newValue.rawValue }
    }

    private var sortedTags: [Tag] {
        switch sortOption {
        case .newest:
            return viewModel.tags.sorted { $0.timestamp > $1.timestamp }
        case .oldest:
            return viewModel.tags.sorted { $0.timestamp < $1.timestamp }
        case .titleAZ:
            return viewModel.tags.sorted { $0.title.localizedLowercase < $1.title.localizedLowercase }
        case .titleZA:
            return viewModel.tags.sorted { $0.title.localizedLowercase > $1.title.localizedLowercase }
        case .type:
            return viewModel.tags.sorted { $0.type.rawValue < $1.type.rawValue }
        }
    }

    var body: some View {
        NavigationStack(path: $path){
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        .blue, Color(UIColor.systemBackground),
                    ]),
                    startPoint: .top,
                    endPoint: .center
                )
                .opacity(headerOpacity)
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5)) {
                        headerOpacity = 1.0
                    }
                }
                
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("TagTrail")
                            .font(.title)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundColor(Color.black)
                            .shadow(radius: 1)
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)

                        Spacer()

                        if locationLimited {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                // If While‑In‑Use and the banner hasn't been dismissed yet, show it. Otherwise show the generic notice.
                                if currentAuth == .authorizedWhenInUse {
                                    showAlwaysBanner = true
                                } else {
                                    showLocationNotice = true
                                }
                            } label: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                            }
                            .padding(.trailing, 6)
                        }

                        if notificationsAllOff {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showNotificationsNotice = true
                            } label: {
                                Image(systemName: "bell.slash.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                            }
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: {
                            // take to settings page
                            path.append(Route.settings)
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.black)
                        }
                    }.padding(.horizontal)
                    
                    Map(
                        coordinateRegion: $region,
                        interactionModes: [.pan, .zoom],
                        showsUserLocation: false,
                        annotationItems: viewModel.tags,
                        annotationContent: { tag in
                            MapAnnotation(coordinate: tag.coordinate) {
                                Button {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    selectedTag = tag
                                } label: {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title)
                                        .foregroundColor(Color(hex: tag.colorHex) ?? .red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    )
                    .gesture(DragGesture().onChanged { _ in followUser = false })
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            .shadow(radius: 4)
                    )
                    .padding()
                    .overlay(alignment: .bottomTrailing) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            recenter()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.body)
                                .foregroundColor(Color(.systemGray6))
                                .padding(8)
                                .background(
                                    Color.gray.opacity(0.9),
                                    in: Rectangle()
                                )
                                .cornerRadius(20)
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 22)
                        .padding(.bottom, 22)
                        .zIndex(1)
                    }
                    
                    TagListView(tags: sortedTags) { tag in
                        recenter(on: tag)
                        selectedTag = tag
                    }
                    .frame(maxHeight: .infinity)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if viewModel.canAddMore {
                                // Show tag creation modal
                                isShowingAddTagView = true
                            } else {
                                // At limit: present paywall instead of disabling
                                showPaywallFromLimit = true
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                                .shadow(color: Color.red, radius: 2)
                        }
                        .padding()
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:
                    SettingsView()
                }
            }
        } // battery optimization
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .inactive, .background:
                // App is going away → drop to low power
                LocationManager.shared.configureForPassiveMode()

            case .active:
                // Don't force high-power here; ContentView.onAppear handles it.
                // Keep any lightweight refresh you truly need:
                LocationManager.shared.updateAllTags(viewModel.tags, force: true)

            @unknown default:
                break
            }
        }
        // center the map to users current position on first launch
        .onAppear {
            LocationManager.shared.configureForActiveMap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let currentLocation = locationManager.currentLocation {
                    region = MKCoordinateRegion(
                        center: currentLocation,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.01,
                            longitudeDelta: 0.01
                        )
                    )
                }
                refreshNotificationStatus()
                refreshLocationStatus()
            }
        }
        .onDisappear {
            LocationManager.shared.configureForPassiveMode()
        }
        // update map region when currentLocation changes
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { loc in
            guard followUser else { return }

            let now = Date()
            let minInterval: TimeInterval = 5.0          // update at most every 5s
            let minMove: CLLocationDistance = 30.0       // and only if moved > 30 m

            let movedFarEnough: Bool = {
                guard let last = lastCenterCoord else { return true }
                let d = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
                return d > minMove
            }()

            guard movedFarEnough, now.timeIntervalSince(lastCenterUpdate) > minInterval else { return }

            lastCenterUpdate = now
            lastCenterCoord = loc

            // Keep animation subtle to avoid GPU churn
            updateRegionIfNeeded(loc, minMove: 50, animated: true)
        }
        .onChange(of: locationManager.authorizationStatus) { newStatus in
            refreshLocationStatus()
        }
        .sheet(item: $selectedTag) { tag in
            TagDetailView(tag: tag, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAddTagView) {
            AddTagView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPaywallFromLimit) {
            PaywallView(isPresented: $showPaywallFromLimit, isProActive: $isProActiveForSheet)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    (locationManager.authorizationStatus == .denied
                     || locationManager.authorizationStatus == .notDetermined)
                    && !locationOnboardingDeferred
                },
                set: { _ in }
            )
        ) {
            VStack(spacing: 16) {
                // Friendly icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "location")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
                
                // Warm headline & subcopy
                Text("Let TagTrail see where you are")
                    .font(.title2).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("To drop tags at your current spot and show them on the map, TagTrail needs permission to use your location while you’re using the app.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Why 'While In Use' explainer
                DisclosureGroup("Why allow location?") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("See your current position on the map.")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Quickly add tags to exactly where you’re standing.")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Makes your saved tags more accurate and useful.")
                        }
                    }
                    .padding(.top, 4)
                }
                .tint(.blue)
                .padding(.horizontal)
                
                Spacer()

                MascotFaceView(color: .blue)
                
                Spacer(minLength: 8)
                
                // Single positive CTA
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let status = CLLocationManager.authorizationStatus()
                    if status == .denied || status == .restricted {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings)
                        }
                    } else {
                        LocationManager.shared.requestWhenInUse()
                    }
                } label: {
                    Text("Allow location access")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    locationOnboardingDeferred = true // dismisses the sheet via binding
                } label: {
                    Text("Not now")
                        .underline()
                        .foregroundColor(.secondary)
                }
                .padding(.top, 6)
            }
            .padding()
            .onDisappear {
                refreshLocationStatus()
            }
        }
        .fullScreenCover(isPresented: $showAlwaysBanner) {
            VStack(spacing: 16) {
                // Friendly icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "location.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.top, 8)

                // Warm headline & subcopy
                Text("Keep TagTrail working in the background")
                    .font(.title2).fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("To ping you when you’re near a saved place, TagTrail needs **Always Allow** location access. You can change this anytime in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                // Why 'Always' explainer
                DisclosureGroup("Why ‘Always’?") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Sends reminders even if the app is closed.")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Uses low‑power background updates — not constant GPS.")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("You’re in control and can switch it off anytime.")
                        }
                    }
                    .padding(.top, 4)
                }
                .tint(.red)
                .padding(.horizontal)

                Spacer()

                MascotFaceView(color: .red)

                Spacer(minLength: 8)

                // Single positive CTA
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings)
                    }
                } label: {
                    Text("Turn on background reminders")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    alwaysBannerDismissed = true
                    showAlwaysBanner = false // dismiss the sheet
                } label: {
                    Text("Not now")
                        .underline()
                        .foregroundColor(.secondary)
                }
                .padding(.top, 6)
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationStatus()
            refreshLocationStatus()
        }
        .alert("Location is limited", isPresented: $showLocationNotice) {
            Button("Open Settings") {
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Without location access while using the app, TagTrail can’t show your current position, drop tags at your exact spot, or recenter the map.")
        }
        .alert("Notifications are off", isPresented: $showNotificationsNotice) {
            Button("Open Settings") {
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("To get tag reminders and alerts, enable at least one notification type (Alerts, Sounds, or Badges) for TagTrail in Settings.")
        }
        .onChange(of: viewModel.didHitFreeLimit) { hit in
            if hit {
                showPaywallFromLimit = true
                viewModel.didHitFreeLimit = false
            }
        }
    }
    /// Only recenter the map if the user actually moved a meaningful distance
    private func updateRegionIfNeeded(_ newCenter: CLLocationCoordinate2D,
                                      minMove: CLLocationDistance = 50,
                                      animated: Bool = true) {
        let cur = region.center
        let d = CLLocation(latitude: cur.latitude, longitude: cur.longitude)
            .distance(from: CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude))

        guard d >= minMove else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                region.center = newCenter
            }
        } else {
            region.center = newCenter
        }
    }
    
    // recenter on tag
    private func recenter(on tag: Tag) {
        followUser = false              // stop auto-follow so user can explore
        withAnimation(.easeInOut) {
            region.center = tag.coordinate
        }
    }

    // recenter on user current location helper
    private func recenter() {
        followUser = true
        if let loc = locationManager.currentLocation {
            withAnimation(.easeInOut) {
                region.center = loc  // just move the center
            }
        }
    }

    // Refresh location status helper (mirrors notifications pattern)
    private func refreshLocationStatus() {
        let status = CLLocationManager.authorizationStatus()
        currentAuth = status

        // Drive the header danger icon
        locationLimited = (status != .authorizedAlways)

        // Decide when to surface the "Always" banner
        if previousAuth == .notDetermined && status == .authorizedWhenInUse && !alwaysBannerDismissed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showAlwaysBanner = true
            }
        } else {
            showAlwaysBanner = (status == .authorizedWhenInUse && !alwaysBannerDismissed)
        }

        // Clear onboarding cover once user has decided
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationOnboardingDeferred = false
        }

        previousAuth = status
    }

    // Refresh notification status helper
    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let granted = (settings.authorizationStatus == .authorized
                           || settings.authorizationStatus == .provisional
                           || settings.authorizationStatus == .ephemeral)
            let anyEnabled = (settings.alertSetting == .enabled
                              || settings.badgeSetting == .enabled
                              || settings.soundSetting == .enabled
                              || settings.criticalAlertSetting == .enabled)
            // Show bell iff NOT (granted AND anyEnabled)
            let allOff = !(granted && anyEnabled)
            DispatchQueue.main.async {
                self.notificationsAllOff = allOff
            }
        }
    }
}

// Listen for foreground notification to refresh notification status
extension ContentView {
    // Add to body via view modifier
    func addNotificationRefresh() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshNotificationStatus()
        }
    }
}

// Add the .onReceive at the ContentView level (not in Preview)
extension View {
    func contentViewNotificationRefresh(_ refresh: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refresh()
        }
    }
}

struct AddTagView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TagViewModel
    @AppStorage("defaultTagColorHex") private var defaultTagColorHex: String = "#FF9500"

    @StateObject private var locationManager = LocationManager.shared

    // MARK: - Geocoding Throttle
    @State private var lastGeocodeCoord: CLLocationCoordinate2D?
    @State private var lastGeocodeTime: Date = .distantPast
    private let geocoder = CLGeocoder()

    // MARK: - Smart Suggestion Model
    private struct SmartSuggestion: Equatable {
        let title: String
        let content: String
        let tagType: TagType
        let hint: String    // short sentence shown to the user
    }

    @State private var selectedTagType: TagType = .text

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isAnimating = false

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var chosenCoordinate: CLLocationCoordinate2D? = nil
    @State private var chosenPlacename: String? = nil
    @State private var isShowingLocationPicker = false
    
    @State private var tagColor: Color = {
        let hex = UserDefaults.standard.string(forKey: "defaultTagColorHex") ?? "#FF9500"
        return Color(hex: hex) ?? .orange
    }()

    @State private var smartSuggestion: SmartSuggestion? = nil

    // MARK: - Free palette (non‑Pro users)
    private let freePaletteHex: [String] = ["#0A84FF", "#34C759", "#FF9500"] // blue, green, orange
    private var freePalette: [Color] { freePaletteHex.compactMap { Color(hex: $0) } }

    // MARK: - RevenueCat Pro
    @State private var isProActive: Bool = false
    @State private var showPaywall: Bool = false
    @ObservedObject private var pro = ProAccessManager.shared


    // MARK: - Smart Suggestion Helper
    private func updateSmartSuggestion(for coord: CLLocationCoordinate2D) {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

        geocoder.reverseGeocodeLocation(loc, preferredLocale: nil) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }

            let reference = (placemark.areasOfInterest?.first ??
                             placemark.name ??
                             "").lowercased()

            let today = Date().formatted(date: .abbreviated, time: .omitted)

            if reference.contains("gym") || reference.contains("fitness") {
                smartSuggestion = SmartSuggestion(
                    title: "Gym Workout - \(today)",
                    content: "sets / reps / weight:\n• Bench Press –  _ × _ @ _kg\n• Incline DB Fly –  _ × _ @ _kg\n• Push-ups –  _ reps",
                    tagType: .text,
                    hint: "Looks like you’re at the gym."
                )
            } else if reference.contains("restaurant") ||
                      reference.contains("cafe") ||
                      reference.contains("diner") {
                smartSuggestion = SmartSuggestion(
                    title: "Meal Note - \(today)",
                    content: "What I ordered:\n• Dish:\n• Drink:\n\nRating ( / 5 ⭐️ ): ",
                    tagType: .text,
                    hint: "Enjoying a meal?"
                )
            } else if reference.contains("school") ||
                      reference.contains("university") ||
                      reference.contains("college") {
                smartSuggestion = SmartSuggestion(
                    title: "Study Note - \(today)",
                    content: "Lecture / Topic:\nKey concepts:\n• \n• \nNext steps:\n• Review slides\n• Practice problems",
                    tagType: .text,
                    hint: "You're on campus."
                )
            } else if reference.contains("pharmacy") ||
                      reference.contains("drug") ||
                      reference.contains("drugstore") {
                smartSuggestion = SmartSuggestion(
                    title: "Pharmacy List - \(today)",
                    content: "Prescription(s):\n• \n\nOver-the-counter:\n• ",
                    tagType: .text,
                    hint: "Picking something up at the pharmacy?"
                )
            } else if reference.contains("airport") ||
                      reference.contains("terminal") ||
                      reference.contains("gate") {
                smartSuggestion = SmartSuggestion(
                    title: "Travel Note - \(today)",
                    content: "Flight: \nCarrier: \nGate: \nDeparture: \nDestination: ",
                    tagType: .text,
                    hint: "At the airport—log your flight details?"
                )
            } else if reference.contains("office") ||
                      reference.contains("corporate") ||
                      reference.contains("business") ||
                      reference.contains("work") {
                smartSuggestion = SmartSuggestion(
                    title: "Work Note - \(today)",
                    content: "Tasks:\n• \n• \n\nNext steps:\n• ",
                    tagType: .text,
                    hint: "At work—quick task note?"
                )
            } else {
                smartSuggestion = nil
            }
        }
    }

    /// Debounced geocoding wrapper to avoid excessive background work
    private func safeUpdateSmartSuggestion(for coord: CLLocationCoordinate2D) {
        let now = Date()
        let minInterval: TimeInterval = 60         // at least 60s between geocodes
        let minMove: CLLocationDistance = 100      // at least 100m movement

        let movedEnough: Bool = {
            guard let last = lastGeocodeCoord else { return true }
            let d = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            return d >= minMove
        }()

        guard movedEnough, now.timeIntervalSince(lastGeocodeTime) >= minInterval else { return }

        lastGeocodeCoord = coord
        lastGeocodeTime = now

        // Cancel any in-flight geocode before starting a new one
        geocoder.cancelGeocode()
        updateSmartSuggestion(for: coord)
    }

    // MARK: - RevenueCat Helper
    private func refreshProStatus() {
        ProAccessManager.shared.refresh()
    }

    private func tagColorMatches(_ color: Color) -> Bool {
        // Compare using hex strings to avoid dynamic color equality issues
        let current = tagColor.toHex()?.lowercased()
        let target = color.toHex()?.lowercased()
        return current == target
    }

    var body: some View {
        NavigationView {
            Form {
                // Smart Suggestion UI
                if let suggestion = smartSuggestion {
                    HStack() {
                        Label {
                            VStack(alignment: .leading){
                                Text("🧠Smart suggestion")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.gray)
                                Text(suggestion.hint)
                                    .font(.subheadline.weight(.semibold))
                            }
                            
                        } icon: {
                            Image(systemName: "lightulb") // TO REMOVE
                                .foregroundColor(.red)
                        }
                        .labelStyle(.titleAndIcon)

                        Spacer()

                        Button("Auto‑fill") {
                            UISelectionFeedbackGenerator().selectionChanged()
                            title = suggestion.title
                            content = suggestion.content
                            selectedTagType = suggestion.tagType
                            withAnimation(.easeInOut) {
                                smartSuggestion = nil
                            }
                        }
                        .buttonStyle(.bordered)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut) {
                                smartSuggestion = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                        
                    }
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: smartSuggestion)
                }

                Section(header: Text("Tag Title")) {
                    TextField("Enter title", text: $title)
                    if isProActive {
                        ColorPicker("Tag Color", selection: $tagColor, supportsOpacity: false)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tag Color")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ForEach(Array(freePalette.enumerated()), id: \.offset) { _, swatch in
                                    Button {
                                        tagColor = swatch
                                    } label: {
                                        Circle()
                                            .fill(swatch)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary.opacity(tagColorMatches(swatch) ? 0.8 : 0.15), lineWidth: tagColorMatches(swatch) ? 2 : 1)
                                            )
                                            .shadow(radius: tagColorMatches(swatch) ? 2 : 0)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Spacer()

                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                        Text("More colors")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }

                            Text("Free plan includes 3 colours. Unlock Pro for full picker.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section(header: Text("Tag Location")) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = chosenPlacename {
                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text({ () -> String in
                                if let c = chosenCoordinate {
                                    return String(format: "%.5f, %.5f", c.latitude, c.longitude)
                                } else if let cur = locationManager.currentLocation {
                                    return String(format: "Current: %.5f, %.5f", cur.latitude, cur.longitude)
                                } else {
                                    return "Will use your current location"
                                }
                            }())
                            .foregroundColor(.secondary)
                            .font(.caption)
                        }
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isShowingLocationPicker = true
                        } label: {
                            Text(chosenCoordinate == nil ? "Choose on Map" : "Change")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section(header: Text("Tag Type")) {
                    Picker("Tag Type", selection: $selectedTagType) {
                        Label("Text", systemImage: "text.bubble.fill").tag(TagType.text)
                        Label("Image", systemImage: "photo").tag(TagType.image)
                        Label(isProActive ? "Voice" : "Voice (Pro)", systemImage: isProActive ? "waveform" : "lock.fill").tag(TagType.voice)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedTagType) { newType in
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()

                        // Clear smart suggestion if type changes
                        if let suggestion = smartSuggestion, suggestion.tagType != newType {
                            withAnimation(.easeInOut) { smartSuggestion = nil }
                        }

                        // Paywall gate for Voice if Pro not active
                        if newType == .voice && !pro.isPro {
                            selectedTagType = .text
                            showPaywall = true
                        }
                    }
                    
                    if selectedTagType == .text {
                        HStack(spacing: 12) {
                            Spacer()

                            Menu("Templates") {
                                Button("📋To-Do List") {
                                    content = "- [ ] Item 1\n- [ ] Item 2"
                                }
                                Button("🧠Brain Dump") {
                                    content = "Thoughts:\n\n... "
                                }
                                Button("📝Quick Note") {
                                    content = "- Remember to..."
                                }
                            }
                            
                        }
                        .padding(.bottom, 4)

                        TextField(
                            "Enter text",
                            text: $content,
                            axis: .vertical
                        )
                        .lineLimit(5...10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    if selectedTagType == .image {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Text("Pick a Photo")
                        }
                        if let selectedImageData,
                            let uiImage = UIImage(data: selectedImageData)
                        {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        }
                    }

                    if selectedTagType == .voice {
                        if isProActive {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Button(action: {
                                        if audioRecorder.isRecording {
                                            audioRecorder.stopRecording()
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                            // Store relative path including Audio/ subfolder so we can rebuild later
                                            content = "Audio/" + audioRecorder.getRecordingURL().lastPathComponent
                                            isAnimating = false
                                        } else {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            audioRecorder.startRecording()
                                            isAnimating = true
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red.opacity(0.2))
                                                .frame(width: 70, height: 70)

                                            if audioRecorder.isRecording {
                                                RealWaveform(
                                                    level: $audioRecorder
                                                        .waveformLevel
                                                )
                                            } else {
                                                Image(systemName: "mic.fill")
                                                    .foregroundColor(.white)
                                                    .font(.title)
                                            }
                                        }
                                    }

                                    Text(audioRecorder.statusMessage)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 4)
                                }
                                Spacer()
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "lock.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Voice tags are a Pro feature.")
                                    .font(.headline)
                                Button("Unlock Pro") {
                                    showPaywall = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                Button("Save Tag") {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    let newTag = Tag(
                        title: title,
                        type: selectedTagType,
                        content: content,
                        coordinate: chosenCoordinate
                            ?? locationManager.currentLocation
                            ?? CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938),
                        timestamp: Date(),
                        colorHex: tagColor.toHex() ?? "#FF9500"
                    )
                    print("🎨 TAG ABOUT TO SAVE:", tagColor.toHex() as Any)
                    print("📄 NEW TAG COLORHEX:", newTag.colorHex)
                    viewModel.addTag(newTag)
                    dismiss()
                }
                .disabled(
                    title.isEmpty || content.isEmpty || audioRecorder.isRecording || (selectedTagType == .voice && !isProActive) || !viewModel.canAddMore
                )
                if !viewModel.canAddMore {
                    Text("Free limit reached (10). Upgrade to add more.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add New Tag📍")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(
                        type: Data.self
                    ) {
                        selectedImageData = data
                        if let filename = UUID().uuidString
                            .addingPercentEncoding(
                                withAllowedCharacters: .alphanumerics
                            )
                        {
                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
                            try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

                            let fileName = "\(UUID().uuidString).jpg"      // store *just* this
                            let url = mediaDir.appendingPathComponent(fileName)
                            try? data.write(to: url)

                            content = fileName
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
            }
            .onAppear {
                if let coord = locationManager.currentLocation {
                    safeUpdateSmartSuggestion(for: coord)
                }
                refreshProStatus()
                isProActive = pro.isPro
                if !isProActive {
                    // If current color isn’t in the free palette, default to first free color
                    let currentHex = tagColor.toHex()?.lowercased()
                    let allowed = Set(freePaletteHex.map { $0.lowercased() })
                    if currentHex == nil || !allowed.contains(currentHex!) {
                        if let first = freePalette.first { tagColor = first }
                    }
                }
            }
            .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
                safeUpdateSmartSuggestion(for: coord)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshProStatus()
            }
            .onReceive(pro.$isPro) { newValue in
                isProActive = newValue
            }
            .sheet(isPresented: $isShowingLocationPicker) {
                LocationPickerView(initialCoordinate: locationManager.currentLocation) { coord, name in
                    chosenCoordinate = coord
                    chosenPlacename = name
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(isPresented: $showPaywall, isProActive: $isProActive)
            }
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - RevenueCat Paywall
struct PaywallView: View {
    @Binding var isPresented: Bool
    @Binding var isProActive: Bool

    @State private var offerings: Offerings?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            // Subtle background to separate the sheet
            LinearGradient(
                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color(.systemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // --- Add colorful background blobs ---
            Circle()
                .fill(Color.blue.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: 140, y: -180)

            Circle()
                .fill(Color.purple.opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: -160, y: 220)

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                // Card
                VStack(spacing: 18) {
                    // Icon badge with overlay ring and glow
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle().stroke(Color.blue.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: .blue.opacity(0.25), radius: 10, x: 0, y: 4)

                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 42)
                    }
                    .padding(.top, 6)

                    // Title & subtitle
                    VStack(spacing: 6) {
                        Text("TagTrail Pro")
                            .font(.system(.largeTitle, design: .rounded)).bold()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.yellow)

                        Text("Unlock Unlimited Tagging, Voice Tags, and Custom Colours — Forever.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // --- Quirky feature chips under subtitle ---
                    HStack(spacing: 8) {
                        Text("🏷️ Tags")
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(.ultraThinMaterial))

                        Text("🎙️ Voice")
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))

                        Text("🎨 Colors")
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }

                    // Feature capsule list
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Unlimited tags", systemImage: "infinity")
                        Label("Voice tags", systemImage: "waveform")
                        Label("All colours", systemImage: "paintpalette")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .tint(.blue)

                    // Dynamic buy options
                    Group {
                        if let offerings = offerings,
                           let current = offerings.current,
                           !current.availablePackages.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(current.availablePackages, id: \.identifier) { pkg in
                                    Button {
                                        purchase(pkg)
                                    } label: {
                                        HStack {
                                            Text(buttonTitle(for: pkg))
                                                .font(.headline).fontDesign(.rounded)
                                            Spacer()
                                            Text(pkg.storeProduct.localizedPriceString)
                                                .font(.headline).fontWeight(.bold)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        )
                                        .foregroundColor(.white)
                                        .shadow(color: Color.blue.opacity(0.28), radius: 14, x: 0, y: 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text(errorMessage ?? "Loading purchase options…")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                    }

                    // --- Friendly guarantee line above Restore ---
                    Text("One‑time purchase. No subscription.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    // Restore
                    Button {
                        restore()
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                )
                .padding(.horizontal)

                // Secondary dismiss
                Button("Not now") {
                    isPresented = false
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
                Spacer(minLength: 0)
            }
        }
        .onAppear(perform: loadOfferings)
    }

    private func loadOfferings() {
        isLoading = true
        errorMessage = nil
        Purchases.shared.getOfferings { newOfferings, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            }
            offerings = newOfferings
        }
    }

    private func purchase(_ package: Package) {
        isLoading = true
        Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
            isLoading = false
            if let error = error, !userCancelled {
                errorMessage = error.localizedDescription
            }
            if let info = customerInfo {
                let active = info.entitlements["pro"]?.isActive == true
                isProActive = active
                ProAccessManager.shared.isPro = active
                if active { isPresented = false }
            }
        }
    }

    private func restore() {
        isLoading = true
        Purchases.shared.restorePurchases { customerInfo, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            }
            if let info = customerInfo {
                let active = info.entitlements["pro"]?.isActive == true
                isProActive = active
                ProAccessManager.shared.isPro = active
                if active { isPresented = false }
            }
        }
    }

    private func buttonTitle(for package: Package) -> String {
        if let period = package.storeProduct.subscriptionPeriod {
            switch period.unit {
            case .year: return "Unlock Pro — Annual"
            case .month: return "Unlock Pro — Monthly"
            case .week: return "Unlock Pro — Weekly"
            case .day: return "Unlock Pro — Daily"
            @unknown default: return "Unlock Pro"
            }
        }
        return "Unlock Pro — One‑Time Purchase"
    }
}

