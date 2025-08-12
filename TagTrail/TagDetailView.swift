//
//  TagListView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-11.
//

import SwiftUI

struct TagDetailView: View {
    let tag: Tag
    @ObservedObject var viewModel: TagViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isShowingEditView = false
    @StateObject private var audioRecorder: AudioRecorder
    @State private var isShowingImageViewer = false
    @State private var zoomURL: URL? = nil
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
                    if let thumb = downsample(imageAt: url, to: CGSize(width: UIScreen.main.bounds.width, height: 300), scale: UIScreen.main.scale) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                zoomURL = url
                                isShowingImageViewer = true
                            }
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
        .fullScreenCover(isPresented: $isShowingImageViewer) {
            if let url = zoomURL {
                ZoomableImageView(url: url)
                    .ignoresSafeArea()
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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
