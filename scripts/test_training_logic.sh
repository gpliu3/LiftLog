#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gplift-regression.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/legacy"
# The released build 72 models create a real store in a separate process.
baseline_ref=3981974
git show "$baseline_ref:GPLift/Models/Exercise.swift" > "$test_dir/legacy/Exercise.swift"
git show "$baseline_ref:GPLift/Models/WorkoutSet.swift" > "$test_dir/legacy/WorkoutSet.swift"

common_args=(-parse-as-library -swift-version 5 -module-name GPLiftRegression)
compiler=(xcrun --sdk macosx swiftc)
runner=()
if [[ -n "${GPLIFT_TEST_SIMULATOR:-}" ]]; then
  compiler=(xcrun --sdk iphonesimulator swiftc)
  common_args+=(-sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target "$(uname -m)-apple-ios17.0-simulator")
  runner=(xcrun simctl spawn "$GPLIFT_TEST_SIMULATOR")
else
  common_args+=(-target "$(uname -m)-apple-macos14.0")
fi
"${compiler[@]}" "${common_args[@]}" \
  "$test_dir/legacy/Exercise.swift" "$test_dir/legacy/WorkoutSet.swift" \
  GPLift/Utilities/LanguageManager.swift Tests/StoreFixture.swift Tests/LegacyFixtureWriter.swift \
  -o "$test_dir/write-fixture"
"${runner[@]}" "$test_dir/write-fixture" "$test_dir/legacy.store"

"${compiler[@]}" "${common_args[@]}" \
  GPLift/Models/Exercise.swift GPLift/Models/WorkoutSet.swift \
  GPLift/Utilities/LanguageManager.swift GPLift/Utilities/TrainingTotals.swift \
  GPLift/Utilities/ExerciseOrdering.swift GPLift/Utilities/HistorySnapshot.swift \
  GPLift/Utilities/CSVExport.swift Tests/StoreFixture.swift Tests/TrainingRegressionTests.swift \
  -o "$test_dir/test-training"
"${runner[@]}" "$test_dir/test-training" "$test_dir/legacy.store"
