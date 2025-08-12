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

    @StateObject private var locationManager = LocationManager()
    @State private var isPermissionLimited = false
    
    @State private var path = NavigationPath()
    @State private var isShowingSettings = false
    
    @Environment(\.scenePhase) private var scenePhase

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var headerOpacity = 0.0
    @State private var followUser = true

    @AppStorage("locationOnboardingDeferred") private var locationOnboardingDeferred: Bool = false
    @State private var showLocationNotice: Bool = false
    
    @AppStorage("tagSortOption") private var tagSortRaw: String = TagSortOption.newest.rawValue

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

                        if locationOnboardingDeferred {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showLocationNotice = true
                            } label: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
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
                            // Show tag creation modal
                            isShowingAddTagView = true
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
            if phase == .active {
                LocationManager.shared.configureForActiveMap()
                LocationManager.shared.updateAllTags(viewModel.tags, force: true)
            } else if phase == .background {
                LocationManager.shared.configureForPassiveMode()
            }
        }
        // center the map to users current position on first launch
        .onAppear {
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
            }
        }
        // update map region when currentLocation changes
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { loc in
            guard followUser else { return }
            withAnimation(.easeInOut) {
                region.center = loc
            }
        }
        .onChange(of: locationManager.authorizationStatus) { newStatus in
            if newStatus == .authorizedWhenInUse {
                isPermissionLimited = true
            } else {
                isPermissionLimited = false
            }
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationOnboardingDeferred = false
            }
        }
        .sheet(item: $selectedTag) { tag in
            TagDetailView(tag: tag, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAddTagView) {
            AddTagView(viewModel: viewModel)
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
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings)
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
        }
        .fullScreenCover(isPresented: $isPermissionLimited) {
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
            }
            .padding()
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
}

struct AddTagView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TagViewModel
    @AppStorage("defaultTagColorHex") private var defaultTagColorHex: String = "#FF9500"

    @StateObject private var locationManager = LocationManager()

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

    // MARK: - Smart Suggestion Helper
    private func updateSmartSuggestion(for coord: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
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
                    ColorPicker("Tag Color", selection: $tagColor, supportsOpacity: false)
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
                        Label("Voice", systemImage: "waveform").tag(TagType.voice)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedTagType) { newType in
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                        if let suggestion = smartSuggestion, suggestion.tagType != newType {
                            withAnimation(.easeInOut) {
                                smartSuggestion = nil
                            }
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
                    title.isEmpty || content.isEmpty || audioRecorder.isRecording
                )
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
                    updateSmartSuggestion(for: coord)
                }
            }
            .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
                updateSmartSuggestion(for: coord)
            }
            .sheet(isPresented: $isShowingLocationPicker) {
                LocationPickerView(initialCoordinate: locationManager.currentLocation) { coord, name in
                    chosenCoordinate = coord
                    chosenPlacename = name
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
