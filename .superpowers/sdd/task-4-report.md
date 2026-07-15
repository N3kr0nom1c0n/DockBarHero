# Task 4 Report: Wire Production To Recorded Speech And Verify

Status: DONE_WITH_CONCERNS

Commit: `2b35eb2` (`feat: wire recorded lore voiceover`)

## Changes

- `AppDelegate` now constructs `RecordedLoreSpeechService(bundle: .main)` for production lore playback.
- If bundled audio or its manifest cannot load, `AppDelegate` falls back to `SystemLoreSpeechService` so launch remains available.
- The lore QA review packet records the offline ElevenLabs provider, locked cast, manifest location, fresh automated results, and the unchecked manual-audio scope.

## Verification

Focused lore suite:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests -only-testing:DockBarHeroTests/LoreAudioManifestTests -only-testing:DockBarHeroTests/LoreReaderControllerTests CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST SUCCEEDED **`. Executed 29 tests with 0 failures.

Full suite:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST SUCCEEDED **`. Executed 424 tests with 0 failures.

Context guard:

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
```

Result: `project context is valid`.

Launch verification:

```bash
./script/build_and_run.sh --verify
```

Result: `** BUILD SUCCEEDED **`; DockBarHero launched from the exact worktree bundle as PID 57511. The build log confirms recorded MP3 resources were copied into the app bundle.

`git diff --check` passed before commit.

## Concern

No inspectable interactive audio session was available. Manual verification of cast distinction, volume giggles at detents 0, 5, and 10, and immediate audio stop on window close remains unchecked and is documented as such in the QA packet.

## Final Review Fix Report (2026-07-14)

### Fixed Findings

- Added `DockBarHero/Lore/Resources/Audio/*.mp3` as explicit `resources` inputs in canonical `project.yml`, then regenerated `DockBarHero.xcodeproj/project.pbxproj`.
- `RecordedLoreSpeechService(bundle:)` now validates every unique manifest asset by locating it in the bundle and opening it with `AVAudioPlayer`. Any missing or unreadable asset throws `LoreAudioManifestError.audioResourceUnreadable`, so `AppDelegate` uses its existing `SystemLoreSpeechService` fallback.
- Added an integration test that verifies each manifest asset resolves from the built app bundle and that recorded-service initialization succeeds.
- Added generator `--force` to regenerate existing output files when configuration or provider output must be refreshed.
- Corrected recorded-voiceover QA evidence to identify `codex/recorded-lore-voiceover` branch HEAD.

### RED Evidence

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/RecordedLoreVoiceoverRed2 CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/LoreAudioManifestTests
```

Result: expected failure before the project resource fix. `testRecordedSpeechServiceValidatesEveryBundledManifestAsset` reported 36 missing manifest references from the built app bundle.

### Verification

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/RecordedLoreVoiceoverGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/LoreAudioManifestTests -only-testing:DockBarHeroTests/LoreReaderControllerTests -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests
```

Result: `** TEST SUCCEEDED **`; 14 focused tests, 0 failures.

```bash
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/RecordedLoreVoiceoverFresh CODE_SIGNING_ALLOWED=NO
```

Result: `** CLEAN SUCCEEDED **` and `** BUILD SUCCEEDED **` from fresh DerivedData.

```bash
python3 <manifest-to-bundle-check>
```

Result: `Bundle manifest verification passed: 22 unique MP3 assets present in .build/RecordedLoreVoiceoverFresh/Build/Products/Debug/DockBarHero.app/Contents/Resources`.

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/RecordedLoreVoiceoverFull CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST SUCCEEDED **`; 425 tests, 0 failures.
