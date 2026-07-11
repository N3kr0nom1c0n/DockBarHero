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
