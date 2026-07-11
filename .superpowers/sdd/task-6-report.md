# Task 6 Report: Versioned Save Document And Validation

## Changed Files

- `DockBarHero/Persistence/SaveDocument.swift`
- `DockBarHeroTests/SaveDocumentTests.swift`
- `DockBarHero.xcodeproj/project.pbxproj` (generated references for the two new Swift files)

## Red Evidence

Ran the focused `SaveDocumentTests` command immediately after adding the tests and before adding production save code. The build failed because the intended production symbols did not exist:

- `cannot find type 'SaveValidationError' in scope`
- `cannot find 'SaveDocument' in scope`

This was the expected TDD red phase for the missing save schema.

## Focused Verification

Command:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData -only-testing:DockBarHeroTests/SaveDocumentTests test CODE_SIGNING_ALLOWED=NO
```

Result: `TEST SUCCEEDED`; 10 tests passed with 0 failures.

## Full Verification

Command:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO
```

Result: `TEST SUCCEEDED`; 102 tests passed with 0 failures.

## Validation Decisions And Risks

- Decoding reads a private schema-version header first, so unsupported versions fail before malformed state bodies are decoded.
- Version 1 has an explicit boundary; no migration or persistence-store behavior was added.
- Dates use ISO 8601 and encoding uses sorted keys for deterministic output.
- `SimulationDuration` remains the existing scalar `Int64` Codable representation.
- Validation covers timer interval/countdown/elapsed/revive bounds, health bounds, enemy level, positive unique item IDs, positive item level/stat/creation sequence values, equipment existence and exact slot, duplicate creation sequences, and active/reviving encounter consistency.
- Item-domain failures use `invalidItem(ItemID)` because the plan's listed error cases did not otherwise distinguish invalid positive item fields from timer errors.
- The codec validates on encode as well as decode, so invalid state cannot be emitted through this boundary.

## Final Commit

`HEAD` on `feature/phase-1-playable-slice`: `feat: add versioned save schema`

## Repair Cycle 1

### Accepted Findings Addressed

- Removed the 10-second maximum from accumulated `activeElapsed`; it now requires only a nonnegative value, with a 60-second round-trip regression.
- Added admission validation for nonnegative combat base stats and encounter hero damage, scalable current and next enemy levels with checked overflow, and checked effective equipped-stat addition.
- Added next-drop validation for `lootSequence` overflow and exact next `ItemID` or creation-sequence collisions.
- Preserved the positive `primaryStat` requirement and kept validation candidate-only with no store or file-I/O work.
- Added `invalidCombatStats(CombatantID)` and `invalidLootSequence` as narrow semantic validation errors.
- Deferred fractional ISO-8601 precision because Foundation's concise deterministic `.iso8601` strategy remains sufficient for the accepted scope; changing it would require extra formatter machinery.

### Repair Red Evidence

The first focused red run failed to compile because the two new semantic errors were absent:

- `type 'SaveValidationError' has no member 'invalidCombatStats'`
- `type 'SaveValidationError' has no member 'invalidLootSequence'`

After adding only those enum cases, the behavioral red run executed 16 tests and failed the six new regression groups: long active elapsed round trip, current/next enemy scaling, negative base stats, negative hero damage, equipped-stat overflow, and next-loot viability.

### Repair Green Verification

- Focused `SaveDocumentTests`: `TEST SUCCEEDED`; 16 tests passed with 0 failures.
- Full suite: `TEST SUCCEEDED`; 108 tests passed with 0 failures.

### Repair Commit

`8ebd3684d39ffeec8ead661c407a3ce4b5ae6d1c` (`fix: align save validation with gameplay`)
