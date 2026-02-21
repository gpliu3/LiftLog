# LiftLog

A clean, modern iOS strength training tracker built with SwiftUI and SwiftData.

![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![Framework](https://img.shields.io/badge/Framework-SwiftUI%20%7C%20SwiftData-purple)

## Features

- **Quick Logging** — Tap to instantly add sets with one tap. Tap a set to edit inline, or long press for full edit view.
- **Smart Defaults** — New training days auto-fill from the first (starting) set of your previous training day for that exercise.
- **PR Highlights** — Sets that hit personal bests (weight/volume/duration/reps up to that day) get a celebration marker.
- **One-Time PB Markers** — PB sparkles appear only on the first set that breaks a previous best (no repeated sparkle for ties later).
- **RIR Tracking** — Optional RIR input (0/1/2) per set, editable later and shown only when set.
- **Previous-Day Reference** — In Today, each exercise header has a clock button to show only the immediately previous training day's sets for planning.
- **Progress Charts** — Track volume, max weight, and estimated 1RM over time with Swift Charts.
- **Exercise Library** — Create and manage exercises with muscle group tags and form notes.
- **Exercise Quick Add** — In Exercises, each row shows last-trained date plus "X days ago" and a direct Quick Add button.
- **Training History** — Browse past workouts by week or month with per-day breakdowns.
- **CSV Export** — Export selected date-range training records to CSV for Excel analysis, share, or copy/paste.
- **Backdated Logging** — Choose a date (default today) when adding a set to log past training days.
- **Due-Aware Exercise Picker** — In Log Set, exercises show last-trained date plus "X days ago", ordered by longest due first.
- **One-Tap Save Actions** — Log Set provides direct **Save & Add Another** and **Save & Close** buttons (no extra menu step).
- **Compact UI System** — Unified rounded typography and tighter row/control spacing across Today, History, Exercises, and edit forms so more records fit on screen (including larger display zoom).
- **Bilingual** — Full English and Chinese (简体中文) support with in-app language switching.

## How It Works

| Action | How |
|---|---|
| Log a new set | Tap the **+** FAB button |
| Save in one tap | Use **Save & Add Another** or **Save & Close** directly at the bottom of Log Set |
| Choose log date | In Log Set, pick **Date** (defaults to today) |
| Add another set | Tap "Add another set" at the bottom of an exercise group |
| Duplicate a set | Swipe right on any set |
| Edit a set quickly | Tap any set row (inline editor) |
| Inline edit safety | Keyboard includes Save; tapping outside weight auto-saves to avoid losing edits |
| Edit a set (full view) | Long press any set |
| Delete a set | Swipe left on any set |
| See previous day sets | In Today exercise header, tap the clock icon |
| Quick add from Exercises | Exercises tab → tap **Quick Add** on any exercise |
| Set optional RIR | In Log Set / Edit Set choose **RIR**: `-`, `0`, `1`, `2` |
| Spot PR sets | Look for the sparkle marker on set rows |
| Export records | History tab → Export button → Generate/Share/Copy CSV |

## Tech Stack

- **SwiftUI** — Declarative UI
- **SwiftData** — On-device persistence with `@Model` and `@Query`
- **Swift Charts** — Progress visualization
- **`@Observable`** — Reactive language and settings management

## Project Structure

```
LiftLog/
├── App/
│   └── LiftLogApp.swift
├── Models/
│   ├── Exercise.swift
│   └── WorkoutSet.swift
├── Views/
│   ├── MainTabView.swift
│   ├── Today/
│   │   ├── TodayView.swift
│   │   ├── AddSetView.swift
│   │   └── EditSetView.swift
│   ├── Exercises/
│   ├── History/
│   ├── Progress/
│   └── Settings/
│       └── SettingsView.swift
├── Utilities/
│   ├── LanguageManager.swift
│   ├── SettingsManager.swift
│   ├── VolumeCalculator.swift
│   └── DateFormatters.swift
└── Resources/
    ├── Assets.xcassets/
    ├── en.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

## Settings

- **Language** — Follow system, English, or 简体中文
- **Default Start Value** — New day set defaults use the first set from the most recent previous training day
- **Restore Default Exercises** — Add missing built-in exercises without modifying existing user data

## Requirements

- Xcode 15+
- iOS 17+
- No external dependencies

## Release

- Current version: `1.0` (`CURRENT_PROJECT_VERSION` `20`)
- Bundle ID: `com.gengpuliu.LiftLog`
- App Store Connect metadata draft: `AppStore/metadata.md`
