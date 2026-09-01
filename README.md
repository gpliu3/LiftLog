# GPLift

GPLift is a compact iOS strength and cardio training log focused on fast daily logging, clear history, and on-device privacy.

![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![Framework](https://img.shields.io/badge/Framework-SwiftUI%20%7C%20SwiftData-purple)

## Highlights

- **Strength and Cardio libraries**: manage both categories independently and switch between them while creating exercises or logging training.
- **Fast training logging**: add a Strength set or Cardio session in one flow, or continue directly from Today.
- **Cardio tracking**: record whole minutes with optional average and maximum heart rate for swimming, cross trainer, rowing machine, indoor bike, or custom activities.
- **Inline editing**: tap a set to edit it in place, with shared `- / +` controls for the active field.
- **Dual-unit entry**: weight entry supports both `kg` and `lb` in Log Set and inline editing, while all saved data stays standardized in `kg`.
- **Smart defaults**: first set of a new day starts from the first set of the most recent previous day for that exercise.
- **Backdated logging**: log to a past date without changing current-day data.
- **Previous-day reference**: each exercise in Today can reveal only the immediately previous training day for planning.
- **One-time PB markers**: sparkles appear only on the first set that establishes a new personal best.
- **Optional RIR**: `0`, `1`, `2`, or blank, editable later.
- **Exercise activity control**: exercises can be marked active or inactive; inactive exercises stay in history and the library but are hidden from the Log Set picker.
- **History by week, month, or all**: the default History view is `All`, grouped by Monday-based weeks with separate Strength set/volume and Cardio session/minute totals.
- **CSV export**: export workout history and exercises, including Cardio duration and heart-rate fields, to UTF-8 BOM CSV for better Excel compatibility with Chinese text.
- **Bilingual UI**: English and Simplified Chinese, with in-app language switching.

## Main Flows

| Action | How |
|---|---|
| Log new training | Tap the floating `+` button in Today, then choose Strength or Cardio |
| Choose a Strength exercise | Browse active exercises grouped by muscle group and sorted by the group training date |
| Choose a Cardio activity | Browse active Cardio activities sorted from longest due to most recently trained |
| Enter weight | Tap either `kg` or `lb`; both stay in sync |
| Record Cardio | Enter whole minutes and, optionally, average and maximum heart rate |
| Save quickly | Use `Save & Add Another` or `Save & Close` |
| Edit a set inline | Tap any Today set row |
| Edit a set in full-screen | Long press a Today set row |
| Add another set | Tap `Add another set` under an exercise in Today |
| Review previous day | Tap the clock button in an exercise header |
| Edit exercise notes and status | Open Exercises and edit the exercise |
| Toggle active/inactive | Use the inline active switch in Exercises or the toggle in Edit Exercise |
| Export workout history | History → export button → choose range → share or copy CSV |

## Data Model Notes

- `WorkoutSet.weightKg` is the single persisted weight field.
- `lb` input is converted to `kg` before saving, so existing records remain compatible.
- `Exercise.category` is optional in SwiftData. Missing or unknown values resolve to Strength, preserving every exercise created before Cardio support.
- Cardio uses the existing `WorkoutSet.durationSeconds` field, storing whole minutes as `minutes * 60`; average and maximum heart rate are new optional fields.
- Strength-only calculations (volume, estimated 1RM, PB markers, and Progress charts) explicitly exclude Cardio records.
- `Exercise.isActive` is stored as an optional field for backward compatibility with older SwiftData stores.
- Missing `isActive` values are treated as active, which preserves existing users' exercise visibility after upgrading.
- The four built-in Cardio activities are seeded once for existing users. If a user later removes one, it is not silently added back.
- No migration fallback recreates or wipes the database.

## Project Structure

```text
GPLift/
├── App/
│   └── GPLiftApp.swift
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
│   │   ├── ExerciseListView.swift
│   │   ├── ExerciseDetailView.swift
│   │   └── ExerciseEditView.swift
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── DayDetailView.swift
│   ├── Progress/
│   └── Settings/
│       └── SettingsView.swift
├── Utilities/
│   ├── CSVExport.swift
│   ├── DateFormatters.swift
│   ├── LanguageManager.swift
│   ├── SettingsManager.swift
│   ├── VolumeCalculator.swift
│   └── WeightUnit.swift
└── Resources/
    ├── Assets.xcassets/
    ├── en.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

## Tech Stack

- **SwiftUI** for UI composition
- **SwiftData** for on-device persistence
- **Swift Charts** for progress charts
- **UIKit interop** for keyboard dismissal, clipboard, and haptics where SwiftUI alone is not enough

## Settings

- **Language**: follow system, English, or 简体中文
- **Restore Default Exercises**: restore missing built-in Strength and Cardio exercises without overwriting existing user-created data or preferences

## Requirements

- Xcode 15+
- iOS 17+
- No third-party dependencies

## Release

- Current App Store/TestFlight version prepared in this repo: `1.8 (71)`
- Bundle identifier: `com.gengpuliu.LiftLog`
- Export compliance: `ITSAppUsesNonExemptEncryption = NO`
- Build/version values are managed from `GPLift.xcodeproj/project.pbxproj`

### TestFlight Publish

Use the scripted flow to reduce failed upload attempts and notification emails:

```bash
cd /Users/gengpuliu/Projects/LiftLog/LiftLog
./scripts/release_testflight.sh \
  --api-key AAN76TPC9V \
  --issuer 33142954-a2ca-4a17-96b9-ee0cda4a3382 \
  --p8 /Users/gengpuliu/.appstoreconnect/private_keys/AuthKey_AAN76TPC9V.p8
```

What it does:
- Archive the app in `Release`
- Export the IPA
- Validate with Apple first
- Upload only after validation succeeds
- Wait for delivery status
