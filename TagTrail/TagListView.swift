//
//  TagListView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-11.
//

import SwiftUI

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
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onLocate(tag)
                                }) {
                                    Image(systemName: "location.fill.viewfinder")
                                        .font(.title2)
                                        .foregroundColor(Color(.gray))
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
