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

enum Route: Hashable {
    case settings
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
                        Button(action: recenter) {
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
                    
                    TagListView(tags: viewModel.tags){ tag in
                        recenter(on: tag)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
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
            isPresented: .constant(
                locationManager.authorizationStatus == .denied
                    || locationManager.authorizationStatus == .notDetermined
            )
        ) {
            VStack(spacing: 20) {
                Image(systemName: "location.slash.circle.fill")
                    .font(.title)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                    .shadow(color: Color.red, radius: 2)
                
                Text("Location Permission Required")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()

                Text(
                    "TagTrail needs your location in the background to work. TagTrail needs Always-On location access to notify you when you revisit tagged places, even when the app is closed."
                )
                .multilineTextAlignment(.center)
                .padding()

                Button("Go to Settings") {
                    if let appSettings = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        UIApplication.shared.open(appSettings)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $isPermissionLimited) {
            VStack(spacing: 20) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.title)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                    .shadow(color: Color.red, radius: 2)
                
                Text("Full Location Access Needed")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()

                Text(
                    "TagTrail needs Always-On location access to notify you when you revisit tagged places, even when the app is closed."
                )
                .multilineTextAlignment(.center)
                .padding()

                Button("Go to Settings") {
                    if let appSettings = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        UIApplication.shared.open(appSettings)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
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

struct TagListView: View {
    let tags: [Tag]
    var onLocate: (Tag) -> Void = { _ in }

    var body: some View {
        ScrollView {
            if tags.isEmpty {
                VStack(alignment: .center, spacing: 10) {
                    Spacer(minLength: 50)
                    Image(systemName: "mappin.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                    Text("No tags yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(tags) { tag in
                        HStack {
                            
                                if tag.type == .image {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                } else if tag.type == .voice {
                                    Image(systemName: "waveform")
                                        .foregroundColor(.red)
                                } else {
                                    Image(systemName: "text.bubble.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(tag.title)
                                        .font(.headline)
                                    Text(
                                        tag.timestamp.formatted(
                                            date: .abbreviated,
                                            time: .shortened
                                        )
                                    )
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundColor(.gray)
                                }.padding(.leading, 8)
                                
                                Spacer()
                                
                                Button(action: { onLocate(tag) }) {
                                    Image(systemName: "location.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                            
                        }
                        .padding()
                        .background(
                            (Color(hex: tag.colorHex) ?? .orange).opacity(0.15)
                        )   // any colour you’d like
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
    }
}

struct AddTagView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TagViewModel
    @AppStorage("defaultTagColorHex") private var defaultTagColorHex: String = "#FF9500"

    @StateObject private var locationManager = LocationManager()

    @State private var selectedTagType: TagType = .text

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isAnimating = false

    @State private var title: String = ""
    @State private var content: String = ""
    
    @State private var tagColor: Color = {
        let hex = UserDefaults.standard.string(forKey: "defaultTagColorHex") ?? "#FF9500"
        return Color(hex: hex) ?? .orange
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tag Title")) {
                    TextField("Enter title", text: $title)
                    ColorPicker("Tag Color", selection: $tagColor, supportsOpacity: false)
                }

                Section(header: Text("Tag Type")) {
                    Picker("Tag Type", selection: $selectedTagType) {
                        Label("Text", systemImage: "text.bubble.fill").tag(TagType.text)
                        Label("Image", systemImage: "photo").tag(TagType.image)
                        Label("Voice", systemImage: "waveform").tag(TagType.voice)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedTagType) { _ in
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
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
                                        // Store relative path including Audio/ subfolder so we can rebuild later
                                        content = "Audio/" + audioRecorder.getRecordingURL().lastPathComponent
                                        isAnimating = false
                                    } else {
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
                    let newTag = Tag(
                        title: title,
                        type: selectedTagType,
                        content: content,
                        coordinate: locationManager.currentLocation
                            ?? CLLocationCoordinate2D(
                                latitude: 53.5461,
                                longitude: -113.4938
                            ),
                        timestamp: Date(),
                        colorHex: tagColor.toHex() ?? "#FF9500"
                    )
                    print("🎨 TAG ABOUT TO SAVE:", tagColor.toHex() as Any)
                    print("📄 NEW TAG COLORHEX:", newTag.colorHex)
                    viewModel.addTag(newTag)
                    dismiss()
                }
                .disabled(
                    title.isEmpty || content.isEmpty
                        || audioRecorder.isRecording
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
                        }
                    }
                }
            }
        }
    }
}

struct TagDetailView: View {
    let tag: Tag
    @ObservedObject var viewModel: TagViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isShowingEditView = false
    @StateObject private var audioRecorder: AudioRecorder
    @State private var isShowingImageViewer = false
    @State private var showDeleteConfirmation = false

    // 1. Add a helper to compute the tag’s color
    private var tagColor: Color {
        Color(hex: tag.colorHex) ?? .orange
    }

    init(tag: Tag, viewModel: TagViewModel) {
        self.tag = tag
        self.viewModel = viewModel
        _audioRecorder = StateObject(
            wrappedValue: AudioRecorder(
                existingRecordingURL: {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
                    return mediaDir.appendingPathComponent(tag.content)
                }()
            )
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            // Top icon + title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tagColor.opacity(0.2))
                        .frame(width: 72, height: 72)

                    Image(systemName: {
                        switch tag.type {
                        case .image: return "photo"
                        case .voice: return "waveform"
                        case .text:  return "text.bubble.fill"
                        }
                    }())
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(tagColor)
                }

                Text(tag.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 25)

            Divider().padding(.vertical, 4)

            // Main content
            Group {
                let docs = FileManager.default.urls(for: .documentDirectory,
                                                    in: .userDomainMask).first!
                let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
                let url      = mediaDir.appendingPathComponent(tag.content)

                if tag.type == .image {
                    if let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                            .padding(.horizontal)
                    } else {
                        Text("Image not found")
                            .foregroundColor(.red)
                    }

                } else if tag.type == .voice {
                    HStack {
                        Spacer()
                        Button(action: { audioRecorder.playRecording() }) {
                            ZStack {
                                Circle()
                                    .fill(tagColor)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: tagColor.opacity(0.6), radius: 8)

                                Image(systemName: audioRecorder.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 40, weight: .bold))
                            }
                        }
                        Spacer()
                    }
                    .padding()

                } else if tag.type == .text {
                    Text(.init(tag.content))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tagColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
            }

            Spacer(minLength: 8)

            // Action Bar
            HStack {
                Button(action: { isShowingEditView = true }) {
                    Image(systemName: "square.and.pencil")
                        .font(.title)
                        .foregroundColor(tagColor)
                }

                Spacer()

                Text(
                    tag.timestamp.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .foregroundColor(.gray)

                Spacer()

                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.title)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .sheet(isPresented: $isShowingEditView) {
            EditTagView(tag: tag, viewModel: viewModel) {
                dismiss()
            }
        }
        .alert("Delete this tag?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteTag(tag)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
                )

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

struct EditTagView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TagViewModel

    var onSave: (() -> Void)? = nil

    @State var tag: Tag
    @State private var title: String
    @State private var content: String
    @State private var tagColor: Color

    init(tag: Tag, viewModel: TagViewModel, onSave: (() -> Void)? = nil) {
        self.tag = tag
        self.viewModel = viewModel
        self.onSave = onSave
        _title = State(initialValue: tag.title)
        _content = State(initialValue: tag.content)
        _tagColor = State(initialValue: Color(hex: tag.colorHex) ?? .orange)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Title")) {
                    TextField("Enter new title", text: $title)
                }
                
                Section(header: Text("Edit Color")) {
                    ColorPicker("Tag Color", selection: $tagColor, supportsOpacity: false)
                }

                Section(header: Text("Edit Content")) {
                    if tag.type == .text {
                        TextField(
                            "Edit Content",
                            text: $content,
                            axis: .vertical
                        )
                        .lineLimit(5...10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                    } else if tag.type == .image {
                        Text("Editing image not supported yet")
                            .foregroundColor(.gray)
                    } else if tag.type == .voice {
                        Text("Editing audio not supported yet")
                            .foregroundColor(.gray)
                    }
                }

                Button("Save Changes") {
                    tag.title = title
                    tag.content = content
                    tag.colorHex = tagColor.toHex() ?? tag.colorHex
                    viewModel.updateTag(tag)
                    dismiss()
                    onSave?()  // This will close the TagDetailView
                }
                .disabled(
                    title.isEmpty || (content.isEmpty && tag.type == .text)
                )
            }
            .navigationTitle("Edit Tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
