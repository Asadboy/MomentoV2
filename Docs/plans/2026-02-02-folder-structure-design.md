# Folder Structure Reorganization Design

**Date:** 2026-02-02
**Status:** Approved

## Problem

The Momento project has a mismatch between filesystem organization and Xcode project structure:
- Files on disk are organized into folders but Xcode treats them as a flat list
- When Claude Code creates files, they need to be manually added to Xcode
- Inconsistent file placement (e.g., HapticsManager in two places, reveal files scattered)

## Solution

Reorganize into a feature-based folder structure and establish a convention for adding new files.

## New Folder Structure

```
Momento/
├── App/
│   ├── MomentoApp.swift
│   └── ContentView.swift
│
├── Features/
│   ├── Auth/
│   │   ├── SignInView.swift
│   │   ├── AuthenticationRootView.swift
│   │   └── UsernameSelectionView.swift
│   │
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   ├── PhotoCaptureSheet.swift
│   │   └── Filters/
│   │       └── BethanReynoldsFilter.swift
│   │
│   ├── Events/
│   │   ├── EventRow.swift
│   │   ├── AddEventSheet.swift
│   │   ├── JoinEventSheet.swift
│   │   ├── InviteSheet.swift
│   │   ├── PremiumEventCard.swift
│   │   └── CreateMomento/
│   │       ├── CreateMomentoFlow.swift
│   │       ├── CreateStep1NameView.swift
│   │       ├── CreateStep2ConfigureView.swift
│   │       ├── CreateStep2TimesView.swift
│   │       └── CreateStep3ShareView.swift
│   │
│   ├── Gallery/
│   │   ├── PhotoGalleryView.swift
│   │   └── LikedGalleryView.swift
│   │
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── SettingsView.swift
│   │   ├── KeepsakeGridView.swift
│   │   ├── KeepsakeDetailModal.swift
│   │   ├── StatCardView.swift
│   │   └── StatsGridView.swift
│   │
│   └── Reveal/
│       ├── FeedRevealView.swift
│       ├── RevealCardView.swift
│       ├── PhotoRevealCard.swift
│       ├── KeepsakeRevealView.swift
│       └── CardPreviewView.swift
│
├── Services/
│   ├── AnalyticsManager.swift
│   ├── EventManager.swift
│   ├── HapticsManager.swift
│   ├── ImageCacheManager.swift
│   ├── OfflineSyncManager.swift
│   ├── PhotoStorageManager.swift
│   ├── RevealStateManager.swift
│   └── SupabaseManager.swift
│
├── Models/
│   ├── Event.swift
│   └── TimeFormatter.swift
│
├── Components/
│   ├── AccordionRow.swift
│   ├── EventPreviewModal.swift
│   ├── FilterPickerView.swift
│   ├── InviteCardRenderer.swift
│   ├── InviteCardView.swift
│   ├── LockedSettingView.swift
│   ├── PremiumRowView.swift
│   └── VerificationCodeInput.swift
│
└── Config/
    ├── PostHogConfig.swift
    └── SupabaseConfig.swift
```

## File Moves Required

### Files to Delete
- `EmojiReactionPicker.swift` - removing emoji reactions

### Files to Rename
- `Filters/KodakGoldFilter.swift` → `Features/Camera/Filters/BethanReynoldsFilter.swift`

### Files to Move

| Current Location | New Location |
|-----------------|--------------|
| `MomentoApp.swift` | `App/MomentoApp.swift` |
| `ContentView.swift` | `App/ContentView.swift` |
| `SignInView.swift` | `Features/Auth/SignInView.swift` |
| `AuthenticationRootView.swift` | `Features/Auth/AuthenticationRootView.swift` |
| `UsernameSelectionView.swift` | `Features/Auth/UsernameSelectionView.swift` |
| `CameraView.swift` | `Features/Camera/CameraView.swift` |
| `PhotoCaptureSheet.swift` | `Features/Camera/PhotoCaptureSheet.swift` |
| `EventRow.swift` | `Features/Events/EventRow.swift` |
| `AddEventSheet.swift` | `Features/Events/AddEventSheet.swift` |
| `JoinEventSheet.swift` | `Features/Events/JoinEventSheet.swift` |
| `InviteSheet.swift` | `Features/Events/InviteSheet.swift` |
| `PremiumEventCard.swift` | `Features/Events/PremiumEventCard.swift` |
| `CreateMomento/*` | `Features/Events/CreateMomento/*` |
| `PhotoGalleryView.swift` | `Features/Gallery/PhotoGalleryView.swift` |
| `LikedGalleryView.swift` | `Features/Gallery/LikedGalleryView.swift` |
| `Profile/*` | `Features/Profile/*` |
| `FeedRevealView.swift` | `Features/Reveal/FeedRevealView.swift` |
| `RevealCardView.swift` | `Features/Reveal/RevealCardView.swift` |
| `PhotoRevealCard.swift` | `Features/Reveal/PhotoRevealCard.swift` |
| `CardPreviewView.swift` | `Features/Reveal/CardPreviewView.swift` |
| `Profile/KeepsakeRevealView.swift` | `Features/Reveal/KeepsakeRevealView.swift` |
| `EventManager.swift` | `Services/EventManager.swift` |
| `PhotoStorageManager.swift` | `Services/PhotoStorageManager.swift` |
| `HapticsManager.swift` (root) | Delete (duplicate exists in Services) |
| `Event.swift` | `Models/Event.swift` |
| `TimeFormatter.swift` | `Models/TimeFormatter.swift` |
| `Components/*` | `Components/*` (no change) |
| `Services/*` | `Services/*` (no change) |
| `Config/*` | `Config/*` (no change) |

## Implementation Steps

1. Create new folder structure on disk
2. Move files to new locations using git mv
3. Rename KodakGoldFilter to BethanReynoldsFilter
4. Delete EmojiReactionPicker.swift
5. Delete duplicate HapticsManager.swift from root
6. Update all import paths in moved files
7. Rebuild Xcode project file with correct group structure
8. Update CLAUDE.md with file organization convention
