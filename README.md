# GPLift

GPLift is a compact iOS strength, cardio, and rehabilitation training log focused on fast daily logging, clear history, and on-device privacy.

![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![Framework](https://img.shields.io/badge/Framework-SwiftUI%20%7C%20SwiftData-purple)

## Highlights

- **Strength, Cardio, and Rehab libraries**: switch between three independent categories when creating exercises or logging training. Consistent dumbbell, heart, and flexibility icons identify categories using the same text styles and colors.
- **Rehabilitation tracking**: record weight/reps, reps only, or timed sets, with notes and optional RIR. Today and History show Rehab separately; it never contributes to Strength set counts, volume totals, or Progress charts.
- **Fast training logging**: add a Strength set or Cardio session in one flow, or continue directly from Today.
- **Cardio tracking**: record whole minutes with optional average and maximum heart rate for swimming, cross trainer, rowing machine, indoor bike, or custom activities. Duration buttons adjust by five minutes in new-session, inline-edit, and full-edit views; direct input still accepts any whole minute. Today has no extra Add another session row.
- **Weekly Cardio goal**: the History overview and each week show Cardio sessions, minutes against a configurable target, and a duration-weighted average heart rate when available.
- **Inline editing**: tap a set to edit it in place, with shared `- / +` controls for the active field.
- **Dual-unit entry**: weight entry supports both `kg` and `lb` in Log Set and inline editing, while all saved data stays standardized in `kg`.
- **Smart defaults**: first set of a new day starts from the first set of the most recent previous day for that exercise.
- **Backdated logging**: log to a past date without changing current-day data.
- **Previous-day reference**: each exercise in Today can reveal only the immediately previous training day for planning.
- **One-time PB markers**: sparkles appear only on the first set that establishes a new personal best.
- **Optional RIR**: `0`, `1`, `2`, or blank, editable later.
- **Exercise activity control**: exercises can be marked active or inactive; inactive exercises stay in history and the library but are hidden from the Log Set picker.
- **Exercise notes in every category**: editing a Cardio exercise preserves its existing notes, just like Strength and Rehab.
- **History by week, month, or all**: the default History view is the current `Week`, shown as a single summary card above its days (no duplicate week header); `Month` and `All` stay grouped by Monday-based weeks with separate Strength set/volume, Cardio session/minute, and Rehab set totals. Days containing only Cardio or Rehab remain visible with their full training notes.
- **Readable History summaries**: the scrollable overview and weekly headers share compact subheadline-sized category rows instead of separate metric tiles; day labels are sized to sit comfortably next to their training details. Week headings combine the Monday-Sunday date range with training days; Strength shows sessions, sets, and kilograms, while Cardio shows a red heart, sessions, minutes/goal, and recorded average heart rate. Text wraps naturally at larger text sizes. Category tabs already identify activities, so the Log Set picker does not repeat category icons for each exercise.
- **CSV export**: export workout history and exercises, including Cardio duration and heart-rate fields, to UTF-8 BOM CSV for better Excel compatibility with Chinese text.
- **Bilingual UI**: English and Simplified Chinese, with in-app language switching.

## Main Flows

| Action | How |
|---|---|
| Log new training | Tap the floating `+` button in Today, then choose Strength, Cardio, or Rehab |
| Choose a Strength or Rehab exercise | Browse active exercises grouped by muscle group; the picker has no search field |
| Choose sorting | Longest due is selected the first time and your last choice is remembered afterwards, with never-trained exercises/groups last; Default order uses fixed muscle groups and localized exercise names within each group |
| Choose a Cardio activity | Browse active Cardio activities sorted from longest due to most recently trained |
| Enter weight | Tap either `kg` or `lb`; both stay in sync |
| Record Cardio | Enter whole minutes and, optionally, average and maximum heart rate |
| Set a weekly Cardio target | Settings → Weekly Cardio Goal; the default is 60 minutes |
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
- `Exercise.category` is optional in SwiftData. Missing or unknown values resolve to Strength, preserving every exercise created before Cardio support. Rehab adds the `rehabilitation` string value to the same field without changing the persisted schema.
- Category editing remains locked after an exercise has training records, so historical records cannot be silently reclassified by changing its category.
- The Glutes & Legs / 臀腿 muscle group retains the canonical stored value `Legs`. This is a localization change, not a data migration.
- Cardio uses the existing `WorkoutSet.durationSeconds` field, storing whole minutes as `minutes * 60`; average and maximum heart rate are new optional fields.
- The weekly Cardio target is stored in `UserDefaults` and defaults to 60 minutes, so it does not require a SwiftData migration.
- Weekly average heart rate is weighted by each recorded session's duration; sessions without an average heart rate are excluded from that calculation but still count toward Cardio minutes.
- Shared `TrainingTotals` calculations keep aggregate Strength counts/volume separate from Cardio and Rehab in Today, History, and day details. Rehab sets retain their own weight, reps, duration, volume, and per-exercise PB behavior; Progress charts continue to include only Strength exercises.
- History training days count distinct dates with Strength or Cardio; mixed days count once. Strength session counts represent distinct dates with Strength sets. Rehab-only dates remain visible but do not increase these counts. These are read-only snapshot calculations with no changes to stored records or the database schema.
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
│   ├── TrainingPresentation.swift
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
│   ├── ExerciseOrdering.swift
│   ├── HistorySnapshot.swift
│   ├── LanguageManager.swift
│   ├── SettingsManager.swift
│   ├── TrainingTotals.swift
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
- **Weekly Cardio Goal**: set the Monday-Sunday target shown for every week in History
- **Restore Default Exercises**: restore missing built-in Strength and Cardio exercises without overwriting existing user-created data or preferences

## Requirements

- Xcode 15+
- iOS 17+
- No third-party dependencies

## Verification

Run `bash scripts/test_training_logic.sh` on macOS with Xcode installed. It compiles the released build 72 model definitions in a separate process, creates a disposable 611-record SwiftData store, and opens it with the current models. The test compares every stored field and relationship before and after saving/reopening, including Chinese notes, optional fields, and inactive exercises.

The same suite verifies all three Rehab recording modes, mixed and Rehab-only days, Monday week boundaries, date-range totals, duration-weighted Cardio heart rate, CSV encoding, exercise ordering, and repeated five-minute adjustments. All stores and exports are temporary; no user app database is read or modified.

To run the same database and logic tests on a booted iOS simulator, set `GPLIFT_TEST_SIMULATOR=<simulator-UUID>` before the command. The tests compile for that runtime and execute through `simctl`, without requiring screen interaction.

## Release

- Current App Store/TestFlight version prepared in this repo: `1.8 (78)`
- Bundle identifier: `com.gengpuliu.LiftLog`
- Export compliance: `ITSAppUsesNonExemptEncryption = NO`
- Build/version values are managed from `GPLift.xcodeproj/project.pbxproj`

### TestFlight Publish

Use the scripted flow to reduce failed upload attempts and notification emails:

```bash
cd /Users/gengpuliu/Projects/LiftLog/LiftLog
./scripts/release_testflight.sh \
  --api-key WGL74Z87GV \
  --issuer 33142954-a2ca-4a17-96b9-ee0cda4a3382 \
  --p8 /Users/gengpuliu/.appstoreconnect/private_keys/AuthKey_WGL74Z87GV.p8
```

What it does:
- Archive the app in `Release`
- Export the IPA
- Validate with Apple first
- Upload only after validation succeeds
- Wait for delivery status
