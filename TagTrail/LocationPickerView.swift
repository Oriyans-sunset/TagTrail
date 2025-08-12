//
//  LocationPickerView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-11.
//

import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    var initialCoordinate: CLLocationCoordinate2D?
    var onPicked: (CLLocationCoordinate2D, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var region: MKCoordinateRegion
    @State private var pinCoordinate: CLLocationCoordinate2D

    @State private var searchText: String = ""
    @StateObject private var searchVM = SearchCompleterVM()
    @State private var suggestions: [MKLocalSearchCompletion] = []

    init(initialCoordinate: CLLocationCoordinate2D?, onPicked: @escaping (CLLocationCoordinate2D, String?) -> Void) {
        self.initialCoordinate = initialCoordinate
        self.onPicked = onPicked
        let fallback = CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938)
        let start = initialCoordinate ?? fallback
        _region = State(initialValue: MKCoordinateRegion(center: start, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        _pinCoordinate = State(initialValue: start)
    }
    
    final class SearchCompleterVM: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
        @Published var results: [MKLocalSearchCompletion] = []
        private let completer: MKLocalSearchCompleter

        override init() {
            completer = MKLocalSearchCompleter()
            super.init()
            completer.delegate = self
            completer.resultTypes = [.address, .pointOfInterest]
            completer.filterType  = .locationsOnly
        }

        func updateQuery(_ text: String) {
            completer.queryFragment = text
        }

        func updateRegion(_ region: MKCoordinateRegion) {
            completer.region = region
        }

        // MKLocalSearchCompleterDelegate
        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            DispatchQueue.main.async { [weak self] in
                self?.results = completer.results
            }
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.results = []
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar + suggestions list
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search for a place", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onChange(of: searchText) { text in
                                searchVM.updateQuery(text)
                            }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding([.horizontal, .top])

                    if !searchVM.results.isEmpty {
                        List(searchVM.results, id: \.self) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.body)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { resolve(completion: item) }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                    }                }

                // Map with draggable pin
                // Map with center crosshair — move the MAP to place the pin
                ZStack {
                    Map(coordinateRegion: $region, interactionModes: [.all])
                        .onChange(of: region.center.latitude) { _ in
                            pinCoordinate = region.center
                            searchVM.updateRegion(region)
                        }
                        .onChange(of: region.center.longitude) { _ in
                            pinCoordinate = region.center
                            searchVM.updateRegion(region)
                        }

                    // Center crosshair pin
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                        .shadow(radius: 3)

                    // Hint banner at the bottom
                    VStack {
                        Spacer()
                        Text("Move the map to place the pin")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                            .padding(.bottom, 12)
                    }
                }
                .frame(maxHeight: .infinity)
                // no tap handler needed

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    reverseGeocode(pinCoordinate) { name in
                        onPicked(pinCoordinate, name)
                        dismiss()
                    }
                } label: {
                    Text("Use this location")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            .navigationTitle("Pick a location")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                searchVM.updateRegion(region)
            }
        }
    }

    private func resolve(completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            if let item = response?.mapItems.first?.placemark {
                let coord = item.coordinate
                pinCoordinate = coord
                region.center = coord
                searchVM.updateRegion(region)
                suggestions.removeAll()
                searchText = completion.title
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { placemarks, _ in
            completion(placemarks?.first?.name)
        }
    }

}
