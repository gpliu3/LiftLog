# GymLog

A clean, modern iOS strength training tracker built with SwiftUI and SwiftData.

![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![Framework](https://img.shields.io/badge/Framework-SwiftUI%20%7C%20SwiftData-purple)

## Features

- **Quick Logging** — Tap to instantly add sets with one tap. Tap a set to edit inline, or long press for full edit view.
- **Smart Defaults** — New training days auto-fill from your previous session. Choose whether to carry over your warm-up (first set) or working (last set) values.
- **Progress Charts** — Track volume, max weight, and estimated 1RM over time with Swift Charts.
- **Exercise Library** — Create and manage exercises with muscle group tags and form notes.
- **Training History** — Browse past workouts by week or month with per-day breakdowns.
- **CSV Export** — Export selected date-range training records to CSV for Excel analysis, share, or copy/paste.
- **Backdated Logging** — Choose a date (default today) when adding a set to log past training days.
- **Bilingual** — Full English and Chinese (简体中文) support with in-app language switching.

## How It Works

| Action | How |
|---|---|
| Log a new set | Tap the **+** FAB button |
| Choose log date | In Log Set, pick **Date** (defaults to today) |
| Add another set | Tap "Add another set" at the bottom of an exercise group |
| Duplicate a set | Swipe right on any set |
| Edit a set quickly | Tap any set row (inline editor) |
| Edit a set (full view) | Long press any set |
| Delete a set | Swipe left on any set |
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
- **Default Set** — Choose whether a new day pulls from the first set (warm-up) or last set (working) of the previous session
- **Restore Default Exercises** — Add missing built-in exercises without modifying existing user data

## Requirements

- Xcode 15+
- iOS 17+
- No external dependencies
