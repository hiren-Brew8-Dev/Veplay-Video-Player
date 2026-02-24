<div align="center">

# 🎬 Veplay — iOS Video Player

**A powerful, feature-rich iOS video player built with SwiftUI.**  
Stream, organise, protect, and enjoy your videos — all in one place.

[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-blue?style=for-the-badge&logo=apple)](https://developer.apple.com/ios/)
[![Language](https://img.shields.io/badge/Language-Swift%205.9-orange?style=for-the-badge&logo=swift)](https://swift.org/)
[![Framework](https://img.shields.io/badge/UI-SwiftUI-purple?style=for-the-badge)](https://developer.apple.com/xcode/swiftui/)
[![Engine](https://img.shields.io/badge/Engine-VLC%20%2B%20AVKit-red?style=for-the-badge)](https://www.videolan.org/vlc/libvlc.html)

---

</div>

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
  - [Video Playback Engine](#-video-playback-engine)
  - [Player Controls](#-player-controls)
  - [Subtitle System](#-subtitle-system)
  - [Library & Dashboard](#-library--dashboard)
  - [Folder Management](#-folder-management)
  - [Private Folder](#-private-folder--biometric-lock)
  - [Google Cast & AirPlay](#-google-cast--airplay)
  - [Sleep Timer](#-sleep-timer)
  - [Background Playback](#-background-playback)
  - [Bookmarks](#-bookmarks)
  - [Snapshot / Screenshot](#-snapshot--screenshot)
  - [Paywall & Pro Features](#-paywall--pro-features)
  - [Settings](#-settings)
  - [Onboarding](#-onboarding)
  - [Search](#-search)
  - [History](#-history-tracking)
  - [Thumbnail Cache](#-thumbnail-caching)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Supported Formats](#-supported-video-formats)
- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [License](#-license)

---

## 🔍 Overview

**Veplay** is a full-featured iOS video player app built using **SwiftUI** and **MobileVLCKit**. It supports dozens of video formats, external subtitle files, Google Cast, AirPlay, Picture-in-Picture, hardware-accelerated decoding, biometric-locked private folders, and much more — all wrapped in a premium dark-themed UI.

---

## ✨ Features

---

### 🎥 Video Playback Engine

Veplay uses a **dual-engine** architecture to ensure maximum format compatibility:

| Engine | Role |
|--------|------|
| `MobileVLCKit` | Primary engine — handles MKV, AVI, FLV, OGG, WebM, TS, and exotic formats |
| `AVKit / AVFoundation` | Native Apple engine for MP4, MOV, QuickTime formats |

- Smooth seeking with **double-tap gesture** (±10 seconds)
- **Swipe-to-seek** on the progress bar
- **Smart aspect ratio** switching: Fill, Fit, Stretch, 4:3, 16:9, and more
- Playback continues seamlessly even after screen rotation

---

### 🎮 Player Controls

The player features a fully custom overlay control system:

- **Auto-hide controls** with a configurable timer
- **Center controls**: Skip backward 10s ⏪ | Play/Pause ▶️ | Skip forward 10s ⏩
- **Top Bar**: Title, Back button, Sleep Timer, Cast button, Settings menu
- **Bottom Bar**: Progress scrubber with live time display, Speed selector, PiP, Aspect Ratio, Audio/Captions, Bookmarks, Lock, Rotate
- **Screen Lock** 🔒: Locks all controls; persistent lock icon remains visible to unlock
- **Brightness control**: Swipe up/down on the left side of the screen
- **Volume control**: Swipe up/down on the right side of the screen (system volume HUD managed via `SystemVolumeManager`)
- **Double-tap seek feedback** with animated indicators

---

### 📝 Subtitle System

Full subtitle pipeline with these capabilities:

- **SRT file import** via Files app
- **Online subtitle search** via **OpenSubtitles API** & **YIFY Subtitles API**
- **Language picker** for browsing subtitle tracks
- **Subtitle delay offset** adjustment (milliseconds precision)
- **Multiple tracks** support — add and switch between tracks
- **Style customisation**: font size, font colour (White / Yellow / Cyan), optional background box
- Accurate time-sync engine with optimised linear search

---

### 📚 Library & Dashboard

- **Grid and List** view layouts (toggle between views)
- **Sort videos** by: Name, Date Added, Duration, File Size
- **Sort direction**: Ascending / Descending
- **Filter by type**: All Videos, By Folder
- **Glass-effect sort header** for a premium look
- Smooth **LazyVGrid** and **LazyVStack** rendering with thumbnail caching
- Watch **History section** on the dashboard with recent videos

---

### 📁 Folder Management

Organise your videos with a full folder system:

- **Create folders** → tap the `+` button to create a named folder
- **Move videos** → drag or select → move to destination folder
- **Copy videos** between folders
- **Delete** videos and folders with confirmation
- **Conflict resolution** UI when moving/copying (Skip / Replace / Keep Both) with optional "Apply to All" checkbox
- **Albums view** for browsing folder collections
- **FolderDetailView** with inline rename, sort, and per-folder settings

---

### 🔒 Private Folder & Biometric Lock

- Dedicated **Private Folder** tab, locked behind **Face ID / Touch ID**
- Uses `LocalAuthentication` framework with full **device passcode fallback**
- The folder cannot be viewed without successful biometric/passcode authentication
- Videos inside are displayed with a shield icon badge
- App-wide **Face ID Lock** option in Settings — requires authentication to open the app

---

### 📡 Google Cast & AirPlay

Cast your videos to external screens with ease:

- **Google Cast** integration via `GoogleCast` SDK
- Automatic **device discovery** on local network (Bonjour / mDNS)
- Custom **Cast Device Picker** UI showing all available Cast devices
- Cast controls: Play, Pause, Seek on remote device
- **AirPlay** support via native `AVRoutePickerView`
- Dedicated **Casting Mode Sheet** to choose between AirPlay/Bluetooth or a Cast Device

---

### ⏱ Sleep Timer

- Set a timer to **auto-stop playback** after a chosen duration
- Options: 15 min, 30 min, 45 min, 1 hour, End of video, Custom
- **Sleep Timer Toast** notification fades in when timer is active
- Timer status icon visible in the player Top Bar
- Cancel or reset the timer at any time

---

### 🎵 Background Playback

- Keep **audio playing** when the app moves to the background (e.g., lock screen or switching apps)
- Requires **Pro subscription** — non-Pro users are prompted to upgrade
- Implemented via `UIBackgroundModes: audio` in `Info.plist`
- Toggle in **Settings → Playback → Background Play**

---

### 🔖 Bookmarks

- Add **time-position bookmarks** during playback with a single tap
- Visual **bookmark indicators** on the progress scrubber bar
- Navigate between bookmarks with **Previous ⏮ / Next ⏭** controls
- Bookmarks are persisted per-video via CoreData
- Bookmark controls auto-hide if no bookmarks exist

---

### 📷 Snapshot / Screenshot

- Capture the **current video frame** as a high-quality image
- Saved directly to the **Photos library** with a success toast notification
- Accessible from the Player Settings Sheet

---

### 💎 Paywall & Pro Features

- **Paywall screen** with animated gradient background
- Subscription plans: Weekly, Yearly, Gift Card offer (introductory pricing)
- Remote Config–driven **dynamic plan descriptions** (trial eligibility shown automatically)
- Portrait-locked on iPhone (even when launched from landscape video player)
- One-time trial offer tracking (weekly & yearly plans)
- Paywall triggered from: Onboarding, Settings, Background Play toggle, Private Folder access

---

### ⚙️ Settings

The Settings screen includes:

| Section | Options |
|---------|---------|
| **Privacy & Security** | Face ID / Touch ID app lock toggle |
| **Playback** | Background Play toggle (Pro only) |
| **Support** | Privacy Policy, Terms of Service, Contact Us, Support |
| **Community** | Rate the App, Share with Friends |
| **About** | App version display |

---

### 🚀 Onboarding

- Multi-step **onboarding flow** shown on first launch
- Highlights key features with animated illustrations (Lottie)
- Seamlessly transitions to the Paywall or main app

---

### 🔍 Search

- Global **video search** across all folders and the library
- Real-time filtering as you type
- Results displayed in a clean list with thumbnail previews

---

### 📜 History Tracking

- Automatically records recently watched videos
- Displayed in a **History Section** on the Dashboard
- Quick-access replay from history with resume position

---

### 🖼 Thumbnail Caching

- High-performance **thumbnail generation** for all video files
- Disk-cached using `ThumbnailCacheManager` to avoid regeneration
- Memory-efficient lazy loading in grid views
- Cache invalidation on video deletion

---

## 🏗 Architecture

Veplay follows an **MVVM (Model-View-ViewModel)** architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                        │
│  DashboardView | PlayerView | SettingsView | OnboardingView  │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                        ViewModels                            │
│     DashboardViewModel | PlayerViewModel | NewPlayerViewModel │
└──────┬─────────────────┬──────────────────┬─────────────────┘
       │                 │                  │
┌──────▼──────┐  ┌───────▼───────┐  ┌──────▼───────────────┐
│   Services  │  │    Models     │  │      Helpers          │
│ SubtitleMgr │  │  VideoItem    │  │  NavigationManager    │
│ BiometricSvc│  │  FolderItem   │  │  HapticsManager       │
│ GoogleCast  │  │  CoreData     │  │  AppFontModifier      │
│ OpenSubs    │  │  BookmarkModel│  │  ThumbnailCache       │
│ RemoteConfig│  │               │  │  Extensions           │
└─────────────┘  └───────────────┘  └──────────────────────┘
```

### Key Design Decisions

- `NavigationManager` — custom navigation stack manager (no `NavigationStack` coupling)
- `CDManager` — CoreData manager for videos, folders, history, and bookmarks
- `KeyValueSyncStore` — lightweight `UserDefaults` wrapper for feature flags
- `RemoteConfigManager` — Firebase Remote Config integration for A/B features
- `DiscoveryManager` — local network device scanner (Google Cast devices)

---

## 🛠 Tech Stack

| Category | Technology |
|----------|-----------|
| **Language** | Swift 5.9 |
| **UI Framework** | SwiftUI |
| **Video Engine** | MobileVLCKit + AVFoundation |
| **Subtitles Online** | OpenSubtitles REST API + YIFY Subtitles |
| **Casting** | Google Cast SDK + AVRoutePickerView (AirPlay) |
| **Authentication** | LocalAuthentication (Face ID / Touch ID) |
| **Storage** | CoreData + UserDefaults |
| **Analytics** | Firebase Analytics |
| **Remote Config** | Firebase Remote Config |
| **Animations** | Lottie + SwiftUI Animations |
| **Fonts** | Figtree (Custom) |
| **Dependency Manager** | CocoaPods |

---

## 🎞 Supported Video Formats

Veplay handles a **massive range of video formats** out of the box:

| Format | Extension |
|--------|-----------|
| MPEG-4 | `.mp4` |
| QuickTime | `.mov` |
| Matroska | `.mkv` |
| AVI | `.avi` |
| Windows Media | `.wmv`, `.asf` |
| WebM | `.webm` |
| OGG Video | `.ogg`, `.ogv` |
| Flash Video | `.flv` |
| MPEG Transport Stream | `.ts`, `.mts`, `.m2ts` |
| MPEG | `.mpeg`, `.mpg`, `.mpe`, `.mpv` |
| 3GP | `.3gp`, `.3g2` |
| RealMedia | `.rm`, `.rmvb` |
| VOB (DVD) | `.vob` |
| MXF | `.mxf` |
| AMV | `.amv` |
| YUV | `.yuv` |
| NSV | `.nsv` |
| And more… | `.rrc`, `.gifv`, `.mng`, `.qt`, `.svi`, `.roq`, `.f4p`, `.f4a`, `.f4b`, `.mod`, `.dat`, `.vro` |

---

## 🚀 Getting Started

### Prerequisites

- Xcode 15+
- iOS 16.0+ deployment target
- CocoaPods installed (`gem install cocoapods`)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-username/Veplay-Video-Player.git
cd Veplay-Video-Player

# 2. Install CocoaPods dependencies
pod install

# 3. Open the workspace (NOT the .xcodeproj)
open My-Video-Player.xcworkspace

# 4. Select your target device/simulator in Xcode

# 5. Build & Run ▶
```

> ⚠️ **Important:** Always open the `.xcworkspace` file, not `.xcodeproj`, after running `pod install`.

### Firebase Setup

1. Add your own `GoogleService-Info.plist` file inside `My-Video-Player/`
2. Enable **Analytics** and **Remote Config** in your Firebase project console

---

## 📁 Project Structure

```
Veplay-Video-Player/
├── My-Video-Player/
│   ├── App/                    # App entry point & lifecycle
│   ├── Assets.xcassets/        # Images, colours, icons
│   ├── Fonts/                  # Figtree custom font family
│   ├── Helpers/                # Utilities: Navigation, Haptics, Extensions, Layout
│   ├── Lottie/                 # Lottie animation JSON files
│   ├── Models/
│   │   ├── CoreData/           # CoreData entities (Videos, Folders, Bookmarks, History)
│   │   └── Video/              # VideoItem, FolderItem model definitions
│   ├── Services/
│   │   ├── AnalyticsManager    # Firebase Analytics wrapper
│   │   ├── AppReviewManager    # App Store review prompts
│   │   ├── BiometricAuthService # Face ID / Touch ID authentication
│   │   ├── CDManager           # CoreData CRUD operations
│   │   ├── DiscoveryManager    # Local network discovery
│   │   ├── GoogleCastManager   # Google Cast session & media control
│   │   ├── HistoryService      # Watch history persistence
│   │   ├── OpenSubtitlesService # OpenSubtitles.com API integration
│   │   ├── RemoteConfigManager # Firebase Remote Config
│   │   ├── StorageService      # File system operations
│   │   ├── SubtitleManager     # SRT parsing & subtitle sync
│   │   ├── SystemVolumeManager # iOS system volume control
│   │   ├── ThumbnailCacheManager # Video thumbnail disk caching
│   │   ├── VideoFetcher        # Photo library video import
│   │   └── YIFYSubtitleService # YIFY subtitles API integration
│   ├── ViewModels/
│   │   ├── DashboardViewModel  # Library, folders, playback state
│   │   └── PlayerViewModel     # Player state, controls, gestures
│   └── Views/
│       ├── Common/             # Shared reusable components
│       ├── Components/         # UI component library
│       ├── Dashboard/          # Library, folders, history views
│       ├── Home/               # Home tab layout
│       ├── Onboarding/         # First-launch onboarding screens
│       ├── Paywall/            # Subscription / Pro paywall
│       ├── Player/             # Full-screen video player + control sheets
│       │   ├── BottomBar/      # Scrubber, playback controls
│       │   ├── TopBar/         # Title, back, cast, timer buttons
│       │   ├── Common/         # Gesture overlay, seek indicator
│       │   └── Sheets/         # Settings, Subtitles, Tracks, Speed, Sleep, Cast sheets
│       ├── Search/             # Global search view
│       ├── Sheets/             # App-level modal sheets
│       ├── Splash/             # Launch / splash screen
│       └── Tabs/               # Tab views: Videos, Folders, Favourites, Private, Settings
├── My-Video-Player.xcodeproj/
├── My-Video-Player.xcworkspace/
├── Podfile
└── README.md
```

---

## 📄 License

```
MIT License

Copyright (c) 2025 Shivshankar Tiwari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

<div align="center">

**Built with ❤️ by Shivshankar Tiwari**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>
