# TagTrail — Location-based personal tags for iOS

TagTrail is a minimalist iOS app that lets you drop personal tags (notes) tied to real-world places. Save quick text, snap a photo, or record a short voice memo right where you are — and get a nudge when you’re back nearby.

> **Status:** Submitted for review. App Store listing coming soon.

---

## ✨ Features

- **Drop tags at your current GPS location**
  - Text, Image, and Voice tag types
  - Optional color accent per tag
- **Find on map** — tap the location icon in the list to center the map on that tag
- **Location-based reminders** — notifications when you’re near a tag
- **Works offline** — everything is stored locally on device
- **Sorting & filters** (in Settings)

### Pro 
- Unlimited custom colors
- Unlimited tags
- Voice notes
> Philosophy: never charge for the core “create & view tags” experience. Pro is for power features.

---

## 📸 Screenshots

<!-- Replace with your images (keep the same alt text for accessibility) -->
| Map & List | Add Tag | Voice Tag |
|---|---|---|
| <img width="200" height="400" alt="Simulator Screenshot - iPhone 16 Pro Max - 2025-08-13 at 15 00 52" src="https://github.com/user-attachments/assets/a7ec8713-c25a-408e-97d2-a54b016b8736" /> | <img width="200" height="400" alt="Simulator Screenshot - iPhone 16 Pro Max - 2025-08-14 at 23 26 02" src="https://github.com/user-attachments/assets/41023a5b-dd2e-4315-ad37-d151e317aab8" /> |  <img width="200" height="400" alt="Simulator Screenshot - iPhone 16 Pro Max - 2025-08-14 at 22 07 40" src="https://github.com/user-attachments/assets/64470688-1dc0-407c-810d-fa90ca3d2998" /> |

---

## 🧱 Tech Stack

- **SwiftUI** (UI) + **MapKit** (maps/annotations)
- **CoreLocation** (location, geofencing)
- **UserNotifications** (local notifications)
- **Audio**: `AVFoundation` (voice tags)
- **Storage**: Local-first (SQLite via **GRDB**)  
- **In-App Purchases**: RevenueCat (WIP)

---

## 🏁 Quick Start

1. **Clone**
   ```bash
   git clone https://github.com/.../TagTrail.git
   cd TagTrail
   ```

2. **Open in Xcode**  
   Use Xcode 15.4+ (iOS 17+) or newer. Open `TagTrail.xcodeproj` (or the workspace if you add packages).

3. **Set the bundle identifier & signing**
   - Targets → TagTrail → **Signing & Capabilities** → set your Team and a unique Bundle ID.

4. **Capabilities**
   - **Background Modes** → check **Location updates**
   - **Push Notifications** (only if you later add remote push) — not required for local notifications

5. **Info.plist keys** (with friendly strings)
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `NSPhotoLibraryUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
   - `NSMicrophoneUsageDescription`

6. **(Optional) RevenueCat setup (WIP)**
   - Add package: `https://github.com/RevenueCat/purchases-ios`
   - Add your **Public API Key** in config
   - Define **Products** in App Store Connect and match identifiers in code

7. **Build & run on a real device**  
   Background geofencing and audio recording work best on device.

---

## 🔐 Privacy & Permissions

- **Location:** TagTrail requests **Always Allow** so geofenced reminders work even when the app isn’t open.
  - Tags are saved locally on your device.
  - Planned: opt-in CloudKit sync to your private iCloud only.
- **Photos:** Only required if you attach images.
- **Microphone:** Only required if you record voice tags.
- 
---

> Notes:
> - Map updates are throttled to avoid excessive redraws.
> - Reverse-geocoding is rate-limited; requests are deduped/debounced.

---

## 🧪 Testing Tips

- Test geofencing outdoors with real movement; simulator geofences are limited.
- On first launch, choose **Allow While Using** or **Always Allow** — the app shows a banner if not “Always”.
- In **Settings → Notifications**, ensure at least one notification type is enabled (the app shows a bell-slash icon if all are off).

---

## 🛣 Roadmap

- [ ] Voice transcription toggle per tag
- [ ] OCR for image tags
- [ ] CloudKit sync (local-first → opt-in sync)
- [ ] Tag heatmaps & simple analytics
- [ ] Export/Import (JSON)
- [ ] Accessibility polish (VoiceOver, Dynamic Type)

---

## 🙌 Acknowledgements

- Apple frameworks: SwiftUI, MapKit, CoreLocation, UserNotifications, AVFoundation
- GRDB by Gwendal Roué
- RevenueCat (IAP infrastructure)
