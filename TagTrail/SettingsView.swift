//
//  SettingsView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-03.
//

import SwiftUI

struct SettingsView: View {
    @State private var showingPrivacy = false
    @State private var showingHowToUse = false
    @AppStorage("defaultTagColorHex") private var defaultTagColorHex: String = "#FF9500"
    @AppStorage("tagSortOption") private var tagSortRaw: String = TagSortOption.newest.rawValue
    private var sortOption: TagSortOption {
        get { TagSortOption(rawValue: tagSortRaw) ?? .newest }
        set { tagSortRaw = newValue.rawValue }
    }
    
    var body: some View {
            let styledText: AttributedString = {
                var result = AttributedString("TagTrail")
                
                if let range = result.range(of: "Tag") {
                    result[range].foregroundColor = .red
                }
                if let range = result.range(of: "Trail") {
                    result[range].foregroundColor = .primary
                }
                
                return result
            }()
            
            List {
                Section {
                    VStack(spacing: 8) {
                        Image("appstore")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(radius: 4)
                        
                        Text(styledText)
                            .font(.title)
                            .fontDesign(.rounded)
                            .fontWeight(.bold)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("By priyanshu")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Defaults")) {
                    Picker("Tag Sorting",
                           selection: Binding(
                               get: { TagSortOption(rawValue: tagSortRaw) ?? .newest },
                               set: { tagSortRaw = $0.rawValue }
                           )) {
                        ForEach(TagSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    ColorPicker("Default Tag Color",
                                selection: Binding(
                                    get: { Color(hex: defaultTagColorHex) ?? .orange },
                                    set: { newColor in
                                        defaultTagColorHex = newColor.toHex() ?? "#FF9500"
                                    }),
                                supportsOpacity: false)
                }

                Section(header: Text("Legal")) {
                    Button(action: {
                        // open privacy sheet
                        showingPrivacy = true
                    }) {
                        Text("Privacy")
                    }
                }
                
                Section(header: Text("Support")) {
                    Link("Feedback", destination: URL(string: "mailto:ryzenlyve@gmail.com?subject=MoodMusic%20Feedback")!)
                    Button("How to Use TagTrail") {
                        showingHowToUse = true
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A")
                            .foregroundColor(.gray)
                    }
                }
                
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPrivacy) {
                Text("Privacy Policy")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.accentColor)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        Text("1. Information We Collect")
                            .font(.title3.bold())
                            .padding(.top)
                        
                        Group {
                            Text("**Location Data**")
                                .font(.headline)
                            Text("TagTrail uses your device’s location to let you create and view tags tied to specific places. This data is processed on your device and never shared with third parties.")
                                .font(.body)
                            
                            Text("**Tag Content**")
                                .font(.headline)
                            Text("When you create a tag (text, image, or voice), the content is stored locally on your device. We do not collect or store your tags on any external servers.")
                                .font(.body)
                        }
                        
                        Divider()
                            .padding(.vertical)
                        
                        Text("2. How We Use Your Information")
                            .font(.title3.bold())
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("•")
                                Text("To show your tags at your current or past locations.")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("To notify you when you’re near a location with a saved tag.")
                            }
                        }
                        .font(.body)
                        
                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("Privacy Policy")
            }
            .sheet(isPresented: $showingHowToUse) {
                Text("How to Use TagTrail")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 100))
                    .foregroundColor(.accentColor)
                
                
                VStack(alignment: .leading, spacing: 16) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. Adding a Tag")
                                .font(.headline)
                            Text("Tap the '+' button on the map screen to add a new tag. You can choose to create a text, image, or voice tag. Each tag is saved with your current location.")

                            Text("2. Viewing Tags")
                                .font(.headline)
                            Text("Your tags appear as pins on the map. Tap a pin to view its details or edit it.")

                            Text("3. Tag List")
                                .font(.headline)
                            Text("Swipe up from the bottom of the map to view a list of all your saved tags.")
                            Text("Tap the location icon (") + Text(Image(systemName: "location.circle.fill")) + Text(") on the right side of a tag to focus the map on that tag’s location.")

                            Text("4. Notifications")
                                .font(.headline)
                            Text("You’ll get notified when you revisit a location where you've saved a tag.")

                            Spacer()
                        }
                        .padding()
                    }
                }
                .navigationTitle("How to Use")
            }
        }
}

#Preview {
    SettingsView()
}
    
